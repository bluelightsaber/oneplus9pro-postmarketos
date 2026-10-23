#!/bin/sh
# (en el móvil) Estado USB-C / UCSI / roles tras el arranque (solo lectura).
ls /sys/bus/auxiliary/devices/
echo "== typec"; ls /sys/class/typec/ 2>&1
for p in /sys/class/typec/port*; do [ -d "$p" ] || continue
  echo "-- $p"; for f in data_role power_role port_type vconn_source power_operation_mode usb_power_delivery_revision; do [ -f $p/$f ] && echo "   $f: $(cat $p/$f)"; done
done
echo "== usb_role"; for r in /sys/class/usb_role/*; do [ -f "$r/role" ] && echo "$r: $(cat $r/role)"; done
echo "== dwc3"; ls /sys/bus/platform/devices/ | grep -i "a600000"; cat /sys/kernel/debug/usb/a600000.usb/mode 2>/dev/null
dmesg | grep -iE "ucsi|typec|role|dwc3" | grep -v fastrpc | tail -12
