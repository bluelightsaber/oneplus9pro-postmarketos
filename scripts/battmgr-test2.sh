#!/bin/sh
# (en el móvil, root) Recarga qcom_battmgr con charge_behaviour y prueba inhibir/reanudar la carga.
set -u
B=/sys/class/power_supply/qcom-battmgr-bat; G=/sys/class/power_supply/bq27541-0
cp /tmp/qcom_battmgr.ko /lib/modules/6.7.0/extra/qcom_battmgr.ko && depmod 6.7.0
rmmod qcom_battmgr && modprobe qcom_battmgr && echo "battmgr recargado"; sleep 3
echo "behaviour: $(cat $B/charge_behaviour 2>&1)"
st() { echo "  $(cat $G/capacity)% $(cat $G/status) corriente=$(cat $G/current_now) | bat-fw: $(cat $B/status 2>&1) $(cat $B/current_now 2>&1)"; }
echo "antes:"; st
echo inhibit-charge > $B/charge_behaviour; echo "rc inhibit=$? -> $(cat $B/charge_behaviour)"
for t in 5 15 30; do sleep 10; echo "+${t}s:"; st; done
echo auto > $B/charge_behaviour; echo "rc auto=$? -> $(cat $B/charge_behaviour)"
for t in 5 15 30; do sleep 10; echo "+${t}s:"; st; done
dmesg | tail -6 | grep -iE "battmgr|unknown|glink"
