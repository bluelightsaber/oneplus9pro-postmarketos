#!/bin/bash
# low CPU/IO priority so builds do not disturb other buildhost services (children and sudo/chroot inherit it)
renice -n 19 -p $$ >/dev/null 2>&1; ionice -c3 -p $$ 2>/dev/null || true
# Builds a boot image for the postmarketOS generic kernel installed in the buildroot chroot and installs
# its modules on the phone (production must be running).
#  DTB: raw lemonadep DTB from our 7.3 tree + modem disabled + USB OTG with role switch (default
#       peripheral) [USBMODE=periph forces dr_mode=peripheral instead]
#       + Adreno 660 GPU enabled with its zap shader [GPU=0 leaves it disabled]
#  bootargs: initcall_blacklist=disp_cc_sm8250_driver_init + notreelog on the rootfs
#       + msm.separate_gpu_kms=1 (GPU-only DRM device, display stays off)
#  PANEL=1 (default): MDSS/DSI/AMB670 panel enabled (package kernel has the driver + SMMU fix); PANEL=0 disables it.
#       WIFI=0: wcn6855-pmu and pcie0 wifi@0 nodes removed, uart18 bluetooth disabled.
#  NAME=x: write lemonadep-prod-x.dtb / boot-uboot-pmos-<kver>-x.img (tests) instead of the production
#       files. SKIPMODS=1: do not copy the modules to the phone.
#  DISPFIX=1 (default; needs a kernel with the 0101 dispcc patch + FB_SIMPLE): the simple-framebuffer node holds
#       MMCX at NOM (required-opps), MDSS_GDSC and the dispcc AHB/MDP/MDP_LUT/VSYNC clocks, so dispcc can probe
#       and sync_state does not starve the running display; bootargs drop the dispcc initcall_blacklist and
#       add fbcon=font:TER16x32 (kernel console on screen). DISPFIX=0 = old behaviour (blacklist).
# Usage: build-pmos-image.sh [package]   -> v2/boot-uboot-pmos-<kver>.img
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
PKG=${1:-linux-postmarketos-mainline}; USBMODE=${USBMODE:-otg}; GPU=${GPU:-1}; DISPFIX=${DISPFIX:-1}
PANEL=${PANEL:-1}; WIFI=${WIFI:-1}; NAME=${NAME:-}; DT=lemonadep-prod${NAME:+-$NAME}.dtb
P=/srv/oneplus9pro-pmos; W=$P/pmbootstrap-work; C=$W/chroot_native/home/pmos; V=$C/v2; B=$W/chroot_buildroot_aarch64
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
# 1) DTB
sudo cp $P/src/build-7.3-fb/arch/arm64/boot/dts/qcom/sm8350-oneplus-lemonadep.dtb $V/$DT
U=/soc@0/usb@a6f8800/usb@a600000
if [ "$USBMODE" = periph ]; then UCMD="fdtput -t s \$D $U dr_mode peripheral"
else UCMD="fdtput -t s \$D $U dr_mode otg && fdtput \$D $U usb-role-switch && fdtput -t s \$D $U role-switch-default-mode peripheral"; fi
G=/soc@0/gpu@3d00000
FB=/chosen/framebuffer@e4d00000; RP=/soc@0/rsc@18200000/power-controller
if [ "$DISPFIX" = 1 ]; then UCMD="$UCMD && DC=\$(fdtget \$D /soc@0/clock-controller@af00000 phandle) && RPH=\$(fdtget \$D $RP phandle) && NOM=\$(fdtget \$D $RP/opp-table/opp6 phandle) && [ \$(fdtget \$D $RP/opp-table/opp6 opp-level) = 256 ] && fdtput \$D $FB power-domains \$RPH 6 \$DC 0 && fdtput \$D $FB required-opps \$NOM && fdtput \$D $FB clocks 2 27 2 28 \$DC 0 \$DC 32 \$DC 34 \$DC 44"; fi
MD=/soc@0/display-subsystem@ae00000; WP=/wcn6855-pmu; WF=/soc@0/pcie@1c00000/pcie@0/wifi@0
if [ "$PANEL" != 1 ]; then UCMD="$UCMD && fdtput -t s \$D $MD status disabled"; fi
# WIFI=1: the QCA6490 rails need the vendor voltages (our DT ranges let them sit at their minimum, e.g. 500 mV)
RG=/soc@0/rsc@18200000
if [ "$WIFI" = 1 ]; then UCMD="$UCMD && fdtput \$D $RG/regulators-0/smps11 regulator-min-microvolt 952000 && fdtput \$D $RG/regulators-0/smps12 regulator-min-microvolt 1352000 && fdtput \$D $RG/regulators-1/smps1 regulator-min-microvolt 1880000 && fdtput \$D $RG/regulators-2/smps2 regulator-min-microvolt 952000 && [ \$(fdtget \$D $RG/regulators-2/smps2 regulator-name) = pmr735a_s2 ]"; fi
BT=/soc@0/geniqup@8c0000/serial@890000/bluetooth
if [ "$WIFI" != 1 ]; then UCMD="$UCMD && { fdtget \$D $BT compatible >/dev/null 2>&1 && fdtput -t s \$D $BT status disabled || true; }"; fi
if [ "$WIFI" != 1 ]; then UCMD="$UCMD && { fdtget \$D $WF compatible >/dev/null 2>&1 && fdtput -r \$D $WF || true; } && { fdtget \$D $WP compatible >/dev/null 2>&1 && fdtput -r \$D $WP || true; }"; fi
if [ "$GPU" = 1 ]; then UCMD="$UCMD && fdtput -t s \$D $G status okay && fdtput -t s \$D $G/zap-shader firmware-name qcom/sm8350/OnePlus/lemonade/a660_zap.mbn"; fi
# EXTRA_UCMD: additional fdtput/fdtget commands on $D (the DTB), for test images (use NAME=...)
[ -n "${EXTRA_UCMD:-}" ] && UCMD="$UCMD && $EXTRA_UCMD"
pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && D=$DT && fdtput -t s \$D /soc@0/remoteproc@4080000 status disabled && $UCMD && \
  echo \"DTB: modem=\$(fdtget \$D /soc@0/remoteproc@4080000 status) usb=\$(fdtget \$D $U dr_mode) gpu=\$(fdtget \$D /soc@0/gpu@3d00000 status) fb_pd=\$(fdtget \$D $FB power-domains 2>/dev/null) default=\$(fdtget \$D $U role-switch-default-mode 2>/dev/null) mdss=\$(fdtget \$D $MD status) wifi=\$(fdtget \$D $WF compatible 2>/dev/null || echo none)\"" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!|WARNING"
# 2) initramfs + Image + FIT template (prep-lts.sh), then point the FIT to the production DTB
~/prep-lts.sh $PKG 2>&1 | grep -E "kernel:|Image|PREPLTS" | grep -v "^$"
KV=$(ls $B/lib/modules | sort -V | tail -1)
[[ "$KV" =~ ^[0-9]+\.[0-9]+ ]] || { echo "refusing: bad kernel version '$KV'"; exit 1; }
IMGKV=$KV${NAME:+-$NAME}
sudo sed -i -E "s|data = /incbin/\(\"[^\"]*\.dtb\"\)|data = /incbin/(\"$DT\")|" $V/pmos-lts.its
grep -c "$DT" $V/pmos-lts.its | sed "s/^/FIT uses $DT: /"
# 3) U-Boot env + boot image
ENV=$C/u-boot/board/qualcomm/pmos-lemonadep.env
sudo cp $ENV /tmp/env.prod; trap "sudo cp /tmp/env.prod $ENV" EXIT
grep -q notreelog $ENV || sudo sed -i -E "s|pmos_rootfsopts=subvol=@,|pmos_rootfsopts=subvol=@,notreelog,|" $ENV
if [ "$DISPFIX" = 1 ]; then
  sudo sed -i -E "s/initcall_blacklist=disp_cc_sm8250_driver_init ?//" $ENV
  grep -q "fbcon=font:" $ENV || sudo sed -i -E "s|^pmos_bootargs=|pmos_bootargs=fbcon=font:TER16x32 |" $ENV
else
  grep -q disp_cc_sm8250 $ENV || sudo sed -i -E "s|^pmos_bootargs=|pmos_bootargs=initcall_blacklist=disp_cc_sm8250_driver_init |" $ENV
fi
if [ "$GPU" = 1 ]; then grep -q separate_gpu_kms $ENV || sudo sed -i -E "s|^pmos_bootargs=|pmos_bootargs=msm.separate_gpu_kms=1 |" $ENV; fi
~/uboot-build.sh >/tmp/pmosimg-ub.log 2>&1 || { tail -20 /tmp/pmosimg-ub.log; exit 1; }
pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && mkimage -f pmos-lts.its pmos-$IMGKV.itb >/dev/null && cat pmos-$IMGKV.itb pad112.bin > pmos-$IMGKV-padded.itb && rm -f boot-uboot-pmos-$IMGKV.img && mkbootimg --header_version 3 --kernel u-boot-int.bin.gz --ramdisk pmos-$IMGKV-padded.itb --cmdline \"\" --os_version 14.0.0 --os_patch_level 2025-04 -o boot-uboot-pmos-$IMGKV.img && ls -la boot-uboot-pmos-$IMGKV.img" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!|WARNING"
sudo cp /tmp/env.prod $ENV; trap - EXIT
~/uboot-build.sh >/tmp/pmosimg-restore.log 2>&1 || { tail -20 /tmp/pmosimg-restore.log; exit 1; }
echo "production U-Boot env restored"
[ -z "$NAME" ] || sudo sed -i -E "s|data = /incbin/\(\"[^\"]*\.dtb\"\)|data = /incbin/(\"lemonadep-prod.dtb\")|" $V/pmos-lts.its
if [ "${SKIPMODS:-0}" = 1 ]; then echo "image: $V/boot-uboot-pmos-$IMGKV.img"; echo PMOSIMG-DONE; exit 0; fi
# 4) modules to the phone (the patched qcom_battmgr is in-tree in our package build, signed by it)
sudo tar -C $B/lib/modules -cf - $KV | $SSHP "cat > /tmp/mods.tar"
$SSHP "sudo -S -p \"\" sh -c \"rm -rf /lib/modules/$KV && tar -C /lib/modules -xf /tmp/mods.tar && depmod $KV && rm /tmp/mods.tar && du -sh /lib/modules/$KV\"" < $HOME/oneplus9pro-password.txt
echo "image: $V/boot-uboot-pmos-$IMGKV.img"; echo PMOSIMG-DONE
