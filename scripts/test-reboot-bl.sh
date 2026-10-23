#!/bin/bash
# Prueba el reinicio a fastboot desde Linux y la vuelta a producción, todo en remoto.
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt
waitssh() {
  for i in $(seq 1 90); do lsusb | grep -q 18d1:d001 && break; sleep 2; done
  sleep 5; I=$(ls /sys/bus/usb/devices/1-1:*/net/ 2>/dev/null | head -1)
  [ -n "$I" ] && { sudo ip link set $I up; sleep 3; ip -4 addr show $I | grep -q inet || sudo ip addr add 172.16.42.2/24 dev $I; }
  for i in $(seq 1 60); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && return 0; sleep 4; done; return 1
}
echo "== reboot bootloader desde Linux ($(date +%T))"
$SSHP "sudo -S -p '' systemctl reboot --reboot-argument=bootloader" < $PW >/dev/null 2>&1
for i in $(seq 1 45); do timeout 5 fastboot devices 2>/dev/null | grep -q fastboot && break; sleep 2; done
if timeout 5 fastboot devices | grep -q fastboot; then
  echo "FASTBOOT REMOTO OK ($(date +%T))"
  timeout 20 fastboot reboot 2>&1 | tail -1
else
  echo "no llegó a fastboot"
fi
waitssh && echo "== producción de vuelta ($(date +%T))"
sleep 30
{ cat $PW; cat <<'EOF'
uname -r; lsmod | grep -cE "pmic_glink|battmgr|ucsi_glink|nvmem_reboot"
for f in status capacity voltage_now current_now charge_type; do printf "bat %-12s " $f; cat /sys/class/power_supply/qcom-battmgr-bat/$f 2>&1; done
for f in online usb_type current_max; do printf "usb %-12s " $f; cat /sys/class/power_supply/qcom-battmgr-usb/$f 2>&1; done
ls /sys/class/typec/ /sys/class/usb_role/
dmesg | grep -iE "glink|battmgr|ucsi|pdr" | grep -viE "fastrpc|bluetooth" | tail -10
EOF
} | $SSHP "sudo -S -p '' sh -s" 2>&1
echo RBL-DONE
