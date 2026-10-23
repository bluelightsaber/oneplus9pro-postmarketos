echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
D=/var/log/experiments/bt-$(date +%m%d-%H%M); mkdir -p $D
for i in $(seq 1 30); do [ -e /sys/class/bluetooth/hci0 ] && [ -e /sys/class/net/wlan0 ] && break; sleep 1; done
echo "net: $(ls /sys/class/net | tr '\n' ' ')  bt: $(ls /sys/class/bluetooth 2>/dev/null | tr '\n' ' ')"
dmesg | grep -iE "bluetooth|btqca|hci_uart|qca|uart18|890000" | grep -v "ath11k" | head -30
which bluetoothctl >/dev/null 2>&1 && {
  systemctl start bluetooth 2>/dev/null; sleep 2
  bluetoothctl show 2>&1 | grep -E "Controller|Powered|Name|Alias" | sed -E "s/([0-9A-F]{2}:){3}[0-9A-F:]+/XX:XX:XX:XX:XX:XX/"
  bluetoothctl power on 2>&1 | tail -1
  timeout 12 bluetoothctl --timeout 10 scan on > $D/btscan.txt 2>&1
  echo "BT devices seen: $(grep -c "NEW.*Device" $D/btscan.txt)"
} || echo "bluetoothctl not installed"
dmesg > $D/dmesg.txt
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
