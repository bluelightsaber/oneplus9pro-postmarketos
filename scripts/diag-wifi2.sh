#!/bin/sh
# (en el móvil) Tras la corrección de vddaonwl: ¿sube el enlace PCIe y aparece wlan0? (solo lectura)
dmesg | grep -iE "vddaonwl|Phy link|link up|ath11k|mhi|wlan|qca6490" | grep -v fastrpc | tail -20
echo "== PCI"; for d in /sys/bus/pci/devices/*; do echo "$(basename $d) $(cat $d/vendor):$(cat $d/device) driver=$(basename $(readlink $d/driver 2>/dev/null) 2>/dev/null)"; done
echo "== red"; ls /sys/class/net/; nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null
