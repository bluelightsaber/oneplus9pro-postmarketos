echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
D=/var/log/experiments/wifiscan-$(date +%m%d-%H%M); mkdir -p $D
for i in $(seq 1 30); do [ -e /sys/class/net/wlan0 ] && break; sleep 1; done
ls /sys/class/net/
nmcli radio wifi on 2>&1; sleep 2
nmcli -t -f DEVICE,TYPE,STATE dev status
nmcli dev wifi rescan 2>&1; sleep 10
nmcli -t -f SSID,CHAN,FREQ,SIGNAL,SECURITY dev wifi list 2>&1 > $D/scan.txt
echo "networks found: $(grep -c . $D/scan.txt)"
awk -F: '{printf "  %-4s ch %-4s %-9s signal %-3s %s\n", substr($1,1,3)"…", $2, $3, $4, $5}' $D/scan.txt | head -25
cat /sys/class/net/wlan0/address | sed -E 's/..:..:..$/xx:xx:xx/'
iw reg get 2>/dev/null | head -3
dmesg | grep -iE "ath11k.*(warn|err|fail)|cfg80211" | tail -8
dmesg > $D/dmesg.txt
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
