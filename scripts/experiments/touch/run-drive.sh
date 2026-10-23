#!/bin/bash
# Touch experiment: gpio31/197 (touch 2v8/1v8 enables) with 16 mA drive + pull-up (sm8350-mainline used 8 mA;
# ours were 2 mA), ts rails always-on, reset hog high, GENI i2c4 scan.
P=/srv/oneplus9pro-pmos; V=$P/pmbootstrap-work/chroot_native/home/pmos/v2
I2C=/soc@0/geniqup@9c0000/i2c@990000; TL=/soc@0/pinctrl@f100000; EN=$TL/ts-en-strong-state
export EXTRA_DTB_CMDS="fdtput -r \$DTB $I2C/touchscreen@4b && fdtput -c \$DTB $EN && fdtput -t s \$DTB $EN pins gpio31 gpio197 && fdtput -t s \$DTB $EN function gpio && fdtput \$DTB $EN drive-strength 16 && fdtput -t s \$DTB $EN bias-pull-up \"\" && fdtput \$DTB $EN phandle 0x7f01 && fdtput -t s \$DTB /regulator-ts-vdd-2v8 pinctrl-names default && fdtput \$DTB /regulator-ts-vdd-2v8 pinctrl-0 0x7f01 && fdtput -t s \$DTB /regulator-ts-vdd-2v8 regulator-always-on \"\" && fdtput -t s \$DTB /regulator-ts-vcc-1v8 regulator-always-on \"\" && fdtput -c \$DTB $TL/ts-rst-hog && fdtput -t s \$DTB $TL/ts-rst-hog gpio-hog \"\" && fdtput \$DTB $TL/ts-rst-hog gpios 22 0 && fdtput -t s \$DTB $TL/ts-rst-hog output-high \"\" && echo hog-ok"
~/dispfix-73.sh "fbcon=font:TER16x32" 2>&1 | grep -E "hog-ok|DISPFIX-DONE|rror"
sudo cp $V/boot-uboot-7.3fb-dispfix2.img $V/boot-uboot-7.3fb-drive.img
for i in $(seq 1 40); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && break; sleep 4; done; sleep 8
CHECK=$HOME/check-i2cscan2.sh ~/test-pmos.sh $V/boot-uboot-7.3fb-drive.img 2>&1 | grep -vE "^\[" | sed -n "/EXP-DONE/,/FASTBOOT/p" | cut -c1-160
echo DRIVE-DONE
