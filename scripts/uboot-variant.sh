#!/bin/bash
# Genera una variante experimental de boot-uboot.img cambiando los bootargs del entorno de U-Boot,
# sin tocar la imagen de producción (que se regenera igual que estaba al final).
# Uso: uboot-variant.sh NOMBRE 'expresión-sed-sobre-la-línea-pmos_bootargs'
set -euo pipefail
NAME=$1; SED=$2
P=/srv/oneplus9pro-pmos
C=$P/pmbootstrap-work/chroot_native/home/pmos
ENV=$C/u-boot/board/qualcomm/pmos-lemonadep.env
sudo cp $ENV $ENV.prod
trap 'sudo cp $ENV.prod $ENV' EXIT
sudo sed -i -E "/^pmos_bootargs=/ $SED" $ENV
grep "^pmos_bootargs" $ENV | cut -c1-160
~/uboot-build.sh >/tmp/variant-build.log 2>&1 || { tail -20 /tmp/variant-build.log; exit 1; }
sudo cp $C/v2/boot-uboot.img $C/v2/boot-uboot-$NAME.img
# restaurar el entorno y la imagen de producción
sudo cp $ENV.prod $ENV; trap - EXIT
~/uboot-build.sh >/tmp/variant-restore.log 2>&1 || { tail -20 /tmp/variant-restore.log; exit 1; }
ls -la $C/v2/boot-uboot.img $C/v2/boot-uboot-$NAME.img
echo VARIANT-DONE
