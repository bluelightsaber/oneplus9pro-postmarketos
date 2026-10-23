# Panel driver test (run as root via test-pmos.sh CHECK=): msm KMS + DSI + AMB670YF01 panel
echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
D=/var/log/experiments/panel-$(date +%m%d-%H%M); mkdir -p $D; dmesg > $D/dmesg.txt
lsmod | grep -E "^msm|panel_samsung|drm_display" | cut -c1-60
echo "== dmesg panel/dsi/dpu"; dmesg | grep -iE "amb670|panel|dsi|dpu|mdss|msm_drm|\[drm\]|fbcon|simplefb|e4d00000|dsc" | grep -v "Adding to iommu" | head -50
ls /sys/class/drm/; for c in /sys/class/drm/card*-*; do echo "$c: $(cat $c/status 2>/dev/null) $(head -1 $c/modes 2>/dev/null)"; done
ls /sys/class/backlight/ 2>/dev/null && cat /sys/class/backlight/*/brightness 2>/dev/null
cat /proc/fb
for i in $(seq 1 40); do printf '\n   *** PANEL DRIVER AMB670YF01 [%s] ***\n' $i > /dev/tty1; sleep 3; done
dmesg > $D/dmesg-end.txt
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
