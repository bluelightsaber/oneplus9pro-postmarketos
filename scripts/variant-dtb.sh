#!/bin/bash
# Genera una variante de producción (6.7) con un DTB modificado por una lista de comandos fdtput,
# sin alterar el DTB ni la imagen de producción (se restauran al final).
# Uso: variant-dtb.sh NOMBRE 'fdtput ... ; fdtput ...'   (las rutas del DTB como DTB)
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
NAME=$1; CMDS=$2
P=/srv/oneplus9pro-pmos; V=$P/pmbootstrap-work/chroot_native/home/pmos/v2
sudo cp $V/orig.dtb /tmp/orig.dtb.prod
trap 'sudo cp /tmp/orig.dtb.prod $V/orig.dtb' EXIT
pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && DTB=orig.dtb && $CMDS" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
~/uboot-build.sh >/tmp/vd.log 2>&1 || { tail -20 /tmp/vd.log; exit 1; }
sudo cp $V/boot-uboot.img $V/boot-uboot-$NAME.img
sudo cp /tmp/orig.dtb.prod $V/orig.dtb; trap - EXIT
~/uboot-build.sh >/tmp/vd-restore.log 2>&1 || { tail -20 /tmp/vd-restore.log; exit 1; }
ls -la $V/boot-uboot-$NAME.img
echo VARIANTDTB-DONE
