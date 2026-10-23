#!/bin/bash
IMG=$1
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
export PATH=$HOME/.local/bin:$PATH
~/exp-ram.sh $IMG /dev/null
$SSHP "sudo -S -p \"\" sh -s" < <(cat ~/oneplus9pro-password.txt ${CHECK:-$HOME/check-pmos.sh})
for i in $(seq 1 30); do timeout 5 fastboot devices 2>/dev/null | grep -q fastboot && { echo "== FASTBOOT reached from Linux ($(date +%T))"; timeout 20 fastboot reboot; break; }; sleep 2; done
echo TESTPMOS-DONE
