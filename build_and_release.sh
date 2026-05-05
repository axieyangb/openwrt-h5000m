#!/bin/bash
# =============================================================================
# Hiveton H5000M - Local Build & GitHub Release Script
# Usage: ./build_and_release.sh [--tag v1.0.0] [--skip-build]
# =============================================================================
set -e

# ── Configuration ─────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="openwrt-h5000m-build"
GH_TOKEN="${GH_TOKEN:-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}"
GH_REPO="axieyangb/openwrt-h5000m"
BRANCH="h5000m-custom"
OUTPUT_DIR="${REPO_DIR}/firmware-output"
SKIP_BUILD=false
TAG=""

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Auto-generate tag if not provided
if [[ -z "$TAG" ]]; then
  TAG="v$(date +%Y.%m.%d)-local"
fi

# ── Colors ─────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Prereq checks ──────────────────────────────────────────────────────────────
command -v docker &>/dev/null || err "Docker is not installed"
docker info &>/dev/null       || err "Docker daemon is not running"
command -v /opt/homebrew/bin/gh &>/dev/null || err "GitHub CLI not found at /opt/homebrew/bin/gh"

log "=== Hiveton H5000M Local Build & Release ==="
log "Tag:    $TAG"
log "Branch: $BRANCH"
log "Output: $OUTPUT_DIR"
echo ""

# ── Step 1: Build ──────────────────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == "false" ]]; then
  log "Step 1: Starting Docker build..."

  # Clean up any old container
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    warn "Removing old build container..."
    docker rm -f "$CONTAINER_NAME"
  fi
  
  log "Using named Docker volume 'openwrt_build_vol' (case-sensitive & persistent)..."

  # Use arm64 Ubuntu for native compilation (no QEMU overhead)
  log "Pulling ubuntu:22.04 (arm64 native)..."
  docker pull --platform linux/arm64 ubuntu:22.04

  log "Starting build container with named volume..."
  docker run -d \
    --platform linux/arm64 \
    --name "$CONTAINER_NAME" \
    -v "${REPO_DIR}:/host-repo:ro" \
    -v "openwrt_build_vol:/openwrt" \
    ubuntu:22.04 \
    sleep infinity

  log "Installing build dependencies..."
  docker exec "$CONTAINER_NAME" bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq \
      build-essential clang flex bison g++ gawk gettext git \
      libncurses5-dev libssl-dev python3-setuptools python3-distutils-extra \
      rsync swig unzip zlib1g-dev file wget curl
  "

  log "Cloning source from GitHub (branch: ${BRANCH})..."
  docker exec "$CONTAINER_NAME" bash -c "
    if [ -d /openwrt/.git ]; then
      cd /openwrt && git fetch origin ${BRANCH} && git reset --hard origin/${BRANCH}
    else
      rm -rf /openwrt/* /openwrt/.* 2>/dev/null || true
      git clone --depth=1 -b ${BRANCH} https://${GH_TOKEN}@github.com/${GH_REPO}.git /openwrt
    fi
  "

  log "Updating feeds..."
  docker exec "$CONTAINER_NAME" bash -c "
    cd /openwrt
    ./scripts/feeds update -a 2>&1 | tail -5
    ./scripts/feeds install -a 2>&1 | tail -5
  "

  log "Writing .config for H5000M target..."
  docker exec "$CONTAINER_NAME" bash -c "
    cd /openwrt
    cat > .config <<'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_hiveton_h5000m=y
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_opkg=y
EOF
    make defconfig
  "

  log "Starting firmware compilation (this takes ~45-90 minutes)..."
  log "Follow along: docker logs -f ${CONTAINER_NAME}"
  docker exec "$CONTAINER_NAME" bash -c "
    cd /openwrt
    useradd -m builduser
    chown -R builduser:builduser /openwrt
    su - builduser -c 'cd /openwrt && make -j\$(nproc) V=s 2>&1 | tee /openwrt/build.log'
  "

  log "Build complete. Checking output..."
  docker exec "$CONTAINER_NAME" bash -c "
    find /openwrt/bin/targets/mediatek/filogic/ -type f | sort
  "
else
  log "Step 1: Skipping build (--skip-build flag set)"
fi

# ── Step 2: Copy firmware out of container ─────────────────────────────────────
log "Step 2: Extracting firmware assets..."
mkdir -p "$OUTPUT_DIR"

if [[ "$SKIP_BUILD" == "false" ]]; then
  # Copy all firmware files out of Docker container
  docker cp "${CONTAINER_NAME}:/openwrt/bin/targets/mediatek/filogic/." "$OUTPUT_DIR/"
fi

# List what we got
FIRMWARE_FILES=$(find "$OUTPUT_DIR" -maxdepth 2 -type f \( \
  -name "*hiveton*sysupgrade*" \
  -o -name "*hiveton*factory*" \
  -o -name "sha256sums" \
  -o -name "config.buildinfo" \
\) 2>/dev/null)

if [[ -z "$FIRMWARE_FILES" ]]; then
  err "No firmware files found in ${OUTPUT_DIR}. Did the build succeed?"
fi

log "Firmware files to release:"
echo "$FIRMWARE_FILES" | while read -r f; do
  echo "  → $(basename "$f") ($(du -sh "$f" | cut -f1))"
done
echo ""

# ── Step 3: Create GitHub Release ─────────────────────────────────────────────
log "Step 3: Creating GitHub Release ${TAG}..."

# Get the current commit SHA
COMMIT_SHA=$(cd "$REPO_DIR" && git rev-parse HEAD)
SHORT_SHA=$(echo "$COMMIT_SHA" | cut -c1-8)

# Build release notes
RELEASE_NOTES="## Hiveton H5000M - Custom OpenWrt Firmware

**Build:** Local (macOS Docker ARM64)
**Branch:** \`${BRANCH}\`
**Commit:** \`${SHORT_SHA}\`
**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')

### What's included
- Full OpenWrt build for Hiveton H5000M (MediaTek MT7988A / Filogic 880)
- LuCI Web UI pre-installed
- WireGuard support (\`luci-proto-wireguard\`)
- Hardware NAT offloading enabled (PPE)
- 5G modem support (Quectel RM520N-GL via QMI)
- Custom SSH welcome banner

### Installation
Flash via LuCI or SSH:
\`\`\`
sysupgrade -v openwrt-mediatek-filogic-hiveton_h5000m-sysupgrade.bin
\`\`\`

### Notes
- See \`H5000M_FIRMWARE_REBASE_GUIDE.md\` for known issues and workarounds
- Wi-Fi requires \`mt7992_eeprom_23_2i5i.bin\` EEPROM to be present on device
"

# Build the asset args
ASSET_ARGS=()
while IFS= read -r f; do
  [[ -n "$f" ]] && ASSET_ARGS+=("$f")
done <<< "$FIRMWARE_FILES"

GH_TOKEN="$GH_TOKEN" /opt/homebrew/bin/gh release create "$TAG" \
  --repo "$GH_REPO" \
  --title "Hiveton H5000M Firmware ${TAG}" \
  --notes "$RELEASE_NOTES" \
  --target "$COMMIT_SHA" \
  --prerelease \
  "${ASSET_ARGS[@]}"

log ""
log "✅ Release ${TAG} created successfully!"
log "   https://github.com/${GH_REPO}/releases/tag/${TAG}"

# ── Step 4: Cleanup ────────────────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == "false" ]]; then
  log "Step 4: Cleaning up Docker container..."
  docker rm -f "$CONTAINER_NAME"
  log "Container removed."
fi

log ""
log "=== All done! ==="
