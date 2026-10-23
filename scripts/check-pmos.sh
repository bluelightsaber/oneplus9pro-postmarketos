echo "== kernel $(uname -r)"; [ "$(uname -r)" = "6.7.0" ] && { echo "production kernel: skipped"; exit 0; }
touch /run/keep-experiment
B=/sys/class/power_supply/qcom-battmgr-bat
echo "battmgr module: $(modinfo -n qcom_battmgr) loaded=$(lsmod | grep -c qcom_battmgr)"
echo "charge_behaviour: $(cat $B/charge_behaviour)"
echo inhibit-charge > $B/charge_behaviour && echo "inhibit: $(cat $B/charge_behaviour)"; sleep 15
echo "bq27541: $(cat /sys/class/power_supply/bq27541-0/status) $(cat /sys/class/power_supply/bq27541-0/current_now)"
echo auto > $B/charge_behaviour && echo "auto: $(cat $B/charge_behaviour)"
for r in /sys/class/usb_role/*; do echo "usb_role $(basename $r): $(cat $r/role)"; done
ls /sys/class/typec/ 2>&1 | tr "\n" " "; echo
lsmod | grep -cE "nvmem_reboot_mode|reboot_mode" | sed "s/^/reboot-mode modules: /"
modprobe nvmem_reboot_mode 2>&1; ls /sys/bus/platform/drivers/nvmem-reboot-mode/ 2>&1 | head -3
systemctl --failed --no-legend
rm -f /run/keep-experiment
echo "== rebooting to bootloader"; systemctl reboot --reboot-argument=bootloader
