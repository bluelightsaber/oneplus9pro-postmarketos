#!/bin/sh
# Diagnóstico del 7.3 arrancado en RAM sobre el rootfs de producción (solo lectura).
uname -r
echo "== remoteprocs"; for r in /sys/class/remoteproc/*; do echo "$(cat $r/name) $(cat $r/state)"; done
echo "== power_supply"; ls /sys/class/power_supply/
for p in /sys/class/power_supply/*; do
  echo "-- $p"
  for f in type status capacity current_now voltage_now charge_control_start_threshold charge_control_end_threshold online usb_type; do
    [ -f $p/$f ] && echo "   $f=$(cat $p/$f 2>&1)"
  done
done
echo "== typec / usb_role"; ls /sys/class/typec/ /sys/class/usb_role/ 2>&1
for r in /sys/class/usb_role/*; do [ -f $r/role ] && echo "$r role=$(cat $r/role)"; done
echo "== reboot-mode"; ls /sys/class/reboot-mode/ 2>&1; dmesg | grep -iE "reboot-mode|nvmem-reboot" | head -3
echo "== modulos cargados"; lsmod | grep -iE "glink|battmgr|ucsi|pas|q6v5" | head
echo "== errores relevantes"; dmesg | grep -iE "battmgr|pmic_glink|ucsi|typec|error|fail" | grep -viE "bluetooth|hci0" | head -25
