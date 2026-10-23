#!/bin/bash
# Restore one kernel's modules on the phone from a local modules dir. Usage: restore-mods.sh <modules-parent-dir> <kver>
set -euo pipefail
SRC=$1; KV=$2
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
[ -d "$SRC/$KV" ] || { echo "missing $SRC/$KV"; exit 1; }
sudo tar -C "$SRC" -cf - --exclude=build --exclude=source "$KV" | $SSHP "cat > /tmp/mods-$KV.tar"
cat > /tmp/restore-remote.sh <<R
set -e
mkdir -p /usr/lib/modules
rm -rf "/usr/lib/modules/$KV"
tar -C /usr/lib/modules -xf "/tmp/mods-$KV.tar"
depmod "$KV"
rm "/tmp/mods-$KV.tar"
echo "restored $KV: \$(du -sh /usr/lib/modules/$KV | cut -f1), \$(find /usr/lib/modules/$KV -name '*.ko*' | wc -l) modules"
R
$SSHP "sudo -S -p '' sh -s" < <(cat $HOME/oneplus9pro-password.txt /tmp/restore-remote.sh)
