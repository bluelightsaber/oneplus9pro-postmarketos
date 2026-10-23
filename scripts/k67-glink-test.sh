#!/bin/sh
# (en el móvil, root) Recarga pmic_glink con skip_pdr=1 y comprueba si battmgr y UCSI responden.
set -u
for m in ucsi_glink typec_ucsi pmic_glink_altmode qcom_battmgr pmic_glink; do rmmod $m 2>/dev/null; done
cp /tmp/pmic_glink.ko /lib/modules/6.7.0/extra/pmic_glink.ko
depmod 6.7.0
modprobe pmic_glink skip_pdr=1 && modprobe qcom_battmgr && modprobe pmic_glink_altmode && modprobe typec_ucsi && modprobe ucsi_glink
sleep 5
cat /sys/module/pmic_glink/parameters/skip_pdr
for f in status capacity voltage_now current_now charge_type; do printf "bat %-12s " $f; cat /sys/class/power_supply/qcom-battmgr-bat/$f 2>&1; done
for f in online usb_type current_max; do printf "usb %-12s " $f; cat /sys/class/power_supply/qcom-battmgr-usb/$f 2>&1; done
ls /sys/class/typec/ /sys/class/usb_role/
dmesg | tail -15 | grep -viE "bluetooth|hci0|fastrpc"
