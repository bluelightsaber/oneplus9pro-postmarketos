#!/bin/bash
# Compila módulos extra para el kernel 6.7 en producción (sin tocar vmlinux):
# pmic_glink, battmgr, UCSI (USB-C/OTG) y reboot-mode (reinicio a fastboot).
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; N=$P/pmbootstrap-work/chroot_native/home/pmos/src
sudo mkdir -p $N; mountpoint -q $N || sudo mount --bind $P/src $N
# solo se añaden como módulo opciones que producción NO tiene; TYPEC y REBOOT_MODE ya son =y
M="QCOM_PMIC_GLINK BATTERY_QCOM_BATTMGR UCSI_PMIC_GLINK TYPEC_UCSI NVMEM_REBOOT_MODE NVMEM_SPMI_SDAM"
EN=""; for k in $M; do EN="$EN -m $k"; done
K='KBUILD_MODPOST_WARN=1 make ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl- CC="ccache aarch64-alpine-linux-musl-gcc" O=../build-6.7'
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux-6.7 && cp /home/pmos/src/build-6.7/.config.base /home/pmos/src/build-6.7/.config && ./scripts/config --file ../build-6.7/.config $EN -e TYPEC && $K olddefconfig >/dev/null && for k in $M; do printf '%-22s %s\n' \$k \$(grep -E \"^CONFIG_\$k=\" ../build-6.7/.config | cut -d= -f2); done && $K -j8 modules_prepare >/dev/null 2>&1 && echo prepare-ok" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
for d in drivers/soc/qcom drivers/power/supply drivers/usb/typec drivers/power/reset drivers/nvmem; do
  pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux-6.7 && $K -j8 M=$d modules > /tmp/m.log 2>&1 && echo \"ok $d\" || { echo \"FALLO $d\"; grep -E \"error|Error\" /tmp/m.log | head -5; }" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
done
mkdir -p $P/modules-6.7-extra
for ko in pmic_glink pmic_glink_altmode qcom_battmgr ucsi_glink typec_ucsi typec nvmem-reboot-mode reboot-mode nvmem_qcom-spmi-sdam; do
  f=$(find $P/src/build-6.7 -name "$ko.ko" 2>/dev/null | head -1)
  [ -n "$f" ] && { cp "$f" $P/modules-6.7-extra/; echo "  $ko.ko"; } || echo "  (no) $ko.ko"
done
modinfo -F vermagic $P/modules-6.7-extra/*.ko 2>/dev/null | sort -u
echo K67MOD-DONE
