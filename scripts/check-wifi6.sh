echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
D=/var/log/experiments/wifi6-$(date +%m%d-%H%M); mkdir -p $D
# wait until ~86 s uptime: BHIe starts ~73 s, ath11k gives up ~93 s
while [ $(cut -d. -f1 /proc/uptime) -lt 86 ]; do sleep 1; done
for f in /sys/kernel/debug/mhi/*/regdump /sys/kernel/debug/mhi/*/states /sys/kernel/debug/mhi/*/events; do echo "== $f"; cat $f 2>&1 | head -60; done > $D/mhi-debug.txt 2>&1
cat $D/mhi-debug.txt | head -80
sleep 15
dmesg > $D/dmesg.txt
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
