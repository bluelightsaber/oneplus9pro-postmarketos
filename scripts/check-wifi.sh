echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
D=/var/log/experiments/wifi-$(date +%m%d-%H%M); mkdir -p $D; dmesg > $D/dmesg.txt
dmesg | grep -iE "pcie|pci 0000|ath11k|mhi|qca6490|wcn|pwrseq|tlmm.*95|link" | grep -v "Adding to iommu" | head -40
echo "== pci devices"; ls /sys/bus/pci/devices/ 2>&1; for d in /sys/bus/pci/devices/*; do [ -e $d ] && echo "$d $(cat $d/vendor) $(cat $d/device) driver=$(basename $(readlink $d/driver) 2>/dev/null)"; done
ls /sys/class/net/
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
