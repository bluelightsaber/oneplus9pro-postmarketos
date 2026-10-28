#!/bin/bash
# low CPU/IO priority so builds do not disturb other buildhost services (children and sudo/chroot inherit it)
renice -n 19 -p $$ >/dev/null 2>&1; ionice -c3 -p $$ 2>/dev/null || true
# Test image: production r104 + vendor host-mode tuning of the USB2 HS PHY (OnePlus param-override-seq-host
# 0xe7/0x0c/0x17 at X0/X1/X2) expressed as mainline qcom,* properties. Negative values in two's complement.
H=/soc@0/phy@88e3000
export EXTRA_UCMD="fdtput \$D $H qcom,hs-disconnect-bp 2156 && fdtput \$D $H qcom,squelch-detector-bp 4294965206 && fdtput \$D $H qcom,hs-amplitude-bp 2000 && fdtput \$D $H qcom,pre-emphasis-duration-bp 20000 && fdtput \$D $H qcom,pre-emphasis-amplitude-bp 40000 && fdtput \$D $H qcom,hs-rise-fall-time-bp 4294963196 && fdtput \$D $H qcom,hs-crossover-voltage-microvolt 4294936296 && fdtput \$D $H qcom,hs-output-impedance-micro-ohms 2600000 && fdtget \$D $H qcom,squelch-detector-bp"
NAME=usbtune SKIPMODS=1 ~/build-pmos-image.sh linux-postmarketos-mainline 2>&1 | grep -vE "^\[" | tail -25
