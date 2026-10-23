#!/bin/bash
# 7.3-fb: make USB gadget (configfs/libcomposite/NCM) and the QMP combo PHY built-in, like on 6.7,
# because the initramfs (from 6.7) cannot load 7.3 modules. Incremental rebuild + modules + boot image.
set -euo pipefail
exec 9>/tmp/kernel-build.lock; flock -n 9 || { echo "another build is running"; exit 1; }
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; N=$P/pmbootstrap-work/chroot_native/home/pmos/src
sudo mkdir -p $N; mountpoint -q $N || sudo mount --bind $P/src $N
K="make ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl- CC=\"ccache aarch64-alpine-linux-musl-gcc\" O=../build-7.3-fb"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && ./scripts/config --file ../build-7.3-fb/.config -e USB_LIBCOMPOSITE -e USB_CONFIGFS -e USB_CONFIGFS_NCM -e USB_F_NCM -e DRM -e PHY_QCOM_QMP_COMBO -e PHY_QCOM_USB_SNPS_FEMTO_V2 -e PHY_QCOM_QUSB2 -e PHY_QCOM_USB_HS && $K olddefconfig >/dev/null && grep -E \"^CONFIG_(USB_LIBCOMPOSITE|USB_CONFIGFS|USB_F_NCM|PHY_QCOM_QMP_COMBO)=\" ../build-7.3-fb/.config | tr \"\\n\" \" \"" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
echo; echo "== build $(date +%T)"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && $K -j8 Image dtbs modules > ../build-7.3-fb/build2.log 2>&1 && echo BUILD-OK || { tail -30 ../build-7.3-fb/build2.log; exit 1; }" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && rm -rf ../modules-7.3-fb && $K INSTALL_MOD_PATH=../modules-7.3-fb INSTALL_MOD_STRIP=1 modules_install >/dev/null && du -sh ../modules-7.3-fb" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
KBUILD=$P/src/build-7.3-fb ~/variant-7.3.sh "fbcon=font:TER16x32 loglevel=8 ignore_loglevel panic=0 initcall_blacklist=disp_cc_sm8250_driver_init" 2>&1 | tail -2
V=$P/pmbootstrap-work/chroot_native/home/pmos/v2; sudo cp $V/boot-uboot-7.3.img $V/boot-uboot-7.3fb-nodisp.img
echo "== done $(date +%T)"; echo BUILDFB2-DONE
