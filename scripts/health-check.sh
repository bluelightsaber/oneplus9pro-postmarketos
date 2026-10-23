#!/bin/sh
# (en el móvil) Comprobación de salud del servidor: kernel, módulos, servicios, batería, carga y almacenamiento.
echo "kernel:     $(uname -r)   uptime: $(cut -d. -f1 /proc/uptime)s"
echo "módulos:    $(lsmod | grep -cE 'pmic_glink|qcom_battmgr|ucsi_glink|nvmem_reboot_mode|nvmem_qcom_spmi_sdam')/5 (glink, battmgr, ucsi, reboot-mode, sdam)"
echo "reboot-mode:$(ls /sys/bus/platform/drivers/nvmem-reboot-mode/ 2>/dev/null | grep -c reboot-mode)"
for s in modem-off charge-limit sshd; do printf "%-12s%s\n" "$s:" "$(systemctl is-active $s 2>/dev/null) / $(systemctl is-enabled $s 2>/dev/null)"; done
for r in /sys/class/remoteproc/*; do printf "  rproc %-20s %s\n" "$(cat $r/name)" "$(cat $r/state)"; done
G=/sys/class/power_supply/bq27541-0; B=/sys/class/power_supply/qcom-battmgr-bat
echo "batería:    $(cat $G/capacity)% $(cat $G/status) $(cat $G/current_now)uA temp=$(cat $G/temp)"
echo "carga:      behaviour=$(cat $B/charge_behaviour 2>&1)  conf: $(grep -E '^(START|STOP)=' /etc/charge-limit.conf | tr '\n' ' ')"
echo "usb fw:     online=$(cat /sys/class/power_supply/qcom-battmgr-usb/online 2>&1) type=$(cat /sys/class/power_supply/qcom-battmgr-usb/usb_type 2>&1)"
df -h / | tail -1 | awk '{print "rootfs:     "$3" usados de "$2" ("$5")"}'
