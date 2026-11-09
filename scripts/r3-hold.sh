#!/bin/bash
# RAM-test REV=3 for the hub and keep it running: install its modules while production runs (reboot-mode is
# already loaded, so the reboot to bootloader still works), RAM boot, keep-experiment. Restore afterwards with
# the production backup (/data/.modules-backup-7.3.0.tar) unless the image gets promoted.
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; B=$P/pmbootstrap-work/chroot_buildroot_aarch64
IMG=$P/pmbootstrap-work/chroot_native/home/pmos/v2/boot-uboot-pmos-7.3.0.img
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt
$SSHP "sudo -S -p '' sh -c 'ls -la /data/.modules-backup-7.3.0.tar'" < $PW || exit 1
~/restore-mods.sh $B/lib/modules 7.3.0 || exit 1
~/exp-ram.sh "$IMG" /dev/null
$SSHP "sudo -S -p '' sh -c 'touch /run/keep-experiment; uname -v; sleep 20; systemctl is-system-running; ip -br a show wlan0 | cut -c1-40'" < $PW
echo R3HOLD-DONE
