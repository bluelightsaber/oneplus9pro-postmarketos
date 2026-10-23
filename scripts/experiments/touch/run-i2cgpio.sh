#!/bin/bash
# Touch experiment: gpio20/21 muxed as plain GPIO (pull-up), i2c4 GENI disabled, bit-banged i2c-gpio on them,
# ts rails + L8C forced on, reset released. Tells IC/pull-up clamp apart from GENI/GPI driving the pins.
P=/srv/oneplus9pro-pmos; V=$P/pmbootstrap-work/chroot_native/home/pmos/v2
I2C=/soc@0/geniqup@9c0000/i2c@990000; TL=/soc@0/pinctrl@f100000; L8=/soc@0/rsc@18200000/regulators-1/ldo8
ST=$TL/qup-i2c4-default-state; IG=/i2c-gpio-ts
export EXTRA_DTB_CMDS="fdtput -r \$DTB $I2C/touchscreen@4b && fdtput -t s \$DTB $I2C status disabled && fdtput -t s \$DTB $ST function gpio && TLP=\$(fdtget \$DTB $TL phandle) && STP=\$(fdtget \$DTB $ST phandle) && fdtput -c \$DTB $IG && fdtput -t s \$DTB $IG compatible i2c-gpio && fdtput \$DTB $IG sda-gpios \$TLP 20 6 && fdtput \$DTB $IG scl-gpios \$TLP 21 6 && fdtput \$DTB $IG i2c-gpio,delay-us 5 && fdtput -t s \$DTB $IG pinctrl-names default && fdtput \$DTB $IG pinctrl-0 \$STP && fdtput -t s \$DTB /regulator-ts-vdd-2v8 regulator-always-on \"\" && fdtput -t s \$DTB /regulator-ts-vcc-1v8 regulator-always-on \"\" && fdtput -t s \$DTB $L8 regulator-always-on \"\" && fdtput -c \$DTB $TL/ts-rst-hog && fdtput -t s \$DTB $TL/ts-rst-hog gpio-hog \"\" && fdtput \$DTB $TL/ts-rst-hog gpios 22 0 && fdtput -t s \$DTB $TL/ts-rst-hog output-high \"\" && echo hog-ok"
~/dispfix-73.sh "fbcon=font:TER16x32" 2>&1 | grep -E "hog-ok|DISPFIX-DONE|rror"
sudo cp $V/boot-uboot-7.3fb-dispfix2.img $V/boot-uboot-7.3fb-i2cgpio.img
for i in $(seq 1 40); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && break; sleep 4; done; sleep 8
CHECK=$HOME/check-i2cgpio.sh ~/test-pmos.sh $V/boot-uboot-7.3fb-i2cgpio.img 2>&1 | grep -vE "^\[" | sed -n "/EXP-DONE/,/FASTBOOT/p" | cut -c1-160
echo I2CGPIO-DONE
