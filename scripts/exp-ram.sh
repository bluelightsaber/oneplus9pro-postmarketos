#!/bin/bash
# Experimento en RAM: reinicia el móvil a fastboot desde Linux, arranca una variante con
# "fastboot boot" y ejecuta un diagnóstico por SSH. Producción (boot_a) no se toca.
# Uso: exp-ram.sh IMAGEN [script-diagnóstico-local]
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
IMG=$1; DIAG=${2:-}
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
battery() { $SSHP 'B=/sys/class/power_supply/bq27541-0; echo "BAT $(cat $B/capacity)% $(cat $B/status) $(cat $B/voltage_now)uV temp=$(cat $B/temp)"' 2>/dev/null; }

echo "== batería antes: $(battery)"
if ! timeout 5 fastboot devices 2>/dev/null | grep -q fastboot; then
  echo "== reboot bootloader desde Linux ($(date +%T))"
  $SSHP 'sudo -S -p "" systemctl reboot --reboot-argument=bootloader' < $HOME/oneplus9pro-password.txt 2>&1 | tail -2
  for i in $(seq 1 45); do timeout 5 fastboot devices 2>/dev/null | grep -q fastboot && break; sleep 2; done
fi
timeout 5 fastboot devices | grep -q fastboot || { echo "NO LLEGA A FASTBOOT"; echo EXP-DONE; exit 1; }
echo "== fastboot ($(date +%T)), arrancando $IMG en RAM"
timeout 180 fastboot boot "$IMG" 2>&1 | grep -E "Booting"
for i in $(seq 1 90); do lsusb | grep -q 18d1:d001 && break; sleep 2; done
sleep 5; I=$(ls /sys/bus/usb/devices/1-1:*/net/ 2>/dev/null | head -1)
[ -n "$I" ] && { sudo ip link set $I up; sleep 3; ip -4 addr show $I | grep -q inet || sudo ip addr add 172.16.42.2/24 dev $I; }
for i in $(seq 1 60); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && break; sleep 4; done
echo "== SSH ($(date +%T)) batería: $(battery)"
[ -n "$DIAG" ] && $SSHP sh -s < "$DIAG"
echo EXP-DONE
