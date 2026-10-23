#!/bin/bash
# Ajustes del rootfs btrfs antes de flashear, y regeneración de las imágenes de U-Boot.
#  - /var/log y /var/tmp sin CoW (chattr +C, recreados para que el contenido existente también lo sea)
#  - noatime en todas las entradas btrfs del fstab, /tmp en tmpfs
#  - bootargs de U-Boot con los UUID nuevos y el initramfs nuevo en la FIT
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos
W=$P/pmbootstrap-work
IMG=$W/chroot_native/home/pmos/rootfs/oneplus-lemonadep.img
V=$W/chroot_native/home/pmos/v2
ENV=$W/chroot_native/home/pmos/u-boot/board/qualcomm/pmos-lemonadep.env
M=/tmp/pmos-rootfs-mnt

pmbootstrap shutdown >/dev/null 2>&1 || true
# la imagen de pmbootstrap es Android sparse: pasarla a cruda para montarla
RAW=${IMG%.img}.raw
if [ ! -f "$RAW" ]; then
  pmbootstrap chroot -- sh -c "apk add -q android-tools-simg2img android-tools-img2simg >/dev/null 2>&1; cd /home/pmos/rootfs && simg2img oneplus-lemonadep.img oneplus-lemonadep.raw && mv oneplus-lemonadep.img oneplus-lemonadep.sparse-orig"
fi
# el deviceinfo usa sectores de 4096 (rootfs_image_sector_size): la GPT solo se ve con -b 4096
LOOP=$(sudo losetup -b 4096 -fP --show "$RAW")
lsblk -o NAME,SIZE,FSTYPE,LABEL $LOOP
trap 'sudo umount -R $M 2>/dev/null || true; sudo losetup -d $LOOP 2>/dev/null || true' EXIT
sudo mkdir -p $M
sudo mount -o subvolid=5 ${LOOP}p2 $M
ls $M

# --- sin CoW en /var/log y /var/tmp (dentro del subvolumen @var)
for d in log tmp; do
  t=$M/@var/$d
  if [ -d "$t" ] && ! sudo lsattr -d "$t" | cut -d" " -f1 | grep -q C; then
    sudo mv "$t" "$t.cow"
    sudo mkdir "$t"
    sudo chown --reference="$t.cow" "$t"; sudo chmod --reference="$t.cow" "$t"
    sudo chattr +C "$t"
    sudo cp -a "$t.cow/." "$t/"
    sudo rm -rf "$t.cow"
  fi
  sudo lsattr -d "$t"
done

# --- fstab: noatime en btrfs y /tmp en tmpfs
F=$M/@/etc/fstab
sudo sed -i -E '/ btrfs /{/noatime/!s/(subvol=[^, ]+)/\1,noatime/}' $F
grep -q "^tmpfs /tmp " $F || echo "tmpfs /tmp tmpfs nosuid,nodev,mode=1777 0 0" | sudo tee -a $F >/dev/null
sudo cat $F

sudo umount -R $M; sudo losetup -d $LOOP; trap - EXIT

# volver a sparse con el nombre que espera pmbootstrap
pmbootstrap chroot -- sh -c "cd /home/pmos/rootfs && img2simg oneplus-lemonadep.raw oneplus-lemonadep.img && rm oneplus-lemonadep.raw"
ls -la $W/chroot_native/home/pmos/rootfs/

# --- bootargs con los UUID nuevos, initramfs nuevo en la FIT
BI=$W/chroot_rootfs_oneplus-lemonadep/boot/boot.img
CMD=$(sudo python3 -c "f=open('$BI','rb').read(1700); print(f[64:576].split(b'\0')[0].decode())")
for k in pmos_boot_uuid pmos_root_uuid pmos_rootfsopts; do
  v=$(echo "$CMD" | tr ' ' '\n' | grep "^$k=" | cut -d= -f2-)
  sudo sed -i -E "s|$k=[^ ]*|$k=$v|" $ENV
done
grep "^pmos_bootargs" $ENV
sudo cp $W/chroot_rootfs_oneplus-lemonadep/boot/initramfs $V/initramfs

~/uboot-build.sh
~/fit-7.3.sh
echo AJUSTES-DONE
