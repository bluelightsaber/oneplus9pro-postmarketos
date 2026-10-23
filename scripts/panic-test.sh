#!/bin/bash
# Provoca un panic controlado en el móvil y comprueba si pstore lo conserva tras el reinicio.
set -uo pipefail
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt
$SSHP "tr ' ' '\n' < /proc/cmdline | grep reboot; dmesg | grep -i 'ramoops: using'"
{ cat $PW; echo "sync; sysctl -w kernel.panic=5 >/dev/null; echo PSTORE-TEST-MARKER > /dev/kmsg; sleep 1; echo c > /proc/sysrq-trigger"; } | timeout 20 $SSHP "sudo -S -p '' sh -s" >/dev/null 2>&1
echo "panic provocado $(date +%T)"; sleep 20
for i in $(seq 1 60); do lsusb | grep -q 18d1:d001 && break; sleep 2; done
sleep 5; I=$(ls /sys/bus/usb/devices/1-1:*/net/ 2>/dev/null | head -1)
[ -n "$I" ] && { sudo ip link set $I up; sleep 3; ip -4 addr show $I | grep -q inet || sudo ip addr add 172.16.42.2/24 dev $I; }
for i in $(seq 1 60); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && break; sleep 4; done
echo "vuelve $(date +%T)"
{ cat $PW; echo 'uptime; ls -la /sys/fs/pstore/; grep -l PSTORE-TEST-MARKER /sys/fs/pstore/* 2>/dev/null && echo "MARCA ENCONTRADA"; grep -h -E "sysrq|Kernel panic" /sys/fs/pstore/* 2>/dev/null | head -3'; } | $SSHP "sudo -S -p '' sh -s"
echo PANIC-TEST-DONE
