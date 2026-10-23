#!/bin/bash
# Variante de depuración del 7.3: g_ether integrado (solo CDC-ECM) + netconsole integrado, para recibir
# el log del kernel en buildhost por UDP desde el primer segundo de arranque. Compila en un O= aparte
# (build-7.3-dbg) para no tocar el árbol "normal".
set -euo pipefail
exec 9>/tmp/kernel-build.lock; flock -n 9 || { echo "ya hay una compilacion en marcha"; exit 1; }
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; N=$P/pmbootstrap-work/chroot_native/home/pmos/src
sudo mkdir -p $N; mountpoint -q $N || sudo mount --bind $P/src $N
mkdir -p $P/src/build-7.3-dbg
sudo cp $P/src/build-7.3/.config $P/src/build-7.3-dbg/.config
K='make ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl- CC="ccache aarch64-alpine-linux-musl-gcc" O=../build-7.3-dbg'
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && ./scripts/config --file ../build-7.3-dbg/.config -e USB_ETH -d USB_ETH_RNDIS -d USB_ETH_EEM -e NETCONSOLE -e NETCONSOLE_DYNAMIC -e NETPOLL -e PRINTK_TIME --set-str LOCALVERSION -lemonadep-dbg && $K olddefconfig >/dev/null && grep -E '^CONFIG_(USB_ETH|USB_ETH_RNDIS|NETCONSOLE|NETPOLL|USB_LIBCOMPOSITE|USB_GADGET)=' ../build-7.3-dbg/.config" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
echo "== build $(date +%T)"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && $K -j8 Image dtbs > ../build-7.3-dbg/build.log 2>&1 && echo BUILD-OK || { tail -30 ../build-7.3-dbg/build.log; exit 1; }" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
ls -la $P/src/build-7.3-dbg/arch/arm64/boot/Image
echo "== fin $(date +%T)"; echo BUILDDBG-DONE
