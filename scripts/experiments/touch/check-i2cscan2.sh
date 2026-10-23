touch /run/keep-experiment
sleep 8
which i2cdetect >/dev/null || apk add -q i2c-tools 2>&1 | tail -1
echo "== regulators"; grep -E "ts_vdd|ts_vcc|pm8350c_l3 |pm8350c_l8 |pm8350c_l6 " /sys/kernel/debug/regulator/regulator_summary
echo "== gpios"; grep -E "gpio(20|21|22|23|31|197) " /sys/kernel/debug/gpio
B=$(for b in $(ls /sys/class/i2c-dev/ | sed 's/i2c-//'); do readlink -f /sys/class/i2c-dev/i2c-$b/device | grep -q 990000 && echo $b; done | head -1)
echo "i2c4 = bus $B"; timeout 30 i2cdetect -y -r $B 0x08 0x77 2>&1 | tail -8; for a in 0x4b 0x20 0x2c; do printf "read4 $a: "; timeout 5 i2ctransfer -y $B r4@$a 2>&1; done
echo "== gpios after"; grep -E "gpio(20|21|23) " /sys/kernel/debug/gpio
echo "== dmesg"; dmesg | grep -iE "990000|i2c-$B" | tail -5
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
