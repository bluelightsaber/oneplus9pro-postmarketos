echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
sleep 15
lsmod | grep -iE "synaptics_tcm" | cut -c1-50
echo "== dmesg"; dmesg | grep -iE "tcm|s3908|synaptics|990000|i2c-4|touch|regulator-ts|ts_v" | grep -v "Adding to iommu" | head -20
echo "== input"; grep -E "^N: |^H: " /proc/bus/input/devices | paste - - | sed "s/H: Handlers=//"
echo "== regulators"; grep -E "ts_vdd|ts_vcc|pm8350c_l3 " /sys/kernel/debug/regulator/regulator_summary 2>/dev/null
D=/var/log/experiments/touch-$(date +%m%d-%H%M); mkdir -p $D; dmesg > $D/dmesg.txt
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
