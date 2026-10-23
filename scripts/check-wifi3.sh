echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
D=/var/log/experiments/wifi3-$(date +%m%d-%H%M); mkdir -p $D
sleep 30
for d in /sys/bus/pci/devices/*; do echo "$d $(cat $d/vendor) $(cat $d/device) driver=$(basename $(readlink $d/driver) 2>/dev/null)"; done
ls /sys/class/net/; ls /sys/class/ieee80211/ 2>/dev/null
dmesg | grep -iE "ath11k|mhi|qmi|wcn|qca6490|firmware|board" | grep -viE "scm|efivars" | tail -40
dmesg > $D/dmesg.txt
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
