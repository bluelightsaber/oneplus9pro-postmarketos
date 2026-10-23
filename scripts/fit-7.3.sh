#!/bin/bash
# Empaqueta Image + DTB de mainline 7.3 con el initramfs de pmOS en una FIT, y genera
# boot-uboot-7.3.img (mismo U-Boot) para probar con "fastboot boot". Idempotente.
# El DTB lleva un nodo ramoops para que el log del kernel sobreviva a un reinicio.
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; V=$P/pmbootstrap-work/chroot_native/home/pmos/v2; B=${KBUILD:-$P/src/build-7.3}
sudo cp $B/arch/arm64/boot/Image $V/Image-7.3
sudo cp $B/arch/arm64/boot/dts/qcom/sm8350-oneplus-lemonadep.dtb $V/lemonadep-7.3.dtb
~/add-ramoops.sh /home/pmos/v2/lemonadep-7.3.dtb | grep -E "ramoops|reg ="
[ -n "${DTB_CMDS:-}" ] && pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && DTB=lemonadep-7.3.dtb && $DTB_CMDS" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!" || true
sudo sed -e "s|data = /incbin/(\"Image\")|data = /incbin/(\"Image-7.3\")|" -e "s|data = /incbin/(\"orig.dtb\")|data = /incbin/(\"lemonadep-7.3.dtb\")|" -e "s|mainline 6.7|mainline 7.3|" $V/pmos.its | sudo tee $V/pmos-7.3.its >/dev/null
grep -E "incbin|description = \"postmarketOS" $V/pmos-7.3.its | sed "s/^\s*//" | cut -c1-90
pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && mkimage -f pmos-7.3.its pmos-7.3.itb >/dev/null && head -c 117440512 /dev/zero > pad112.bin && cat pmos-7.3.itb pad112.bin > pmos-7.3-padded.itb && rm -f boot-uboot-7.3.img && mkbootimg --header_version 3 --kernel u-boot-int.bin.gz --ramdisk pmos-7.3-padded.itb --cmdline \"\" --os_version 14.0.0 --os_patch_level 2025-04 -o boot-uboot-7.3.img && ls -la pmos-7.3.itb boot-uboot-7.3.img" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
echo FIT-DONE
