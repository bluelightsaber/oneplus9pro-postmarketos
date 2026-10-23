#!/bin/bash
# Install Alpine/pmOS packages on the offline phone: fetch them (with deps) in the buildroot aarch64 chroot,
# copy ONLY the packages not already installed on the phone (installed ones are never up/downgraded),
# then apk add --no-network. Usage: phone-apk-install.sh pkg1 pkg2 ...
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; B=$P/pmbootstrap-work/chroot_buildroot_aarch64
SSHP="ssh -o BatchMode=yes -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
SCPO="-o BatchMode=yes -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone"
pmbootstrap chroot -b aarch64 -- sh -c "rm -rf /tmp/phonepk && mkdir /tmp/phonepk && cd /tmp/phonepk && apk fetch -q -R $* 2>&1 | tail -3" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!|WARNING" || true
$SSHP "apk info 2>/dev/null" | sort -u > /tmp/phone-installed.txt
D=/tmp/phonepk-copy; rm -rf $D; mkdir -p $D
for f in $B/tmp/phonepk/*.apk; do
  n=$(basename $f .apk); name=$(echo $n | sed -E 's/-[0-9][^-]*-r[0-9]+$//')
  grep -qx "$name" /tmp/phone-installed.txt || sudo cp $f $D/
done
echo "to install: $(ls $D | wc -l) packages ($(du -sh $D | cut -f1))"; ls $D | sed 's/^/  /'
$SSHP "rm -rf /tmp/pk && mkdir /tmp/pk"
scp -q $SCPO $D/*.apk user@172.16.42.1:/tmp/pk/
$SSHP "sudo -S -p '' apk add --no-network /tmp/pk/*.apk 2>&1 | tail -4; rm -rf /tmp/pk" < $HOME/oneplus9pro-password.txt
echo PHONEAPK-DONE
