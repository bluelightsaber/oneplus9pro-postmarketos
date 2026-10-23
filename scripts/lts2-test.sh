#!/bin/bash
# Prepares and RAM-tests the pmOS generic LTS kernel with the 7.3 fixes (see prep-lts2.sh).
set -uo pipefail
V=/srv/oneplus9pro-pmos/pmbootstrap-work/chroot_native/home/pmos/v2
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
~/prep-lts2.sh ${1:-linux-postmarketos-lts} || exit 1
~/exp-ram.sh $V/boot-uboot-lts2.img /dev/null
K=$($SSHP uname -r 2>/dev/null); echo "== running kernel: ${K:-no SSH}"
if [ -n "$K" ] && [ "$K" != "6.7.0" ]; then
  sed -n "/^cat > \/tmp\/check73.sh/,/^EOF/p" ~/full-73.sh | sed "1d;\$d" > /tmp/check-lts.sh
  $SSHP "sudo -S -p \"\" sh -s" < <(cat ~/oneplus9pro-password.txt /tmp/check-lts.sh)
fi
echo LTS2-DONE
