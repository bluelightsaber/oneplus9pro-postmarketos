#!/bin/sh
# Diagnóstico tras arrancar con el ADSP habilitado (solo lectura).
tr ' ' '\n' < /proc/cmdline | grep initcall
for r in /sys/class/remoteproc/*; do [ -e "$r/name" ] && echo "rproc $(cat $r/name) $(cat $r/state)"; done
ls /sys/class/power_supply/
dmesg | grep -iE "remoteproc|adsp|cdsp|slpi|glink|battmgr|charg|fatal|crash|watchdog" | tail -20
sleep 20
B=/sys/class/power_supply/bq27541-0; echo "BAT +20s: $(cat $B/capacity)% $(cat $B/status) $(cat $B/current_now)"
