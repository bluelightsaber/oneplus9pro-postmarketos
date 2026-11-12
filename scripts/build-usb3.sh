#!/bin/bash
# test images: production + USB 3 DT stages (usb3-dt.sh a|b|c); modules unchanged (production)
# usage: build-usb3.sh a|b|c   -> boot-uboot-pmos-7.3.0-usb3<stage>.img
ST=${1:?stage}
P=/srv/oneplus9pro-pmos
sudo cp ~/usb3-dt.sh $P/pmbootstrap-work/chroot_native/home/pmos/v2/usb3-dt.sh
export NAME=usb3$ST SKIPMODS=1
export EXTRA_UCMD="sh /home/pmos/v2/usb3-dt.sh \$D $ST"
nice -n 19 ionice -c3 ~/build-pmos-image.sh
