#!/bin/bash
# Experimental variant of the current production (pmOS kernel): production DTB + fdtput commands
# (\$D = the DTB file), optional extra bootargs. Same kernel/initramfs as production.
# Usage: variant-pmos.sh NAME "fdtput cmds" ["extra bootargs"]  -> v2/boot-uboot-pmos-NAME.img
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
NAME=$1; CMDS=$2; EXTRA=${3:-}
P=/srv/oneplus9pro-pmos; C=$P/pmbootstrap-work/chroot_native/home/pmos; V=$C/v2
ENV=$C/u-boot/board/qualcomm/pmos-lemonadep.env
KV=$(ls $P/pmbootstrap-work/chroot_buildroot_aarch64/lib/modules | sort -V | tail -1)
sudo cp $V/lemonadep-prod.dtb $V/lemonadep-$NAME.dtb
pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && D=lemonadep-$NAME.dtb && $CMDS" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!|WARNING" || true
sudo sed -E "s|data = /incbin/\(\"lemonadep-prod.dtb\"\)|data = /incbin/(\"lemonadep-$NAME.dtb\")|" $V/pmos-lts.its | sudo tee $V/pmos-$NAME.its >/dev/null
grep -q "lemonadep-$NAME.dtb" $V/pmos-$NAME.its || { echo "its template does not use lemonadep-prod.dtb"; exit 1; }
if [ -n "$EXTRA" ]; then
  sudo cp $ENV /tmp/env.prod; trap "sudo cp /tmp/env.prod $ENV" EXIT
  sudo sed -i -E "s|^pmos_bootargs=|pmos_bootargs=$EXTRA |" $ENV
fi
~/uboot-build.sh >/tmp/vp-ub.log 2>&1 || { tail -20 /tmp/vp-ub.log; exit 1; }
pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && mkimage -f pmos-$NAME.its pmos-$NAME.itb >/dev/null && cat pmos-$NAME.itb pad112.bin > pmos-$NAME-padded.itb && rm -f boot-uboot-pmos-$NAME.img && mkbootimg --header_version 3 --kernel u-boot-int.bin.gz --ramdisk pmos-$NAME-padded.itb --cmdline \"\" --os_version 14.0.0 --os_patch_level 2025-04 -o boot-uboot-pmos-$NAME.img && ls -la boot-uboot-pmos-$NAME.img" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!|WARNING"
if [ -n "$EXTRA" ]; then sudo cp /tmp/env.prod $ENV; trap - EXIT; ~/uboot-build.sh >/tmp/vp-restore.log 2>&1; fi
echo "image: $V/boot-uboot-pmos-$NAME.img"; echo VARIANTPMOS-DONE
