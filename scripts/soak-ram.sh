#!/bin/bash
# RAM-boots IMG, keeps it (keep-experiment) and samples it every 30 s for MIN minutes, then reboots to production.
IMG=$1; MIN=${2:-15}
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=8 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
~/exp-ram.sh $IMG /dev/null
K=$($SSHP uname -r 2>/dev/null); echo "kernel: $K"
[ -z "$K" ] || [ "$K" = "6.7.0" ] && { echo "test kernel not running"; exit 1; }
$SSHP "sudo -S -p \"\" touch /run/keep-experiment" < ~/oneplus9pro-password.txt
for i in $(seq 1 $((MIN*2))); do
  sleep 30
  O=$($SSHP "cat /proc/uptime /proc/loadavg | tr \"\n\" \" \"; cat /sys/class/power_supply/bq27541-0/capacity /sys/class/thermal/thermal_zone0/temp 2>/dev/null | tr \"\n\" \" \"" 2>/dev/null) || { echo "$(date +%T) LOST after ~$((i*30)) s"; exit 1; }
  echo "$(date +%T) up/load/bat/temp: $O"
done
$SSHP "sudo -S -p \"\" sh -c \"dmesg | grep -ciE \\\"error|fail|oops|bug\\\"; rm -f /run/keep-experiment; systemctl reboot\"" < ~/oneplus9pro-password.txt
echo SOAKRAM-DONE
