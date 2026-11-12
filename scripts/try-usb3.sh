#!/bin/bash
# RAM-boot one USB 3 stage image and report: reachability (USB/Wi-Fi), link speed, QMP/dwc3 state
ST=${1:?stage}
V=/srv/oneplus9pro-pmos/pmbootstrap-work/chroot_native/home/pmos/v2
SW="ssh -o ConnectTimeout=8 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@192.168.1.59"
timeout 420 ~/exp-ram.sh ${IMG:-$V/boot-uboot-pmos-7.3.0-usb3$ST.img} 2>&1 | grep -E "fastboot|Booting|SSH|NO LLEGA"
for i in $(seq 1 30); do ping -c1 -W2 192.168.1.59 >/dev/null 2>&1 && break; sleep 4; done
ping -c1 -W2 192.168.1.59 >/dev/null 2>&1 || { echo "STAGE $ST: phone not reachable (hang?)"; echo TRY-DONE; exit 1; }
sleep 10
for d in /sys/bus/usb/devices/*; do [ -f $d/idVendor ] && [ "$(cat $d/idVendor)" = 18d1 ] && echo "buildhost sees phone $(basename $d) speed=$(cat $d/speed)"; done
$SW "sudo -S -p '' sh -c 'touch /run/keep-experiment; uname -v; cat /proc/device-tree/soc@0/phy@88e8000/status; echo; ls /sys/bus/platform/drivers/qcom-qmp-combo-phy/ 2>/dev/null | grep 88e8; ls /sys/class/udc; cat /sys/class/udc/*/current_speed /sys/class/udc/*/maximum_speed 2>/dev/null; dmesg | grep -iE \"qmp|88e8000|dwc3|a600000|altmode|typec_switch|clk_regmap|phy_mux\" | tail -15; grep -E \"usb3_prim_phy_pipe\" /sys/kernel/debug/clk/clk_summary'" < ~/oneplus9pro-password.txt
echo TRY-DONE
