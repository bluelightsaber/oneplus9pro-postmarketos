#!/bin/bash
# Panel work on the 7.3-fb test kernel: enable the AMB670YF01 panel driver (module), incremental build of
# Image + dtbs + modules, stage the modules and install them on the phone (production running).
set -euo pipefail
exec 9>/tmp/kernel-build.lock; flock -n 9 || { echo "another build is running"; exit 1; }
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; N=$P/pmbootstrap-work/chroot_native/home/pmos/src
sudo mkdir -p $N; mountpoint -q $N || sudo mount --bind $P/src $N
K="make ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl- CC=\"ccache aarch64-alpine-linux-musl-gcc\" O=../build-7.3-fb"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && ./scripts/config --file ../build-7.3-fb/.config -m DRM_PANEL_SAMSUNG_AMB670YF01 && $K olddefconfig >/dev/null && grep -E \"^CONFIG_(DRM_PANEL_SAMSUNG_AMB670YF01|DRM_MSM|DRM_MSM_DSI)=\" ../build-7.3-fb/.config | tr \"\\n\" \" \"" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
echo; echo "== build $(date +%T)"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && $K -j8 Image dtbs modules > ../build-7.3-fb/build-panel.log 2>&1 && echo BUILD-OK || { grep -E \"error|Error\" ../build-7.3-fb/build-panel.log | head -20; exit 1; }" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
grep -E "warning:.*amb670" $P/src/build-7.3-fb/build-panel.log | head -5 || true
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && rm -rf ../modules-7.3-fb && $K INSTALL_MOD_PATH=../modules-7.3-fb INSTALL_MOD_STRIP=1 modules_install >/dev/null && find ../modules-7.3-fb -name \"panel-samsung-amb670yf01*\"" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
~/install-modules-73fb.sh | tail -2
echo "== done $(date +%T)"; echo PANELBUILD-DONE
