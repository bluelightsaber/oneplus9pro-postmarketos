echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
D=/var/log/experiments/wifi2-$(date +%m%d-%H%M); mkdir -p $D
lsmod | grep -iE "pwrseq|pwrctrl|ath11k|mhi|qcom_pcie" | cut -c1-50
echo "pmu driver: $(readlink /sys/bus/platform/devices/wcn6855-pmu/driver)"
ls /sys/bus/platform/drivers/ | grep -iE "pwrseq|pwrctrl|qcom-pcie"
for d in /sys/bus/platform/drivers/pci-pwrctrl-pwrseq/* /sys/bus/platform/drivers/qcom-pcie/*; do [ -L "$d" ] && echo "bound: $d"; done
echo "== regulators (pmu + rails)"; grep -E "vreg_pmu|pm8350_s1[012]|pm8350c_s1|pmr735a_s2" /sys/kernel/debug/regulator/regulator_summary 2>/dev/null | head -20
echo "== gpio 64/65/153"; grep -E "gpio(64|65|153) " /sys/kernel/debug/gpio 2>/dev/null
dmesg | grep -iE "pwrseq|pwrctrl|wcn" | head
echo "== unbind/bind qcom-pcie"
echo 1c00000.pcie > /sys/bus/platform/drivers/qcom-pcie/unbind 2>&1; sleep 2
echo 1c00000.pcie > /sys/bus/platform/drivers/qcom-pcie/bind 2>&1; sleep 6
dmesg | tail -25 | grep -iE "pcie|pci |ath11k|mhi|link|found" 
for d in /sys/bus/pci/devices/*; do echo "$d $(cat $d/vendor) $(cat $d/device) driver=$(basename $(readlink $d/driver) 2>/dev/null)"; done
dmesg > $D/dmesg.txt
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
