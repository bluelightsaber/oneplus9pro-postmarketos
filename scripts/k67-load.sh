#!/bin/sh
# (en el móvil, como root) Instala los módulos extra en /lib/modules/6.7.0/extra y los carga por grupos.
set -u
mkdir -p /lib/modules/6.7.0/extra
cp /tmp/extra/*.ko /lib/modules/6.7.0/extra/
depmod 6.7.0
step() {
  echo "===== $1"
  shift
  for m in "$@"; do modprobe "$m" && echo "  cargado $m" || echo "  FALLO $m"; done
  sleep 3
  dmesg | tail -n 12 | grep -viE "bluetooth|hci0"
}
step "1. reboot-mode" nvmem_qcom_spmi_sdam nvmem_reboot_mode
ls /sys/class/ | grep -i reboot; grep -l "" /sys/bus/platform/drivers/nvmem-reboot-mode/* 2>/dev/null | head -2
step "2. carga" pmic_glink qcom_battmgr
ls /sys/class/power_supply/
for p in /sys/class/power_supply/*; do echo "-- $p: $(cat $p/type 2>/dev/null) $(cat $p/status 2>/dev/null) $(cat $p/online 2>/dev/null)"; done
step "3. usb-c" typec_ucsi ucsi_glink
ls /sys/class/typec/ /sys/class/usb_role/ 2>&1
