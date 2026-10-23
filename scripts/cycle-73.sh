#!/bin/bash
# Full cycle: rebuild 7.3-fb (incremental), stage modules, install them on the phone (production),
# build the periph-DTB boot image and RAM-test it. The fallback service returns the phone to production.
set -uo pipefail
export DTB_CMDS="fdtput -t s \$DTB /soc@0/usb@a6f8800/usb@a600000 dr_mode peripheral"
~/kernel-build-73-fb2.sh || exit 1
V=/srv/oneplus9pro-pmos/pmbootstrap-work/chroot_native/home/pmos/v2
sudo cp $V/boot-uboot-7.3.img $V/boot-uboot-7.3fb-periph.img
~/install-modules-73fb.sh | tail -2
cat > /tmp/diag73.sh <<"D"
echo "== $(uname -r)"; uptime
sudo -n true 2>/dev/null; touch /run/keep-experiment 2>/dev/null || echo "(could not create keep file without sudo)"
for b in /sys/class/power_supply/*; do echo "$(basename $b): $(cat $b/capacity 2>/dev/null) $(cat $b/status 2>/dev/null) online=$(cat $b/online 2>/dev/null)"; done
for r in /sys/class/remoteproc/*; do echo "$(cat $r/name 2>/dev/null) $(cat $r/state)"; done
systemctl --failed --no-legend | head
echo "errors: $(dmesg 2>/dev/null | grep -ciE "error|fail")"
D
~/exp-ram.sh $V/boot-uboot-7.3fb-periph.img /tmp/diag73.sh
echo CYCLE-DONE
