echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
D=/var/log/experiments/wifi4-$(date +%m%d-%H%M); mkdir -p $D
sleep 25
lsmod | grep -iE "ath11k|mhi|qrtr" | cut -c1-50
echo "== mhi devices"; ls /sys/bus/mhi/devices/ 2>&1; for m in /sys/bus/mhi/devices/*; do [ -e $m/state ] && echo "$m state=$(cat $m/state 2>/dev/null)"; done
cat /sys/bus/mhi/devices/mhi0/serial_number /sys/bus/mhi/devices/mhi0/oem_pk_hash 2>/dev/null | head -3
ls /sys/class/net/
dmesg | grep -iE "ath11k|mhi|qrtr" | tail -40
dmesg > $D/dmesg.txt
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
