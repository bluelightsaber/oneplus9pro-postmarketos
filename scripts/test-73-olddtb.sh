#!/bin/bash
# Experimento: kernel 7.3 (depuración, con g_ether + netconsole) arrancado con el DTB de producción (6.7).
# Si arranca, el problema está en el device tree del 7.3; si no, en el kernel/drivers.
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; W=$P/pmbootstrap-work/chroot_native/home/pmos/v2
O=$P/tests/7.3-olddtb-$(date +%m%d-%H%M); mkdir -p $O
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=8 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt

# FIT: Image del 7.3-dbg + DTB de producción (orig.dtb) + initramfs; mismo U-Boot y bootargs de producción + netconsole
sudo cp $P/src/build-7.3-dbg/arch/arm64/boot/Image $W/Image-7.3dbg
sudo sed -e 's|data = /incbin/("Image")|data = /incbin/("Image-7.3dbg")|' -e 's|mainline 6.7|7.3dbg + DTB 6.7|' $W/pmos.its | sudo tee $W/pmos-73olddtb.its >/dev/null
EXTRA="netconsole=6665@172.16.42.1/usb0,6666@172.16.42.2/ff:ff:ff:ff:ff:ff loglevel=8 ignore_loglevel"
ENV=$W/../u-boot/board/qualcomm/pmos-lemonadep.env
sudo cp $ENV /tmp/env.prod; trap 'sudo cp /tmp/env.prod $ENV' EXIT
sudo sed -i -E "s|^pmos_bootargs=|pmos_bootargs=$EXTRA |" $ENV
~/uboot-build.sh > $O/ub.log 2>&1 || { tail $O/ub.log; exit 1; }
pmbootstrap chroot -- sh -c "cd /home/pmos/v2 && mkimage -f pmos-73olddtb.its pmos-73olddtb.itb >/dev/null && cat pmos-73olddtb.itb pad112.bin > pmos-73olddtb-padded.itb && rm -f boot-73olddtb.img && mkbootimg --header_version 3 --kernel u-boot-int.bin.gz --ramdisk pmos-73olddtb-padded.itb --cmdline \"\" --os_version 14.0.0 --os_patch_level 2025-04 -o boot-73olddtb.img && ls -la boot-73olddtb.img" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
sudo cp /tmp/env.prod $ENV; trap - EXIT
~/uboot-build.sh > $O/ub-restore.log 2>&1 || { tail $O/ub-restore.log; exit 1; }

for i in $(seq 1 30); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && break; sleep 3; done
B=$($SSHP 'cat /sys/class/power_supply/bq27541-0/capacity' 2>/dev/null); echo "batería $B%"
$SSHP "sudo -S -p '' systemctl reboot --reboot-argument=bootloader" < $PW >/dev/null 2>&1
for i in $(seq 1 45); do timeout 5 fastboot devices 2>/dev/null | grep -q fastboot && break; sleep 2; done
timeout 5 fastboot devices | grep -q fastboot || { echo "no llegó a fastboot"; exit 1; }
(
  for i in $(seq 1 240); do
    I=$(for d in /sys/bus/usb/devices/1-1:*/net/*; do [ -e "$d" ] && basename $d; done | head -1)
    lsusb | grep -qE "0525:a4a2|18d1:d001" && [ -n "$I" ] && break; sleep 0.5
  done
  echo "gadget visto: $(lsusb | grep -oE '0525:a4a2|18d1:d001') ${I:-ninguno} $(date +%T)"
  [ -n "$I" ] && { sudo ip link set $I up; sudo ip addr add 172.16.42.2/24 dev $I 2>/dev/null
                   sudo timeout 120 tcpdump -l -n -i $I -A -s 0 udp port 6666 > $O/netconsole.raw 2>/dev/null; }
) > $O/listener.log 2>&1 &
LP=$!
echo "== fastboot boot ($(date +%T))"
timeout 180 fastboot boot $W/boot-73olddtb.img 2>&1 | grep -E "Booting"
wait $LP; cat $O/listener.log
grep -vE "^[0-9]{2}:[0-9]{2}|^\s*$" $O/netconsole.raw > $O/netconsole.txt 2>/dev/null
echo "líneas de log: $(wc -l < $O/netconsole.txt 2>/dev/null)"; tail -30 $O/netconsole.txt 2>/dev/null
K=$($SSHP uname -r 2>/dev/null); echo "SSH responde: ${K:-no}"
sudo journalctl -k --since "-5 min" --no-pager | grep -iE "usb 1-1: (new|USB disc)|idProduct" | tail -8 > $O/usb.log; cat $O/usb.log
echo "resultados en $O"; echo OLDDTB-DONE
