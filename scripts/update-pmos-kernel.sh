#!/bin/bash
# low CPU/IO priority so builds do not disturb other buildhost services (children and sudo/chroot inherit it)
renice -n 19 -p $$ >/dev/null 2>&1; ionice -c3 -p $$ 2>/dev/null || true
# Update cycle for the production kernel: postmarketOS linux-postmarketos-mainline built locally with
# extra patches: 0100 qcom_battmgr charge_behaviour for SM8350 + oplus_usb_prop (raw Oplus USB properties), 0101 dispcc-sm8250 no-init-park (dispcc can
# probe with the bootloader display running), 0102 ath11k WCN6855 hw1.1 (QCA6490 v1 Wi-Fi), 0103 arm-smmu-qcom
# sm8350-mdss identity domain (needed once MDSS/panel is enabled) and FB_SIMPLE + fbcon font (console on screen). The pmOS kernel
# enforces signed modules, so everything must be in the package build.
#  1. take the upstream APKBUILD from pmaports (origin/main) and compare with what we last built
#  2. regenerate our patch against the new upstream tag (anchored script: fails loudly if the driver changed)
#  3. pmbootstrap build (pkgrel 100+N so our package wins over the official one)
#  4. build-pmos-image.sh: initramfs + FIT + U-Boot boot image, modules to the phone
#  5. RAM test (test-pmos.sh: SSH, charge_behaviour, USB role, reboot to fastboot) + RAM soak
#  6. only with --promote: write the image to boot_a (promote-boot.sh: backup + verify)
# Usage: [REV=n] [SKIPBUILD=1] update-pmos-kernel.sh [--force] [--promote]
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
FORCE=0; PROMOTE=0; REV=${REV:-1}   # REV: our local revision on top of the upstream pkgrel
for a in "$@"; do case $a in --force) FORCE=1;; --promote) PROMOTE=1;; esac; done
P=/srv/oneplus9pro-pmos; W=$P/pmbootstrap-work; A=$W/cache_git/pmaports
D=device/main/linux-postmarketos-mainline; V=$W/chroot_native/home/pmos/v2
STATE=$P/state-pmos-kernel.txt
die() { echo "!! $*"; echo UPDATE-FAILED; exit 1; }

echo "== 1. pmaports ($(date +%T))"
cd $A && git fetch -q origin || die "git fetch pmaports"
UPVER=$(git show origin/main:$D/APKBUILD | sed -n "s/^pkgver=//p")
LAST=$(cat $STATE 2>/dev/null)
echo "upstream: $UPVER, last built: ${LAST:-none}"
[ "$UPVER" = "$LAST" ] && [ $FORCE = 0 ] && { echo "nothing to do"; echo UPDATE-DONE; exit 0; }

echo "== 2. patch against upstream tag"
TAG=v$(echo $UPVER | sed -E "s/_rc/-rc/")                       # 7.3_rc5 -> v7.3-rc5, 7.2.9 -> v7.2.9
cd $P/src/linux
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || sudo git fetch -q --depth 1 origin tag $TAG || die "fetch $TAG"
WT=$P/src/linux-pmos-$TAG
[ -d $WT ] || sudo git worktree add -q --detach $WT $TAG || die "worktree $TAG"
cd $WT && sudo git checkout -q -- . && sudo git clean -fdq -- drivers arch   # a failed earlier run must not leak into the patches
sudo python3 $P/scripts/apply-battmgr-behaviour-73.py drivers/power/supply/qcom_battmgr.c || die "battmgr patch does not apply to $TAG: update apply-battmgr-behaviour-73.py"
sudo python3 $P/scripts/apply-battmgr-oplus-usbprop.py drivers/power/supply/qcom_battmgr.c || die "battmgr oplus_usb_prop does not apply to $TAG: update apply-battmgr-oplus-usbprop.py"
sudo git diff --no-color -- drivers/power/supply/qcom_battmgr.c > /tmp/battmgr.patch; sudo git checkout -q -- drivers/power/supply/qcom_battmgr.c
sudo git checkout -q -- drivers/clk/qcom/dispcc-sm8250.c
sudo python3 $P/scripts/apply-dispcc-noinitpark-73.py drivers/clk/qcom/dispcc-sm8250.c || die "dispcc patch does not apply to $TAG: update apply-dispcc-noinitpark-73.py"
sudo git diff --no-color -- drivers/clk/qcom/dispcc-sm8250.c > /tmp/dispcc.patch; sudo git checkout -q -- drivers/clk/qcom/dispcc-sm8250.c
A11=drivers/net/wireless/ath/ath11k; sudo git checkout -q -- $A11
sudo python3 $P/scripts/ath11k-hw11.py $WT || die "ath11k hw1.1 patch does not apply to $TAG: update ath11k-hw11.py"
sudo git diff --no-color -- $A11 > /tmp/ath11k.patch; sudo git checkout -q -- $A11
SM=drivers/iommu/arm/arm-smmu/arm-smmu-qcom.c; sudo git checkout -q -- $SM
sudo python3 $P/scripts/apply-smmu-sm8350-mdss.py $SM || die "smmu patch does not apply to $TAG"
sudo git diff --no-color -- $SM > /tmp/smmu.patch; sudo git checkout -q -- $SM
# 0104: Samsung AMB670YF01 panel driver (driver + Kconfig + Makefile only; the DT lives in our tree DTB)
PD=drivers/gpu/drm/panel; sudo git checkout -q -- $PD; sudo rm -f $PD/panel-samsung-amb670yf01.c
sudo python3 $P/scripts/add-panel-amb670.py $WT $P/repo/patches/lmdpdg-panel-samsung-amb670yf01-dsc.c >/dev/null && sudo python3 $P/scripts/panel-enable.py $WT/$PD/panel-samsung-amb670yf01.c >/dev/null && sudo python3 $P/scripts/panel-readback.py $WT/$PD/panel-samsung-amb670yf01.c >/dev/null || die "panel driver does not apply to $TAG"
sudo git checkout -q -- arch/arm64/boot/dts/qcom/
sudo git add -N $PD/panel-samsung-amb670yf01.c; sudo git diff --no-color -- $PD > /tmp/panel.patch; sudo git reset -q $PD/panel-samsung-amb670yf01.c; sudo rm -f $PD/panel-samsung-amb670yf01.c; sudo git checkout -q -- $PD
grep -q "panel-samsung-amb670yf01.c" /tmp/panel.patch || die "panel patch empty"
cd $A && git checkout -q origin/main -- $D || die "checkout upstream APKBUILD"
cp /tmp/battmgr.patch $D/0100-qcom_battmgr-charge-behaviour-sm8350.patch
cp /tmp/dispcc.patch $D/0101-dispcc-sm8250-no-init-park.patch
cp /tmp/ath11k.patch $D/0102-ath11k-wcn6855-hw1.1.patch
cp /tmp/smmu.patch $D/0103-arm-smmu-qcom-sm8350-mdss-identity.patch
cp /tmp/panel.patch $D/0104-drm-panel-samsung-amb670yf01.patch
UPREL=$(sed -n "s/^pkgrel=//p" $D/APKBUILD)
sed -i "s/^pkgrel=.*/pkgrel=$((100 + 10 * UPREL + REV))/" $D/APKBUILD
sed -i "0,/^source=\"/s|^source=\"|source=\"\n\t0100-qcom_battmgr-charge-behaviour-sm8350.patch|" $D/APKBUILD
grep -q "0100-qcom_battmgr" $D/APKBUILD || die "could not add the patch to the APKBUILD"
sed -i "0,/0100-qcom_battmgr-charge-behaviour-sm8350.patch/s|0100-qcom_battmgr-charge-behaviour-sm8350.patch|0100-qcom_battmgr-charge-behaviour-sm8350.patch\n\t0101-dispcc-sm8250-no-init-park.patch|" $D/APKBUILD
grep -q "0101-dispcc" $D/APKBUILD || die "could not add the dispcc patch to the APKBUILD"
sed -i "0,/0101-dispcc-sm8250-no-init-park.patch/s|0101-dispcc-sm8250-no-init-park.patch|0101-dispcc-sm8250-no-init-park.patch\n\t0102-ath11k-wcn6855-hw1.1.patch\n\t0103-arm-smmu-qcom-sm8350-mdss-identity.patch\n\t0104-drm-panel-samsung-amb670yf01.patch|" $D/APKBUILD
grep -q "0102-ath11k" $D/APKBUILD && grep -q "0103-arm-smmu" $D/APKBUILD || die "could not add 0102/0103 to the APKBUILD"
# console on screen: simplefb (bootloader framebuffer, see build-pmos-image.sh) + a large font
CF=$D/config-mainline.aarch64
sed -i "s/^# CONFIG_FB_SIMPLE is not set/CONFIG_FB_SIMPLE=y/; s/^# CONFIG_FONTS is not set/CONFIG_FONTS=y\nCONFIG_FONT_8x16=y\nCONFIG_FONT_TER16x32=y/" $CF
grep -q "^CONFIG_FB_SIMPLE=y" $CF && grep -q "^CONFIG_FONT_TER16x32=y" $CF || die "config: FB_SIMPLE/FONT_TER16x32 not set"
grep -q "DRM_PANEL_SAMSUNG_AMB670YF01" $CF || echo "CONFIG_DRM_PANEL_SAMSUNG_AMB670YF01=m" >> $CF
# console rotation (btop on a landscape console; fbcon rotate_all is set at boot by a systemd unit)
sed -i "/CONFIG_FRAMEBUFFER_CONSOLE_ROTATION/d" $CF; echo "CONFIG_FRAMEBUFFER_CONSOLE_ROTATION=y" >> $CF
pmbootstrap checksum linux-postmarketos-mainline >/dev/null 2>&1 || die "checksum"

echo "== 3. pmbootstrap build ($(date +%T))"
N=$W/chroot_native/home/pmos/src; mountpoint -q $N && sudo umount $N
pmbootstrap shutdown >/dev/null 2>&1
if [ "${SKIPBUILD:-0}" = 1 ]; then echo "SKIPBUILD=1: reusing the package already built"; else
pmbootstrap -y build --lax --arch aarch64 --force linux-postmarketos-mainline > /tmp/pkgbuild.log 2>&1 || { tail -20 /tmp/pkgbuild.log; die "package build"; }
fi
echo "built $(date +%T)"

echo "== 4. boot image + modules on the phone"
# the new package usually has the same kernel version as production: save production modules first, so they
# can be restored if the new image is not promoted (the pmOS kernel only loads modules signed by its own build)
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PKV=$($SSHP uname -r) || die "phone not reachable"
$SSHP "sudo -S -p \"\" tar -C /lib/modules -cf /data/.modules-backup-$PKV.tar $PKV" < $HOME/oneplus9pro-password.txt || die "could not back up production modules"
pmbootstrap chroot -b aarch64 -- apk del -q linux-postmarketos-lts linux-postmarketos-stable >/dev/null 2>&1
~/build-pmos-image.sh linux-postmarketos-mainline 2>&1 | grep -vE "^\[" | tail -8 | tee /tmp/pmosimg.log
grep -q PMOSIMG-DONE /tmp/pmosimg.log || die "image build"
IMG=$(sed -n "s/^image: //p" /tmp/pmosimg.log)

echo "== 5. RAM test + 15 min soak"
~/test-pmos.sh $IMG 2>&1 | grep -vE "^\[" | tee /tmp/testpmos.log
grep -qE "charge_behaviour: .*(\[auto\]|\[inhibit-charge\])" /tmp/testpmos.log || die "charge_behaviour missing on the new kernel"
grep -q "FASTBOOT reached from Linux" /tmp/testpmos.log || die "reboot to fastboot from Linux failed"
sleep 60
~/soak-ram.sh $IMG 15 2>&1 | tail -4 | tee /tmp/soak.log
grep -q SOAKRAM-DONE /tmp/soak.log || die "RAM soak failed"
echo $UPVER | sudo tee $STATE >/dev/null

if [ $PROMOTE = 1 ]; then
  echo "== 6. promote to boot_a"
  sleep 60; ~/promote-boot.sh $IMG || die "promote"
else
  echo "== 6. not promoted (run with --promote, or: ~/promote-boot.sh $IMG)"
  echo "   restoring the production modules ($PKV) so the running production kernel keeps working"
  sleep 60; for i in $(seq 1 40); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && break; sleep 4; done; sleep 10
  $SSHP "sudo -S -p \"\" sh -c \"[ -s /data/.modules-backup-$PKV.tar ] && rm -rf /lib/modules/$PKV && tar -C /lib/modules -xf /data/.modules-backup-$PKV.tar && depmod $PKV && echo restored && (sleep 2; systemctl reboot) &\"" < $HOME/oneplus9pro-password.txt
  echo "   NOTE: to promote later, first reinstall the new modules (build-pmos-image.sh step 4) or rerun with SKIPBUILD=1 --promote"
fi
echo UPDATE-DONE
