#!/bin/bash
# Fase 4: flashea el rootfs pmOS (btrfs) en super y U-Boot+6.7 en boot_a, y arranca.
# Confirmado por el usuario. Para ante cualquier error (comprueba el código de salida de cada paso).
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos
V=$P/pmbootstrap-work/chroot_native/home/pmos/v2
L=$P/tests/fase4-$(date +%m%d-%H%M); mkdir -p $L

timeout 10 fastboot devices | grep -q fastboot || { echo "NO EN FASTBOOT"; exit 1; }
timeout 10 fastboot getvar unlocked 2>&1 | head -1

echo "== 1/3 rootfs -> super ($(date +%T))"
pmbootstrap flasher flash_rootfs > $L/flash_rootfs.log 2>&1; rc=$?
grep -E "Sending|Writing|Finished|FAILED|ERROR" $L/flash_rootfs.log | tail -8
[ $rc -eq 0 ] || { echo "flash_rootfs FALLO rc=$rc, paro (log en $L)"; exit 1; }

echo "== 2/3 U-Boot + 6.7 -> boot_a ($(date +%T))"
timeout 120 fastboot flash boot_a $V/boot-uboot.img > $L/flash_boot.log 2>&1; rc=$?
cat $L/flash_boot.log
[ $rc -eq 0 ] || { echo "flash boot_a FALLO rc=$rc, paro"; exit 1; }

echo "== 3/3 reboot ($(date +%T))"
timeout 20 fastboot reboot 2>&1 | tail -1
echo FLASH-DONE
