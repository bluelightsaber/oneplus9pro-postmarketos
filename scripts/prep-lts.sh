#!/bin/bash
# Prepara la prueba del kernel genérico linux-postmarketos-lts (binario oficial de pmOS) en el chroot
# buildroot_aarch64: initramfs propio generado por mkinitfs (con UFS, btrfs y gadget NCM) y boot.img con
# U-Boot + FIT (Image extraída del vmlinuz EFI zboot + initramfs + DTB del 9 Pro de producción).
# No toca el móvil. Lecciones: mkinitfs 2.11 solo escribe vía boot-deploy (necesita el DTB en /boot/dtbs
# y android-tools), los módulos extra van por NOMBRE en /etc/mkinitfs/modules/*.modules, y hacen falta
# postmarketos-initramfs + postmarketos-base-udev.
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; W=$P/pmbootstrap-work; V=$W/chroot_native/home/pmos/v2
R=$W/chroot_rootfs_oneplus-lemonadep; B=$W/chroot_buildroot_aarch64
PKG=${1:-linux-postmarketos-lts}
echo "== chroot aarch64 + $PKG ($(date +%T))"
pmbootstrap chroot -b aarch64 -- sh -c "apk add -u -q $PKG postmarketos-mkinitfs postmarketos-initramfs postmarketos-base-udev android-tools 2>&1 | grep -v WARNING | tail -2" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!" || true
KV=$(ls $B/lib/modules/ | sort -V | tail -1); echo "kernel: $KV"
sudo mkdir -p $B/usr/share/deviceinfo $B/etc/mkinitfs/modules $B/boot/dtbs/qcom
sudo cp $R/usr/share/deviceinfo/* $B/usr/share/deviceinfo/
sudo cp $V/orig.dtb $B/boot/dtbs/qcom/sm8350-oneplus-lemonadep.dtb
printf "%s\n" "# OnePlus 9 Pro: almacenamiento UFS y su PHY, necesarios para montar el rootfs" "ufs-qcom" "phy-qcom-qmp-ufs" "btrfs" "phy-qcom-snps-femto-v2" "phy-qcom-qmp-combo" | sudo tee $B/etc/mkinitfs/modules/10-lemonadep.modules >/dev/null
# newer boot-deploy sources /usr/lib/os-release, absent in the buildroot chroot
[ -e $B/usr/lib/os-release ] || sudo cp $(ls $P/pmbootstrap-work/chroot_rootfs_*/usr/lib/os-release | head -1) $B/usr/lib/os-release
echo "== mkinitfs ($(date +%T))"
pmbootstrap chroot -b aarch64 -- sh -c "mkinitfs 2>&1 | grep -iE 'error|fail|completed' | tail -3" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
IKV=$(sudo sh -c "zcat $B/boot/initramfs | cpio -t 2>/dev/null" | grep -oE "lib/modules/[^/]+" | sort -u | sed "s|lib/modules/||")
[ "$IKV" = "$KV" ] || { echo "!! initramfs has modules for $IKV, kernel is $KV (mkinitfs/boot-deploy failed?)"; exit 1; }
sudo sh -c "zcat $B/boot/initramfs | cpio -t 2>/dev/null" | grep -cE "ufs-qcom|phy-qcom-qmp-ufs|btrfs.ko|usb_f_ncm" | sed "s/^/módulos clave en el initramfs: /;s/$/ de 4/"
sudo python3 - "$B/boot/vmlinuz" "$V/Image-lts" <<'EOF'
import struct, sys, gzip
d = open(sys.argv[1], "rb").read()
assert d[:2] == b"MZ" and d[4:8] == b"zimg", "no es EFI zboot"
off, size = struct.unpack("<II", d[8:16])
assert d[24:32].rstrip(b"\0") == b"gzip"
img = gzip.decompress(d[off:off + size])
open(sys.argv[2], "wb").write(img)
print("Image extraída:", len(img), "bytes, magic", img[56:60])
EOF
sudo cp $B/boot/initramfs $V/initramfs-lts
sudo sed -e 's|data = /incbin/("Image")|data = /incbin/("Image-lts")|' -e 's|data = /incbin/("initramfs")|data = /incbin/("initramfs-lts")|' -e 's|mainline 6.7|generic LTS|' $V/pmos.its | sudo tee $V/pmos-lts.its >/dev/null
pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && mkimage -f pmos-lts.its pmos-lts.itb >/dev/null && cat pmos-lts.itb pad112.bin > pmos-lts-padded.itb && rm -f boot-uboot-lts.img && mkbootimg --header_version 3 --kernel u-boot-int.bin.gz --ramdisk pmos-lts-padded.itb --cmdline \"\" --os_version 14.0.0 --os_patch_level 2025-04 -o boot-uboot-lts.img && ls -la pmos-lts.itb boot-uboot-lts.img" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
echo "== fin ($(date +%T))"; echo PREPLTS-DONE
