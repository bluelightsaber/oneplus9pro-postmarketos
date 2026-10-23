#!/bin/bash
# Copies the staged 7.3-fb modules to the phone and runs depmod for that version. The old tree of THAT
# version is removed first (stale modules, e.g. a drm.ko from when DRM was =m, break depmod/modprobe).
set -euo pipefail
P=/srv/oneplus9pro-pmos; M=$P/src/modules-7.3-fb/lib/modules
KV=$(ls $M); echo "kernel: $KV"
# guard: never let an empty/odd version reach the remote rm (2026-10-09 incident: rm -rf /lib/modules/)
[[ "$KV" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[A-Za-z0-9.+-]+$ ]] || { echo "refusing: bad kernel version '$KV'"; exit 1; }
[ "$KV" != "$(cat $P/state-pmos-kernel.txt 2>/dev/null | sed -E 's/_rc/.0-rc/')" ] || { echo "refusing: $KV looks like the production kernel"; exit 1; }
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
sudo tar -C $M -cf - --exclude=build --exclude=source $KV | $SSHP "cat > /tmp/mods.tar"
cat > /tmp/inst-remote.sh <<R
set -e
rm -rf "/usr/lib/modules/$KV"
tar -C /usr/lib/modules -xf /tmp/mods.tar
depmod "$KV"
rm /tmp/mods.tar
du -sh "/usr/lib/modules/$KV"; df -h / | tail -1
R
$SSHP "sudo -S -p '' sh -s" < <(cat $HOME/oneplus9pro-password.txt /tmp/inst-remote.sh)
echo INSTALL-DONE
