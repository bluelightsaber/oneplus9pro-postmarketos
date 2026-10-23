touch /run/keep-experiment
sleep 8
which i2cdetect >/dev/null || apk add -q i2c-tools 2>&1 | tail -1
echo "== regulators"; grep -E "ts_vdd|ts_vcc|pm8350c_l3 |pm8350c_l8 |pm8350c_l6 |pm8350c_l9 " /sys/kernel/debug/regulator/regulator_summary
echo "== gpios"; grep -E "gpio(20|21|22|23|31|197) " /sys/kernel/debug/gpio
lsmod | grep -E "^i2c_gpio|i2c_algo_bit" | cut -c1-40
for b in $(ls /sys/class/i2c-dev/ | sed 's/i2c-//'); do echo "bus $b $(cat /sys/class/i2c-dev/i2c-$b/device/of_node/name 2>/dev/null)"; done
B=$(for b in $(ls /sys/class/i2c-dev/ | sed 's/i2c-//'); do [ "$(cat /sys/class/i2c-dev/i2c-$b/device/of_node/name 2>/dev/null)" = "i2c-gpio-ts" ] && echo $b; done | head -1)
echo "i2c-gpio = bus $B"
if [ -n "$B" ]; then timeout 60 i2cdetect -y -r $B 2>&1 | tail -8; for a in 0x4b 0x20 0x2c; do printf "read4 $a: "; timeout 5 i2ctransfer -y $B r4@$a 2>&1; done; fi
echo "== gpios after"; grep -E "gpio(20|21|23) " /sys/kernel/debug/gpio
echo "== dmesg"; dmesg | grep -iE "i2c-gpio|i2c_gpio|i2c-gpio-ts" | tail -5
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
