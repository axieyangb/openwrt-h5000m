#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y build-essential clang flex bison g++ gawk gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget python3-distutils
git clone -b h5000m-custom https://github.com/axieyangb/openwrt-h5000m.git /openwrt
cd /openwrt
./scripts/feeds update -a
./scripts/feeds install -a
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_hiveton_h5000m=y" >> .config
echo "CONFIG_PACKAGE_luci-app-passwall=y" >> .config
echo "CONFIG_PACKAGE_opkg=y" >> .config
make defconfig
useradd -m builduser
chown -R builduser:builduser /openwrt
su - builduser -c "cd /openwrt && make -j$(nproc) > /openwrt/build.log 2>&1 &"
