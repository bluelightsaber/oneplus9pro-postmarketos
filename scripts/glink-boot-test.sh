#!/bin/bash
# Activa skip_pdr para pmic_glink al arrancar, reinicia el móvil y comprueba battmgr/UCSI.
set -uo pipefail
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt
{ cat $PW; echo 'echo "options pmic_glink skip_pdr=1" > /etc/modprobe.d/pmic_glink.conf; cat /etc/modprobe.d/pmic_glink.conf; systemctl reboot'; } | $SSHP "sudo -S -p '' sh -s" 2>&1 | head -2
echo "reinicio $(date +%T)"; sleep 15
for i in $(seq 1 90); do lsusb | grep -q 18d1:d001 && break; sleep 2; done
sleep 5; I=$(ls /sys/bus/usb/devices/1-1:*/net/ 2>/dev/null | head -1)
[ -n "$I" ] && { sudo ip link set $I up; sleep 3; ip -4 addr show $I | grep -q inet || sudo ip addr add 172.16.42.2/24 dev $I; }
for i in $(seq 1 60); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && break; sleep 4; done
echo "SSH $(date +%T)"; sleep 20
{ cat $PW; cat <<'EOF'
cat /sys/module/pmic_glink/parameters/skip_pdr
for f in status capacity voltage_now current_now charge_type health; do printf "bat %-12s " $f; cat /sys/class/power_supply/qcom-battmgr-bat/$f 2>&1; done
for f in online usb_type current_max; do printf "usb %-12s " $f; cat /sys/class/power_supply/qcom-battmgr-usb/$f 2>&1; done
ls /sys/class/typec/ /sys/class/usb_role/
dmesg | grep -iE "glink|battmgr|ucsi|pdr" | grep -viE "fastrpc|bluetooth" | tail -10
EOF
} | $SSHP "sudo -S -p '' sh -s" 2>&1
echo GLINK-DONE
