echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
D=/var/log/experiments/wifi5-$(date +%m%d-%H%M); mkdir -p $D
sleep 20
echo 1 > /proc/sys/kernel/sysrq; echo w > /proc/sysrq-trigger; sleep 2
dmesg > $D/dmesg.txt
ls /sys/kernel/debug/ath11k/ 2>&1 | head; ls /sys/bus/mhi/devices/ 2>&1
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
