#!/bin/bash
# Genera boot-uboot-7.3.img con bootargs extra (variante experimental del 7.3) sin alterar
# el entorno ni la imagen de producción (que se reconstruyen como estaban al final).
# Uso: variant-7.3.sh "parametros extra"
set -euo pipefail
EXTRA=$1
P=/srv/oneplus9pro-pmos
C=$P/pmbootstrap-work/chroot_native/home/pmos
ENV=$C/u-boot/board/qualcomm/pmos-lemonadep.env
sudo cp $ENV /tmp/env.prod
trap 'sudo cp /tmp/env.prod $ENV' EXIT
sudo sed -i -E "s|pmos_rootfsopts=subvol=@,|pmos_rootfsopts=subvol=@,notreelog,|" $ENV; sudo sed -i -E "s|^pmos_bootargs=|pmos_bootargs=$EXTRA |" $ENV
grep "^pmos_bootargs" $ENV | cut -c1-140
~/uboot-build.sh >/tmp/v73-ub.log 2>&1 || { tail -20 /tmp/v73-ub.log; exit 1; }
~/fit-7.3.sh 2>&1 | grep -E "boot-uboot-7.3|FIT-DONE"
# restaurar entorno y U-Boot de producción
sudo cp /tmp/env.prod $ENV; trap - EXIT
~/uboot-build.sh >/tmp/v73-restore.log 2>&1 || { tail -20 /tmp/v73-restore.log; exit 1; }
echo "produccion restaurada: $(sudo strings $C/u-boot/.output/u-boot-nodtb.bin | grep -c "$(echo $EXTRA | cut -d' ' -f1)") coincidencias del extra (debe ser 0)"
echo VARIANT73-DONE
