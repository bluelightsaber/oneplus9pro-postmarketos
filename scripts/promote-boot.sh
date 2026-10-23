#!/bin/bash
# Escribe una imagen probada en boot_a desde Linux (dd por SSH), con copia previa y verificación.
# Uso: promote-boot.sh IMAGEN
set -euo pipefail
IMG=$1
P=/srv/oneplus9pro-pmos
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt
sudo_p() { { cat $PW; } | $SSHP "sudo -S -p '' sh -c '$1'"; }

DEV=$(sudo_p 'readlink -f /dev/disk/by-partlabel/boot_a')
SIZE=$(sudo_p "blockdev --getsize64 $DEV")
ISZ=$(stat -c %s "$IMG")
echo "boot_a = $DEV ($SIZE bytes); imagen $ISZ bytes"
[ "$ISZ" -le "$SIZE" ] || { echo "la imagen no cabe"; exit 1; }

B=$P/backups/boot_a-$(date +%m%d-%H%M).img; mkdir -p $P/backups
echo "== copia del boot_a actual -> $B"
sudo_p "cat $DEV" > "$B"
ls -la "$B"

echo "== escribiendo"
$SSHP "cat > /tmp/newboot.img" < "$IMG"
sudo_p "dd if=/tmp/newboot.img of=$DEV bs=4M conv=fsync status=none && sync"

echo "== verificando"
H1=$(sha256sum "$IMG" | cut -d" " -f1)
H2=$(sudo_p "head -c $ISZ $DEV | sha256sum" | cut -d" " -f1)
echo "imagen  $H1"; echo "boot_a  $H2"
[ "$H1" = "$H2" ] && echo "VERIFICADO" || { echo "NO COINCIDE: restaurar con $B"; exit 1; }
$SSHP "rm -f /tmp/newboot.img"
echo PROMOTE-DONE
