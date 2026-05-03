# Hiveton H5000M - OpenWrt Firmware Rebase Guide

This document catalogs the exact issues encountered, root causes, and workarounds implemented to achieve a stable, fully hardware-accelerated OpenWrt firmware for the **Hiveton H5000M** (MediaTek MT7988A / Filogic 880). 

Use this guide as a checklist whenever you need to rebase your custom branch onto a newer upstream OpenWrt release.

---

## 1. Wi-Fi 7 Initialization (MT7992/MT7996)
**Issue:** The `mt7996e` driver would fail to probe with `error -12`, complaining about missing firmware binaries, and dumping `____000000` as the firmware version.
**Root Cause:** The MT7992 chip inside the H5000M is Hardware Revision `23` and uses a `2i5i` antenna topology. The driver aggressively enforces strict naming conventions for its calibration (EEPROM) and ROM patch files based on these hardware identifiers.
**The Fix / Rebase Checklist:**
* **Package Requirement:** You **MUST** use `kmod-mt7992-23-firmware` in `filogic.mk`. Do *not* use the generic `kmod-mt7992-firmware`, as it strips the `-23` suffix from the binaries.
* **EEPROM Naming:** The extracted factory calibration data (the EEPROM) must be placed in `target/linux/mediatek/filogic/base-files/lib/firmware/mediatek/mt7996/` and MUST be explicitly named:
  👉 `mt7992_eeprom_23_2i5i.bin`
  *(Any other name, such as `mt7996_eeprom.bin`, will be completely ignored by the kernel driver).*

---

## 2. 5G Cellular Modem Integration (Quectel RM520N-GL)
**Issue:** The 5G modem was not recognized, and there was no way to dial out or bridge its internet connection into the router.
**The Fix / Rebase Checklist:**
* **Required Packages:** Add the following to your build configuration to ensure the USB bus detects the modem and can communicate via the Qualcomm MSM Interface (QMI):
  `kmod-usb-net-qmi-wwan kmod-usb-serial-option uqmi luci-proto-qmi usbutils`
* **Interface Configuration:** OpenWrt does not auto-configure the QMI protocol perfectly. To streamline it, execute these UCI commands on a fresh flash (or bake them into `/etc/uci-defaults/`):
  ```bash
  uci set network.wan_5g=interface
  uci set network.wan_5g.proto='qmi'
  uci set network.wan_5g.device='/dev/cdc-wdm0'
  uci set network.wan_5g.pdptype='ipv4v6'
  uci add_list firewall.@zone[1].network='wan_5g'
  uci delete network.wwan  # Removes the redundant auto-generated interface
  uci commit network && uci commit firewall
  ```

---

## 3. Hardware NAT Offloading (PPE)
**Issue:** By default, OpenWrt 23.05+ handles routing via the CPU. On a 2.5G/Wi-Fi 7 router, this causes massive CPU bottlenecks.
**The Fix / Rebase Checklist:**
* **Required Package:** Ensure `kmod-nft-offload` is included in the build.
* **Activation:** OpenWrt disables offloading by default for compatibility. It must be explicitly enabled via UCI or the LuCI Firewall settings:
  ```bash
  uci set firewall.@defaults[0].flow_offloading=1
  uci set firewall.@defaults[0].flow_offloading_hw=1
  uci commit firewall
  ```
  *(This activates the MediaTek Packet Processing Engine (PPE) for zero-CPU wire-speed routing).*

---

## 4. Compilation Environment (macOS Limitations)
**Issue:** The OpenWrt build system heavily relies on a case-sensitive file system. macOS uses a case-insensitive file system by default, causing obscure build failures (e.g., `netfilter` vs `Netfilter`).
**The Fix / Rebase Checklist:**
* **Native Docker:** Always compile using a Docker container on the Mac.
* **Speed:** Because newer Macs use Apple Silicon (ARM64), and the router is also ARM64 (Cortex-A73), running an `ubuntu:22.04` ARM64 docker container allows you to compile *natively* without QEMU translation overhead. This reduces a 3-hour cross-compile down to ~30 minutes.

---

## 5. Pre-Requisite Packages Summary (filogic.mk)
Whenever you rebase, ensure your `DEVICE_PACKAGES` list in `target/linux/mediatek/image/filogic.mk` for the `hiveton_h5000m` block looks exactly like this:
```makefile
  DEVICE_PACKAGES := kmod-hwmon-pwmfan kmod-usb3 mt7987-2p5g-phy-firmware \
	kmod-mt7996e kmod-mt7992-23-firmware f2fsck mkf2fs \
	kmod-usb-net-qmi-wwan kmod-usb-serial-option uqmi luci-proto-qmi usbutils \
	kmod-nft-offload
```
