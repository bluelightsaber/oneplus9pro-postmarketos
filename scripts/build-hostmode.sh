#!/bin/bash
# test image: dwc3 fixed in host mode from boot (dr_mode=host, no role switch), modules unchanged
U=/soc@0/usb@a6f8800/usb@a600000
export NAME=hostmode SKIPMODS=1
export EXTRA_UCMD="fdtput -t s \$D $U dr_mode host && fdtput -d \$D $U usb-role-switch && fdtput -d \$D $U role-switch-default-mode && echo HOSTDT=$(fdtget \$D $U dr_mode)"
nice -n 19 ionice -c3 ~/build-pmos-image.sh
