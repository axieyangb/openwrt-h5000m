# OpenWrt for Hiveton H5000M

![Hiveton H5000M Router](hiveton-h5000m.avif)

This repository is a specialized fork of OpenWrt, heavily customized and optimized specifically for the **Hiveton H5000M** router.

## Hardware Specifications
* **SoC:** MediaTek MT7988A (Filogic 880) - Quad-Core ARM Cortex-A73
* **Wi-Fi:** MediaTek MT7992/MT7996 (True Wi-Fi 7 / EHT / 802.11be)
* **Networking:** 2x 2.5GbE Ports (WAN/LAN)
* **Cellular Expansion:** M.2 Slot supporting 5G Cellular Modems (Pre-configured for Quectel RM520N-GL)

## Features Included in This Build
This fork is designed to provide a perfect "Out of the Box" experience for the Hiveton H5000M. When you flash the compiled `sysupgrade` binary, the following features are automatically configured and enabled:

1. **Hardware NAT Offloading (PPE):**
   * The MediaTek Packet Processing Engine is enabled globally. 
   * Delivers zero-CPU wire-speed routing (2.5Gbps) out of the box.

2. **Native Wi-Fi 7 Support:**
   * Includes the exact `-23` ROM patches and the `2i5i` factory calibration EEPROM required to initialize the radio.
   * Both 2.4GHz and 5GHz radios are active on first boot, broadcasting the `Hiveton_H5000M` SSID securely (Open/No Password by default to allow initial setup).

3. **Plug-and-Play 5G Cellular:**
   * Includes complete QMI protocol integration.
   * A dedicated `wan_5g` interface is pre-bridged to the firewall. Simply insert your 5G SIM card, and the router will auto-negotiate and connect to the cellular network.

4. **Thermal Management & GUI:**
   * Includes native OpenWrt PWM Fan Control.
   * The complete LuCI Web UI is baked directly into the default image.

## How to Build / Download
The firmware binaries are built automatically using GitHub Actions.
To download the latest stable release:
1. Navigate to the **Actions** tab.
2. Select the latest successful run of the **Build H5000M Firmware** workflow.
3. Scroll down to the **Artifacts** section and download the generated `.bin` files.

---

*(For developers and maintainers: Please refer to the `H5000M_FIRMWARE_REBASE_GUIDE.md` file in this repository for critical instructions on rebasing this fork against newer upstream OpenWrt branches).*
