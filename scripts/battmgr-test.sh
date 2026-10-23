#!/bin/sh
# (en el móvil, root) Recarga qcom_battmgr con umbrales y prueba el límite 45-65 %.
set -u
B=/sys/class/power_supply/qcom-battmgr-bat; G=/sys/class/power_supply/bq27541-0
cp /tmp/qcom_battmgr.ko /lib/modules/6.7.0/extra/qcom_battmgr.ko && depmod 6.7.0
rmmod qcom_battmgr && modprobe qcom_battmgr && echo "battmgr recargado"
sleep 3
ls $B/ | grep charge_control
echo "antes: $(cat $G/capacity)% $(cat $G/status) corriente=$(cat $G/current_now)"
echo 65 > $B/charge_control_end_threshold; echo "rc end=$?"
echo 45 > $B/charge_control_start_threshold; echo "rc start=$?"
echo "umbrales: start=$(cat $B/charge_control_start_threshold) end=$(cat $B/charge_control_end_threshold)"
dmesg | tail -5 | grep -iE "battmgr|unknown|glink"
for t in 10 20 30 40 60; do sleep 10; echo "+${t}s: $(cat $G/capacity)% $(cat $G/status) corriente=$(cat $G/current_now) | usb online=$(cat /sys/class/power_supply/qcom-battmgr-usb/online 2>&1)"; done
