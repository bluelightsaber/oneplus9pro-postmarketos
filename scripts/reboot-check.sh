#!/bin/bash
# Reinicia el móvil (normal) y comprueba producción tras el arranque.
set -uo pipefail
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
$SSHP "sudo -S -p '' systemctl reboot" < $HOME/oneplus9pro-password.txt 2>&1 | tail -1
echo "reinicio $(date +%T)"; sleep 15
for i in $(seq 1 90); do lsusb | grep -q 18d1:d001 && break; sleep 2; done
sleep 5; I=$(ls /sys/bus/usb/devices/1-1:*/net/ 2>/dev/null | head -1)
[ -n "$I" ] && { sudo ip link set $I up; sleep 3; ip -4 addr show $I | grep -q inet || sudo ip addr add 172.16.42.2/24 dev $I; }
for i in $(seq 1 60); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && break; sleep 4; done
echo "SSH $(date +%T)"
$SSHP 'uptime; tr " " "\n" < /proc/cmdline | grep initcall; for r in /sys/class/remoteproc/*; do echo "rproc $(cat $r/name) $(cat $r/state)"; done; sleep 20; B=/sys/class/power_supply/bq27541-0; echo "BAT $(cat $B/capacity)% $(cat $B/status) current=$(cat $B/current_now) temp=$(cat $B/temp)"'
echo CHECK-DONE
