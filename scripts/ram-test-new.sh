#!/bin/bash
# RAM-test a NEW package image whose kernel version equals production's: install the new modules (from the
# buildroot chroot), run test-pmos.sh with CHECK, then restore production's modules and reboot production.
# Production modules backup: /data/.modules-backup-<kver>.tar (made here if missing).
# Usage: CHECK=~/check-x.sh ram-test-new.sh IMG
set -uo pipefail
IMG=$1
P=/srv/oneplus9pro-pmos; B=$P/pmbootstrap-work/chroot_buildroot_aarch64
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt
wait_ssh() { for i in $(seq 1 60); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && return 0; sleep 4; done; return 1; }
wait_ssh || { echo "phone not reachable"; exit 1; }
KV=$($SSHP uname -r); [[ "$KV" =~ ^[0-9]+\.[0-9]+ ]] || { echo "bad kver"; exit 1; }
[ -d $B/lib/modules/$KV ] || { echo "buildroot has no modules for $KV"; exit 1; }
$SSHP "sudo -S -p '' sh -c '[ -s /data/.modules-backup-$KV.tar ] || tar -C /lib/modules -cf /data/.modules-backup-$KV.tar $KV; ls -la /data/.modules-backup-$KV.tar'" < $PW
~/restore-mods.sh $B/lib/modules $KV
~/test-pmos.sh "$IMG"
sleep 30; wait_ssh || { echo "phone did not come back"; exit 1; }; sleep 10
$SSHP "sudo -S -p '' sh -c 'rm -rf /lib/modules/$KV && tar -C /lib/modules -xf /data/.modules-backup-$KV.tar && depmod $KV && echo production-modules-restored && systemctl reboot'" < $PW
sleep 20; wait_ssh && sleep 15 && $SSHP "systemctl is-system-running; lsmod | grep -c qcom_battmgr"
echo RAMTESTNEW-DONE
