C=gpiochip6; modprobe i2c-dev; sleep 0.3; B=3
lv() { echo "-- $1: $(grep -E "gpio(20|21|23) " /sys/kernel/debug/gpio | awk '{printf "%s=%s ", $1, $4}')"; }
gpioset -c $C 33=1 & P=$!; sleep 0.3
lv "inicio"
i2ctransfer -y $B w3@0x08 0x09 0x46 0x80; sleep 0.1; printf "chip-en=%s " $(i2ctransfer -y $B w2@0x08 0x09 0x46 r1)
i2ctransfer -y $B w3@0x09 0x42 0x46 0x80; sleep 0.3; printf "L3 en=%s status=%s\n" $(i2ctransfer -y $B w2@0x09 0x42 0x46 r1) $(i2ctransfer -y $B w2@0x09 0x42 0x08 r1)
lv "L3 ON"
gpioset -c $C 126=1 & P2=$!; sleep 0.5; lv "L3 ON + tof enable"
gpioset -c $C 31=1 197=1 & P3=$!; sleep 0.5; lv "+ touch rails"
which i2cdetect >/dev/null; T=$(for b in $(ls /sys/class/i2c-dev/ | sed 's/i2c-//'); do readlink -f /sys/class/i2c-dev/i2c-$b/device | grep -q 990000 && echo $b; done | head -1)
echo "i2c4=bus $T"; [ -n "$T" ] && timeout 20 i2cdetect -y -r $T 0x40 0x4f | tail -2
kill $P3 $P2; wait $P3 $P2 2>/dev/null
echo "(L3 y gpio33 se quedan encendidos)"
