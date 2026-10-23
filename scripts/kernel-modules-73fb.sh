#!/bin/bash
# Builds and stages the modules of the 7.3-fb kernel (LOCALVERSION -lemonadep-fb) into $P/src/modules-7.3-fb
set -euo pipefail
exec 9>/tmp/kernel-build.lock; flock -n 9 || { echo "another build is running"; exit 1; }
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; N=$P/pmbootstrap-work/chroot_native/home/pmos/src
sudo mkdir -p $N; mountpoint -q $N || sudo mount --bind $P/src $N
K="make ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl- CC=\"ccache aarch64-alpine-linux-musl-gcc\" O=../build-7.3-fb"
echo "== modules $(date +%T)"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && $K -j8 modules > ../build-7.3-fb/modules.log 2>&1 && echo MOD-OK || { tail -30 ../build-7.3-fb/modules.log; exit 1; }" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && rm -rf ../modules-7.3-fb && $K INSTALL_MOD_PATH=../modules-7.3-fb INSTALL_MOD_STRIP=1 modules_install >/dev/null && ls ../modules-7.3-fb/lib/modules/ && du -sh ../modules-7.3-fb" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
echo "== done $(date +%T)"; echo MODFB-DONE
