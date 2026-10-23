#!/bin/sh
set -e
export PATH=$HOME/.local/bin:$PATH
pmbootstrap chroot -- sh -c "set -e; cd /home/pmos/u-boot; \
 make CROSS_COMPILE=aarch64-alpine-linux-musl- O=.output qcom_defconfig qcom-phone.config pmos-lemonadep.config >/dev/null; \
 make CROSS_COMPILE=aarch64-alpine-linux-musl- O=.output -j8 >/tmp/ub-make.log 2>&1 || { tail -25 /tmp/ub-make.log; exit 1; }; tail -3 /tmp/ub-make.log; \
 cd /home/pmos/v2; cat /home/pmos/u-boot/.output/u-boot-nodtb.bin orig.dtb > u-boot-int.bin; gzip -9 -f -k u-boot-int.bin; \
 mkimage -f pmos.its pmos.itb >/dev/null && head -c 134217728 /dev/zero > pad.bin && cat pmos.itb pad.bin > pmos-padded.itb && echo itb-ok; \
 rm -f boot-uboot.img; mkbootimg --header_version 3 --kernel u-boot-int.bin.gz --ramdisk pmos-padded.itb --cmdline \"\" --os_version 14.0.0 --os_patch_level 2025-04 -o boot-uboot.img && ls -la u-boot-int.bin.gz pmos.itb boot-uboot.img"
echo BUILD-DONE
