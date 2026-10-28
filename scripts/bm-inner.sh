#!/bin/sh
# runs inside chroot_native: compile only qcom_battmgr.o against the 7.3 tree
cd /home/pmos/src/linux-pmos-v7.3 || exit 1
O=/home/pmos/src/build-bmtest
M="make O=$O ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl-"
$M -s olddefconfig >/dev/null || exit 1
$M -s -j4 modules_prepare > $O/prep.log 2>&1 || { tail -20 $O/prep.log; exit 1; }
$M W=1 drivers/power/supply/qcom_battmgr.o > $O/cc.log 2>&1
echo "RC=$?"
grep -E "warning|error" $O/cc.log | grep -i battmgr | head -20
ls -la $O/drivers/power/supply/qcom_battmgr.o
