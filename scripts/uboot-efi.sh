#!/bin/bash
# EFI boot variant for diagnosis: U-Boot extracts kernel + DTB from the FIT and starts the kernel with
# "bootefi" instead of "bootm". The kernel then gets a GOP framebuffer (screen_info) and can print
# from its very first instruction with earlycon=efifb. No initrd (not needed to see where it dies).
# Builds boot-uboot-efi-73.img (7.3-fb FIT) and boot-uboot-efi-lts.img (generic LTS FIT).
# Production env/image are restored at the end.
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
EXTRA=${1:-"earlycon=efifb keep_bootcon boot_delay=60 loglevel=8 ignore_loglevel panic=0"}
P=/srv/oneplus9pro-pmos
C=$P/pmbootstrap-work/chroot_native/home/pmos
ENV=$C/u-boot/board/qualcomm/pmos-lemonadep.env
sudo cp $ENV /tmp/env.prod
trap 'sudo cp /tmp/env.prod $ENV' EXIT
sudo sed -i -E "s|pmos_rootfsopts=subvol=@,|pmos_rootfsopts=subvol=@,notreelog,|" $ENV; sudo sed -i -E "s|^pmos_bootargs=|pmos_bootargs=$EXTRA |" $ENV
sudo sed -i -E 's|bootm \$\{ramdisk_addr_r\};|imxtract ${ramdisk_addr_r} fdt 0x1f0000000; imxtract ${ramdisk_addr_r} kernel 0x200000000; echo kernel size ${filesize}; bootefi 0x200000000:${filesize} 0x1f0000000;|' $ENV
grep -c "bootefi 0x200000000" $ENV | sed 's/^/bootefi lines: /'
grep "^pmos_bootargs" $ENV | cut -c1-120
~/uboot-build.sh >/tmp/efi-ub.log 2>&1 || { tail -20 /tmp/efi-ub.log; exit 1; }
for v in ${VARIANTS:-73:pmos-7.3-padded.itb lts:pmos-lts-padded.itb}; do
  n=${v%%:*}; f=${v#*:}
  pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && rm -f boot-uboot-efi-$n.img && mkbootimg --header_version 3 --kernel u-boot-int.bin.gz --ramdisk $f --cmdline \"\" --os_version 14.0.0 --os_patch_level 2025-04 -o boot-uboot-efi-$n.img && ls -la boot-uboot-efi-$n.img" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
done
sudo cp /tmp/env.prod $ENV; trap - EXIT
~/uboot-build.sh >/tmp/efi-restore.log 2>&1 || { tail -20 /tmp/efi-restore.log; exit 1; }
echo "production restored: $(sudo strings $C/u-boot/.output/u-boot-nodtb.bin | grep -c bootefi\ 0x2000) bootefi strings (must be 0)"
echo EFI-DONE
