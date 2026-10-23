#!/bin/bash
# Compila el DTB del 9 Pro sobre lemonadep-7.3 dentro del chroot nativo de pmbootstrap
# (el host no tiene flex/bison y no se instala nada con apt). Idempotente.
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; N=$P/pmbootstrap-work/chroot_native/home/pmos/src
pmbootstrap chroot -- true >/dev/null 2>&1
pmbootstrap chroot -- apk add -q flex bison bc perl openssl-dev elfutils-dev linux-headers python3 dtc >/dev/null 2>&1
sudo mkdir -p $N; mountpoint -q $N || sudo mount --bind $P/src $N
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && make -s ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl- O=../build-7.3 defconfig && make ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl- O=../build-7.3 qcom/sm8350-oneplus-lemonadep.dtb 2>&1 | grep -vE \"^ +(DTC|CPP|HOSTCC|YACC|LEX|HOSTLD|SYNC|GEN|UPD)\" | tail -25" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
ls -la $P/src/build-7.3/arch/arm64/boot/dts/qcom/sm8350-oneplus-lemonadep.dtb 2>/dev/null && echo DTB-OK
echo DTB-DONE
