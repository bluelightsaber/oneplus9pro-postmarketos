#!/bin/bash
# Espera al móvil en fastboot, arranca boot-uboot-7.3.img en RAM y recoge resultados. No escribe nada en el móvil.
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; W=$P/pmbootstrap-work/chroot_native/home/pmos/v2; O=$P/tests/7.3-ram-$(date +%m%d-%H%M); mkdir -p $O
echo "esperando fastboot $(date +%T)"; until timeout 5 fastboot devices 2>/dev/null | grep -q fastboot; do sleep 2; done
echo "fastboot detectado $(date +%T)"; sleep 2
timeout 180 fastboot boot $W/boot-uboot-7.3.img 2>&1 | grep -E "Sending|Booting"
echo "esperando gadget pmOS $(date +%T)"
for i in $(seq 1 90); do lsusb | grep -qiE "18d1:d001" && break; sleep 2; done
lsusb | grep -iE "18d1|0525|22d9" || { echo "SIN GADGET tras 3 min"; echo TEST-DONE; exit 0; }
echo "gadget $(date +%T)"; sleep 5
I=$(ls /sys/bus/usb/devices/1-1:*/net/ 2>/dev/null | head -1); echo "iface=$I"; sudo ip link set $I up 2>/dev/null; ip -4 addr show $I | grep -q inet || sudo ip addr add 172.16.42.2/24 dev $I
for i in $(seq 1 60); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/23" 2>/dev/null && break; sleep 3; done
if timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/23" 2>/dev/null; then
  echo "TELNET OK $(date +%T)"
  { sleep 1; echo "uname -a; cat /proc/cmdline; dmesg; exit"; sleep 8; } | nc 172.16.42.1 23 2>/dev/null | tr -d "\r" > $O/dmesg.txt
  grep -m1 "Linux (none)" $O/dmesg.txt; wc -l $O/dmesg.txt
else echo "telnet no abre"; fi
echo "resultados en $O"; echo TEST-DONE
