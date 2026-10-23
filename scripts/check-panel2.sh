echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
D=/var/log/experiments/panel2-$(date +%m%d-%H%M); mkdir -p $D
M=/sys/bus/platform/devices/ae00000.display-subsystem
echo "mdss dev: $(ls -d $M 2>&1) driver=$(readlink $M/driver) modalias=$(cat $M/modalias 2>/dev/null)"
cat /sys/kernel/debug/devices_deferred 2>/dev/null | head
grep -rh msm /etc/modprobe.d/ 2>/dev/null; echo "lsmod msm: $(lsmod | grep -c '^msm')"
echo "== modprobe msm"; modprobe -v msm 2>&1 | tail -5; sleep 8
lsmod | grep -E "^msm|panel_samsung" | cut -c1-60
dmesg | grep -iE "amb670|panel|dsi|dpu|mdss|msm|\[drm\]|fbcon|dsc|Unknown symbol" | grep -v "Adding to iommu\|Fixed dependency" | tail -40
ls /sys/class/drm/; cat /proc/fb; ls /sys/class/backlight/
dmesg > $D/dmesg.txt
for i in $(seq 1 30); do printf '\n   *** PANEL DRIVER AMB670YF01 [%s] ***\n' $i > /dev/tty1; sleep 3; done
dmesg > $D/dmesg-end.txt
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
