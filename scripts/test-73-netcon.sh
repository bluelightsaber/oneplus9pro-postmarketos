#!/bin/bash
# Arranca el kernel 7.3 de depuración (g_ether + netconsole) en RAM y graba en buildhost su log por UDP.
# Producción no se toca: si el 7.3 cae, el móvil vuelve solo a boot_a.
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; W=$P/pmbootstrap-work/chroot_native/home/pmos/v2
O=$P/tests/7.3-netcon-$(date +%m%d-%H%M); mkdir -p $O
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=8 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt
EXTRA="netconsole=6665@172.16.42.1/usb0,6666@172.16.42.2/ff:ff:ff:ff:ff:ff loglevel=8 ignore_loglevel"

echo "== variante ($(date +%T))"
KBUILD=$P/src/build-7.3-dbg ~/variant-7.3.sh "$EXTRA" > $O/build.log 2>&1 || { tail $O/build.log; exit 1; }
B=$($SSHP 'cat /sys/class/power_supply/bq27541-0/capacity' 2>/dev/null); echo "batería $B%"
[ -n "$B" ] && [ "$B" -lt 40 ] && { echo "batería baja, no pruebo"; exit 1; }

echo "== reboot bootloader ($(date +%T))"
$SSHP "sudo -S -p '' systemctl reboot --reboot-argument=bootloader" < $PW >/dev/null 2>&1
for i in $(seq 1 45); do timeout 5 fastboot devices 2>/dev/null | grep -q fastboot && break; sleep 2; done
timeout 5 fastboot devices | grep -q fastboot || { echo "no llegó a fastboot"; exit 1; }

# escuchador: espera la interfaz del gadget del 7.3 (0525:a4a2) y graba UDP 6666 durante 150 s
(
  for i in $(seq 1 200); do
    I=$(for d in /sys/bus/usb/devices/1-1:*/net/*; do [ -e "$d" ] && basename $d; done | head -1)
    lsusb | grep -q 0525:a4a2 && [ -n "$I" ] && break; sleep 0.5
  done
  echo "gadget 7.3 visto: ${I:-ninguno} $(date +%T.%N | cut -c1-12)"
  [ -n "$I" ] && { sudo ip link set $I up; sudo ip addr add 172.16.42.2/24 dev $I 2>/dev/null
                   sudo timeout 150 tcpdump -l -n -i $I -A -s 0 udp port 6666 > $O/netconsole.raw 2>$O/tcpdump.err; }
) > $O/listener.log 2>&1 &
LP=$!

echo "== fastboot boot ($(date +%T))"
timeout 180 fastboot boot $W/boot-uboot-7.3.img 2>&1 | grep -E "Booting"
sleep 5; sudo journalctl -k --since "-1 min" --no-pager -f > $O/buildhost-usb.log 2>&1 &
JP=$!
wait $LP; kill $JP 2>/dev/null
cat $O/listener.log
grep -vE "^[0-9]{2}:[0-9]{2}|^\s*$|^\.\.\." $O/netconsole.raw > $O/netconsole.txt 2>/dev/null
echo "líneas de log recibidas: $(wc -l < $O/netconsole.txt)"
echo "-- últimas 40 líneas:"; tail -40 $O/netconsole.txt
echo "-- eventos USB en buildhost:"; grep -iE "usb 1-1|idVendor|cdc|renamed" $O/buildhost-usb.log | tail -8
echo "resultados en $O"; echo NETCON-DONE
