#!/bin/bash
# stage c1 (pipe clock from the QMP PHY, super-speed) with on-screen boot debug, to see where it hangs
P=/srv/oneplus9pro-pmos
sudo cp ~/usb3-dt.sh $P/pmbootstrap-work/chroot_native/home/pmos/v2/usb3-dt.sh
export USB3=0 NAME=usb3c1dbg SKIPMODS=1
export EXTRA_UCMD="sh /home/pmos/v2/usb3-dt.sh \$D c1"
export EXTRA_BOOTARGS="initcall_debug ignore_loglevel"
nice -n 19 ionice -c3 ~/build-pmos-image.sh
