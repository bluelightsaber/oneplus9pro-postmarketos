#!/bin/bash
set -e
cd /srv/oneplus9pro-pmos/scripts
O="-o BatchMode=yes -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone"
scp $O usb-gadget-ensure usb-gadget-ensure.service user@172.16.42.1:/tmp/
ssh $O user@172.16.42.1 'sudo -S -p "" sh -s' < <(cat ~/oneplus9pro-password.txt install-gadget-ensure.sh)
