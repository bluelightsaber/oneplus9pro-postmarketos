#!/bin/bash
# Recompila 7.3 con lo necesario integrado (=y) para arrancar el rootfs instalado sin módulos
# y para carga/límite (pmic_glink+battmgr), USB-C role/OTG (UCSI) y reboot-mode a fastboot.
# Después instala los módulos en un directorio de staging para copiarlos al móvil.
set -euo pipefail
exec 9>/tmp/kernel-build.lock; flock -n 9 || { echo "ya hay una compilacion en marcha"; exit 1; }
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; N=$P/pmbootstrap-work/chroot_native/home/pmos/src
sudo mkdir -p $N; mountpoint -q $N || sudo mount --bind $P/src $N
K='make ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl- CC="ccache aarch64-alpine-linux-musl-gcc" O=../build-7.3'
Y="QCOM_PMIC_GLINK BATTERY_QCOM_BATTMGR UCSI_PMIC_GLINK TYPEC_UCSI TYPEC POWER_RESET_QCOM_PON NVMEM_REBOOT_MODE NVMEM_SPMI_SDAM BTRFS_FS SCSI_UFS_QCOM PHY_QCOM_QMP PHY_QCOM_QMP_UFS PHY_QCOM_QMP_COMBO PHY_QCOM_QMP_USB QCOM_Q6V5_PAS QCOM_PDR_HELPERS QCOM_SYSMON PSTORE PSTORE_RAM"
EN=""; for k in $Y; do EN="$EN -e $k"; done
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && ./scripts/config --file ../build-7.3/.config $EN -d USB_ETH && $K olddefconfig >/dev/null && for k in $Y; do printf '%-24s %s\n' \$k \$(grep -E \"^CONFIG_\$k=\" ../build-7.3/.config | cut -d= -f2); done" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
echo "== build $(date +%T)"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && $K -j8 Image dtbs modules > ../build-7.3/build.log 2>&1 && echo BUILD-OK || { tail -30 ../build-7.3/build.log; exit 1; }" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && rm -rf ../modules-7.3 && $K INSTALL_MOD_PATH=../modules-7.3 INSTALL_MOD_STRIP=1 modules_install >/dev/null && ls ../modules-7.3/lib/modules/ && du -sh ../modules-7.3" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
echo "== fin $(date +%T)"
echo BUILD-DONE
