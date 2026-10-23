#!/bin/bash
# Espera al móvil en fastboot, arranca el 7.3 en RAM y, según lo que responda por SSH:
#  - si es 7.3: ejecuta el diagnóstico;
#  - si es producción (6.7, tras un fallo): recoge /sys/fs/pstore (log del 7.3 antes de morir).
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; W=$P/pmbootstrap-work/chroot_native/home/pmos/v2
O=$P/tests/7.3-pstore-$(date +%m%d-%H%M); mkdir -p $O
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt

echo "esperando fastboot $(date +%T)"; until timeout 5 fastboot devices 2>/dev/null | grep -q fastboot; do sleep 2; done
echo "fastboot $(date +%T)"; timeout 180 fastboot boot $W/boot-uboot-7.3.img 2>&1 | grep -E "Booting"
for i in $(seq 1 120); do lsusb | grep -q 18d1:d001 && break; sleep 2; done
sleep 5; I=$(ls /sys/bus/usb/devices/1-1:*/net/ 2>/dev/null | head -1)
[ -n "$I" ] && { sudo ip link set $I up; sleep 3; ip -4 addr show $I | grep -q inet || sudo ip addr add 172.16.42.2/24 dev $I; }
for i in $(seq 1 90); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && break; sleep 4; done
K=$($SSHP uname -r 2>/dev/null); echo "SSH $(date +%T) kernel=$K"
case "$K" in
  7.3*) $SSHP sh -s < $HOME/diag-7.3.sh | tee $O/diag.txt ;;
  6.7*) echo "== volvió producción: recogiendo pstore"
        { cat $PW; echo 'ls -la /sys/fs/pstore/; for f in /sys/fs/pstore/*; do echo "##### $f"; cat "$f"; done'; } | $SSHP "sudo -S -p '' sh -s" > $O/pstore.txt 2>&1
        ls -la $O; grep -E "^#####|Kernel panic|Internal error|Unable to handle|Call trace|watchdog|BUG|Oops" $O/pstore.txt | head -20
        echo "-- últimas líneas del log del 7.3:"; grep -v "^#####" $O/pstore.txt | tail -40 ;;
  *) echo "no responde por SSH" ;;
esac
echo "resultados en $O"; echo TEST-DONE
