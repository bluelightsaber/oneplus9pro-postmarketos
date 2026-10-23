#!/bin/bash
# 7.3 with an on-screen console to diagnose the early hang: simplefb + large font (TER16x32) +
# BOOT_PRINTK_DELAY (slow log, readable/photographable). Separate O= dir (build-7.3-fb).
set -euo pipefail
exec 9>/tmp/kernel-build.lock; flock -n 9 || { echo "another build is running"; exit 1; }
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; N=$P/pmbootstrap-work/chroot_native/home/pmos/src
sudo mkdir -p $N; mountpoint -q $N || sudo mount --bind $P/src $N
mkdir -p $P/src/build-7.3-fb
sudo cp $P/src/build-7.3/.config $P/src/build-7.3-fb/.config
K='make ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl- CC="ccache aarch64-alpine-linux-musl-gcc" O=../build-7.3-fb'
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && ./scripts/config --file ../build-7.3-fb/.config -e FB -e FB_SIMPLE -e SYSFB_SIMPLEFB -e FRAMEBUFFER_CONSOLE -e FRAMEBUFFER_CONSOLE_DETECT_PRIMARY -e FONTS -e FONT_TER16x32 -e FONT_8x16 -e BOOT_PRINTK_DELAY -e PRINTK_TIME -d USB_ETH --set-str LOCALVERSION -lemonadep-fb && $K olddefconfig >/dev/null && ./scripts/config -k --file ../build-7.3-fb/.config -e FONT_TER16x32 && $K olddefconfig >/dev/null && grep -E '^CONFIG_(FB_SIMPLE|SYSFB_SIMPLEFB|FONT_TER16x32|BOOT_PRINTK_DELAY|FRAMEBUFFER_CONSOLE)=' ../build-7.3-fb/.config" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
echo "== build $(date +%T)"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && $K -j8 Image dtbs > ../build-7.3-fb/build.log 2>&1 && echo BUILD-OK || { tail -30 ../build-7.3-fb/build.log; exit 1; }" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
ls -la $P/src/build-7.3-fb/arch/arm64/boot/Image
# boot image: 7.3-fb kernel + 7.3 DTB + 6.7 initramfs; bootargs: big font, slow printk, stay on panic
KBUILD=$P/src/build-7.3-fb ~/variant-7.3.sh "fbcon=font:TER16x32 boot_delay=120 panic=0 loglevel=8 ignore_loglevel" 2>&1 | tail -3
sudo cp $P/pmbootstrap-work/chroot_native/home/pmos/v2/boot-uboot-7.3.img $P/pmbootstrap-work/chroot_native/home/pmos/v2/boot-uboot-7.3fb.img
echo "== done $(date +%T): boot-uboot-7.3fb.img"; echo BUILDFB-DONE
