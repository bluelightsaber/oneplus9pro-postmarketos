#!/bin/bash
# Prepara la prueba del 7.3 sobre producción: instantánea btrfs, módulos 7.3 en el móvil y boot.img de prueba.
set -euo pipefail
P=/srv/oneplus9pro-pmos
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt
rootsh() { { cat $PW; echo "$1"; } | $SSHP "sudo -S -p '' sh -s"; }

echo "== 1. instantánea btrfs"
TAG=pre-7.3-$(date +%m%d-%H%M)
rootsh "mkdir -p /.snapshots/$TAG && btrfs subvolume snapshot -r / /.snapshots/$TAG/root && btrfs subvolume snapshot -r /var /.snapshots/$TAG/var && btrfs subvolume list / | grep $TAG"

echo "== 2. módulos 7.3"
MV=$(ls $P/src/modules-7.3/lib/modules/)
echo "versión: $MV"
sudo tar -C $P/src/modules-7.3/lib/modules -czf /tmp/modules-$MV.tgz $MV
$SSHP "cat > /tmp/modules.tgz" < /tmp/modules-$MV.tgz
rootsh "tar -C /lib/modules -xzf /tmp/modules.tgz && depmod $MV && rm /tmp/modules.tgz && ls /lib/modules/ && du -sh /lib/modules/$MV"

echo "== 3. boot.img 7.3"
~/fit-7.3.sh 2>&1 | grep -E "boot-uboot-7.3|FIT-DONE"
echo PREP-DONE
