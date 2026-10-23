#!/bin/sh
# Run ON THE PHONE as root. Installs the QCA6490 (WCN6851 = WCN6855 hw1.1) Wi-Fi firmware for ath11k from the
# phone's OWN partitions (vendor/unit-specific blobs: never redistribute them). Both mounts are read-only.
#   modem_a: amss.bin (WLAN.HSP.1.1, V1/V2 silicon), m3.bin
#   persist: bdwlan.elf (OnePlus board data, what cnss2 loads for board_id 0xff) -> board.bin, regdb.bin
# Fallback board file: BOARD=e06 uses the generic Qualcomm modem_a/image/bdwlan.e06 instead.
# Do NOT use the linux-firmware WCN6855 hw2.0 regdb.bin: it crashes this firmware at "wlan mode req".
set -e
T=/lib/firmware/ath11k/WCN6855/hw1.1
M=$(mktemp -d); Q=$(mktemp -d)
mount -o ro,noexec,nosuid /dev/disk/by-partlabel/modem_a "$M"
mount -o ro,noexec,nosuid,nodev /dev/disk/by-partlabel/persist "$Q"
trap 'umount "$M" "$Q"; rmdir "$M" "$Q"' EXIT
mkdir -p "$T"
cp "$M/image/amss.bin" "$M/image/m3.bin" "$T/"
if [ -n "${BOARD:-}" ]; then cp "$M/image/bdwlan.$BOARD" "$T/board.bin"; rm -f "$T/regdb.bin"
else cp "$Q/bdwlan.elf" "$T/board.bin"; cp "$Q/regdb.bin" "$T/regdb.bin"; fi
ls -la "$T"
