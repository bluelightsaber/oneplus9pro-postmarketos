# Display + GPU + services check for a new production candidate (run as root via test-pmos.sh CHECK=)
echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
echo "cmdline: dispcc_blacklist=$(grep -c disp_cc_sm8250 /proc/cmdline) separate_gpu_kms=$(grep -c separate_gpu_kms /proc/cmdline) fbcon=$(grep -o 'fbcon=[^ ]*' /proc/cmdline)"
cat /proc/fb
grep -E "^(mdss_gdsc|mmcx) " /sys/kernel/debug/pm_genpd/pm_genpd_summary 2>/dev/null
dmesg | grep -iE "simplefb|sync_state\(\) pending due to af00000" | head -5
echo "systemd: $(systemctl is-system-running)"; systemctl --failed --no-legend | head -5
ls /dev/dri/
setpriv --reuid=user --regid=user --groups=render --reset-env env XDG_RUNTIME_DIR=/tmp vulkaninfo --summary 2>/dev/null | grep -E "deviceName|driverName"
for i in $(seq 1 20); do printf '\n   *** %s - pantalla OK [%s] ***\n' "$(uname -r)" $i > /dev/tty1; sleep 3; done
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
