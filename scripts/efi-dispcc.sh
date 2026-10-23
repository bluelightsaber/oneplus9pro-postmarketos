#!/bin/bash
# dispcc diagnosis: 7.3-fb kernel (no-init-park patch) booted via U-Boot bootefi with an EFI earlycon on
# screen, WITHOUT initcall_blacklist=disp_cc_sm8250_driver_init, so the screen shows what happens after
# dispcc probes. Output: v2/boot-uboot-efi-dispcc.img. Production env/U-Boot restored at the end.
# Usage: efi-dispcc.sh ["extra bootargs"]
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
EXTRA=${1:-"earlycon=efifb keep_bootcon initcall_debug boot_delay=15 loglevel=8 ignore_loglevel panic=0"}
P=/srv/oneplus9pro-pmos
C=$P/pmbootstrap-work/chroot_native/home/pmos
ENV=$C/u-boot/board/qualcomm/pmos-lemonadep.env
# FIT with the 7.3-fb kernel + its DTB
KBUILD=$P/src/build-7.3-fb ~/fit-7.3.sh 2>&1 | grep -E "FIT-DONE|incbin" || true
sudo cp $ENV /tmp/env.prod
trap 'sudo cp /tmp/env.prod $ENV' EXIT
sudo sed -i -E "s/initcall_blacklist=disp_cc_sm8250_driver_init ?//; s/msm.separate_gpu_kms=1 ?//" $ENV
sudo sed -i -E "s|^pmos_bootargs=|pmos_bootargs=$EXTRA |" $ENV
sudo sed -i -E 's|bootm \$\{ramdisk_addr_r\};|imxtract ${ramdisk_addr_r} fdt 0x1f0000000; imxtract ${ramdisk_addr_r} kernel 0x200000000; echo kernel size ${filesize}; bootefi 0x200000000:${filesize} 0x1f0000000;|' $ENV
grep -c "bootefi 0x200000000" $ENV | sed 's/^/bootefi lines: /'
{ grep -c disp_cc_sm8250 $ENV || true; } | sed 's/^/dispcc blacklist lines (must be 0): /'
grep "^pmos_bootargs" $ENV | cut -c1-200
~/uboot-build.sh >/tmp/efid-ub.log 2>&1 || { tail -20 /tmp/efid-ub.log; exit 1; }
pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && rm -f boot-uboot-efi-dispcc.img && mkbootimg --header_version 3 --kernel u-boot-int.bin.gz --ramdisk pmos-7.3-padded.itb --cmdline \"\" --os_version 14.0.0 --os_patch_level 2025-04 -o boot-uboot-efi-dispcc.img && ls -la boot-uboot-efi-dispcc.img" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
sudo cp /tmp/env.prod $ENV; trap - EXIT
~/uboot-build.sh >/tmp/efid-restore.log 2>&1 || { tail -20 /tmp/efid-restore.log; exit 1; }
echo "production restored: $(sudo strings $C/u-boot/.output/u-boot-nodtb.bin | grep -c 'bootefi 0x2000') bootefi strings (must be 0), $(sudo strings $C/u-boot/.output/u-boot-nodtb.bin | grep -c disp_cc_sm8250_driver_init) blacklist (must be >0)"
echo EFIDISPCC-DONE
