#!/bin/bash
# dispcc proper-fix test: 7.3-fb kernel (FB_SIMPLE + no-init-park patch), normal bootm path with the pmOS
# initramfs (USB SSH), WITHOUT the dispcc initcall_blacklist. The simple-framebuffer node holds the display
# resources so sync_state cannot power them off: power-domains = <&dispcc MDSS_GDSC> and the dispcc
# AHB/MDP/MDP_LUT/VSYNC clocks on top of the GCC ones, plus MMCX at NOM (required-opps): after rpmhpd
# sync_state MMCX otherwise drops to performance level 0 and the MDP (460 MHz) freezes. Output: v2/boot-uboot-7.3fb-dispfix2.img
# Usage: dispfix-73.sh ["extra bootargs"]
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
EXTRA=${1:-"fbcon=font:TER16x32"}
P=/srv/oneplus9pro-pmos
C=$P/pmbootstrap-work/chroot_native/home/pmos; V=$C/v2
ENV=$C/u-boot/board/qualcomm/pmos-lemonadep.env
FB=/chosen/framebuffer@e4d00000
export DTB_CMDS="fdtput -t s \$DTB /soc@0/usb@a6f8800/usb@a600000 dr_mode peripheral && DC=\$(fdtget \$DTB /soc@0/clock-controller@af00000 phandle) && RP=\$(fdtget \$DTB /soc@0/rsc@18200000/power-controller phandle) && NOM=\$(fdtget \$DTB /soc@0/rsc@18200000/power-controller/opp-table/opp6 phandle) && fdtput \$DTB $FB power-domains \$RP 6 \$DC 0 && fdtput \$DTB $FB required-opps \$NOM && fdtput \$DTB $FB clocks 2 27 2 28 \$DC 0 \$DC 32 \$DC 34 \$DC 44 && echo fb: pd=\$(fdtget \$DTB $FB power-domains) opps=\$(fdtget \$DTB $FB required-opps) clocks=\$(fdtget \$DTB $FB clocks)${EXTRA_DTB_CMDS:+ && $EXTRA_DTB_CMDS}"
sudo cp $ENV /tmp/env.prod
trap 'sudo cp /tmp/env.prod $ENV' EXIT
sudo sed -i -E "s/initcall_blacklist=disp_cc_sm8250_driver_init ?//; s/msm.separate_gpu_kms=1 ?//" $ENV
sudo sed -i -E "s|^pmos_bootargs=|pmos_bootargs=$EXTRA |" $ENV
{ grep -c disp_cc_sm8250 $ENV || true; } | sed 's/^/dispcc blacklist lines (must be 0): /'
grep "^pmos_bootargs" $ENV | cut -c1-200
~/uboot-build.sh >/tmp/dfx-ub.log 2>&1 || { tail -20 /tmp/dfx-ub.log; exit 1; }
KBUILD=$P/src/build-7.3-fb ~/fit-7.3.sh 2>&1 | grep -E "fb: pd|boot-uboot-7.3|FIT-DONE" || true
sudo cp $V/boot-uboot-7.3.img $V/boot-uboot-7.3fb-dispfix2.img
sudo cp /tmp/env.prod $ENV; trap - EXIT
~/uboot-build.sh >/tmp/dfx-restore.log 2>&1 || { tail -20 /tmp/dfx-restore.log; exit 1; }
echo "production restored: $(sudo strings $C/u-boot/.output/u-boot-nodtb.bin | grep -c disp_cc_sm8250_driver_init) blacklist (must be >0)"
ls -la $V/boot-uboot-7.3fb-dispfix2.img; echo DISPFIX-DONE
