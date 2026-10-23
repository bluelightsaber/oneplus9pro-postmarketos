#!/bin/bash
# Prueba de resistencia: N reinicios normales seguidos; en cada uno comprueba que vuelve a producción
# y que la GPT mantiene boot_a como correcto. Al final, comprobación de salud.
set -uo pipefail
N=${1:-3}
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt
up() {
  for i in $(seq 1 90); do lsusb | grep -q 18d1:d001 && break; lsusb | grep -q 18d1:d00d && { echo "  !! EN FASTBOOT"; return 1; }; sleep 2; done
  sleep 5; I=$(ls /sys/bus/usb/devices/1-1:*/net/ 2>/dev/null | head -1)
  [ -n "$I" ] && { sudo ip link set $I up; sleep 3; ip -4 addr show $I | grep -q inet || sudo ip addr add 172.16.42.2/24 dev $I; }
  for i in $(seq 1 60); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && return 0; sleep 3; done; return 1
}
gpt() { { cat $PW; echo "dd if=/dev/sde bs=4096 count=6 2>/dev/null"; } | $SSHP "sudo -S -p '' sh -s" > /tmp/g.bin; python3 /srv/oneplus9pro-pmos/scripts/gpt-ab.py /tmp/g.bin 4096 | grep boot_a; }
for n in $(seq 1 $N); do
  $SSHP "sudo -S -p '' systemctl reboot" < $PW >/dev/null 2>&1; sleep 15
  if up; then sleep 40; echo "reinicio $n OK $(date +%T): $(gpt)"; else echo "reinicio $n FALLO $(date +%T)"; exit 1; fi
done
$SSHP sh -s < $HOME/health-check.sh
echo SOAK-DONE
