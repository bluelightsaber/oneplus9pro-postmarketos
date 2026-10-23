#!/bin/bash
# Second attempt with the postmarketOS generic kernel (default linux-postmarketos-lts), applying what
# made mainline 7.3 boot:
#  - USB PHY modules in the initramfs (snps-femto-v2 = USB 2.0 PHY, qmp-combo), so dwc3 binds in time
#    for the initramfs USB gadget;
#  - the mainline 7.3 DTB with dr_mode = "peripheral" (no UCSI role from the OnePlus firmware);
#  - bootargs: initcall_blacklist=disp_cc_sm8250_driver_init (dispcc parks the display RCGs).
# Also copies the kernel modules to the phone (production must be running). Builds boot-uboot-lts2.img.
# Production env/image are restored at the end.
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
PKG=${1:-linux-postmarketos-lts}
P=/srv/oneplus9pro-pmos; W=$P/pmbootstrap-work; C=$W/chroot_native/home/pmos; V=$C/v2
B=$W/chroot_buildroot_aarch64
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
printf "%s\n" "# OnePlus 9 Pro: UFS + PHY for the rootfs, USB PHYs so dwc3 binds before the gadget is set up" \
  "ufs-qcom" "phy-qcom-qmp-ufs" "btrfs" "phy-qcom-snps-femto-v2" "phy-qcom-qmp-combo" \
  | sudo tee $B/etc/mkinitfs/modules/10-lemonadep.modules >/dev/null
# DTB: mainline 7.3 + ramoops + dr_mode peripheral (same as the 7.3 test images)
sudo cp $V/lemonadep-7.3.dtb $B/boot/dtbs/qcom/sm8350-oneplus-lemonadep.dtb
pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && fdtget lemonadep-7.3.dtb /soc@0/usb@a6f8800/usb@a600000 dr_mode" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!|WARNING"
~/prep-lts.sh $PKG 2>&1 | grep -E "kernel:|módulos clave|Image|PREPLTS"
sudo sh -c "zcat $B/boot/initramfs | cpio -t 2>/dev/null" | grep -cE "snps-femto|qmp-combo" | sed "s/^/USB PHY modules in initramfs: /"
# prep-lts.sh put orig.dtb into the FIT template; use the 7.3 DTB instead
sudo sed -i 's|data = /incbin/("orig.dtb")|data = /incbin/("lemonadep-7.3.dtb")|' $V/pmos-lts.its
grep -c "lemonadep-7.3.dtb" $V/pmos-lts.its | sed "s/^/FIT uses 7.3 DTB: /"
# U-Boot env variant with the dispcc blacklist
ENV=$C/u-boot/board/qualcomm/pmos-lemonadep.env
sudo cp $ENV /tmp/env.prod; trap 'sudo cp /tmp/env.prod $ENV' EXIT
sudo sed -i -E "s|pmos_rootfsopts=subvol=@,|pmos_rootfsopts=subvol=@,notreelog,|" $ENV; sudo sed -i -E "s|^pmos_bootargs=|pmos_bootargs=initcall_blacklist=disp_cc_sm8250_driver_init |" $ENV
~/uboot-build.sh >/tmp/lts2-ub.log 2>&1 || { tail -20 /tmp/lts2-ub.log; exit 1; }
pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && mkimage -f pmos-lts.its pmos-lts.itb >/dev/null && cat pmos-lts.itb pad112.bin > pmos-lts-padded.itb && rm -f boot-uboot-lts2.img && mkbootimg --header_version 3 --kernel u-boot-int.bin.gz --ramdisk pmos-lts-padded.itb --cmdline \"\" --os_version 14.0.0 --os_patch_level 2025-04 -o boot-uboot-lts2.img && ls -la pmos-lts.itb boot-uboot-lts2.img" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!|WARNING"
sudo cp /tmp/env.prod $ENV; trap - EXIT
~/uboot-build.sh >/tmp/lts2-restore.log 2>&1 || { tail -20 /tmp/lts2-restore.log; exit 1; }
echo "production restored: $(sudo strings $C/u-boot/.output/u-boot-nodtb.bin | grep -c disp_cc_sm8250) dispcc strings (must be 0)"
# kernel modules to the phone
KV=$(ls $B/lib/modules/ | sort -V | tail -1); echo "modules: $KV"
sudo tar -C $B/lib/modules -cf - $KV | $SSHP "cat > /tmp/mods.tar"
$SSHP "sudo -S -p '' sh -c 'tar -C /lib/modules -xf /tmp/mods.tar && depmod $KV && rm /tmp/mods.tar && du -sh /lib/modules/$KV'" < $HOME/oneplus9pro-password.txt
echo PREPLTS2-DONE
