C=gpiochip6; modprobe i2c-dev; sleep 0.5
which i2cdetect >/dev/null || apk add -q i2c-tools 2>&1 | tail -1
B=$(for b in $(ls /sys/class/i2c-dev/ | sed 's/i2c-//'); do readlink -f /sys/class/i2c-dev/i2c-$b/device | grep -q a94000 && echo $b; done | head -1)
echo "i2c13 = bus $B"; grep -E "gpio33 " /sys/kernel/debug/gpio
echo "-- antes"; i2cdetect -y -r $B 0x08 0x0b | tail -1
gpioset -c $C 33=1 & P=$!; sleep 0.5
echo "-- gpio33=1"; i2cdetect -y -r $B 0x08 0x0b | tail -1
for a in 0x08 0x09; do printf "$a revid(0x0100..0x0105): "; for r in 0x00 0x01 0x02 0x03 0x04 0x05; do i2ctransfer -y $B w2@$a 0x01 $r r1 2>&1 | tr '\n' ' '; done; echo; done
printf "0x09 L3 regs 0x4208(status1) 0x4240/41(vset) 0x4246(en): "; for r in 0x08 0x40 0x41 0x46; do i2ctransfer -y $B w2@0x09 0x42 $r r1 2>&1 | tr '\n' ' '; done; echo
printf "0x08 chip-en 0x0946: "; i2ctransfer -y $B w2@0x08 0x09 0x46 r1 2>&1; 
grep -E "gpio(20|21) " /sys/kernel/debug/gpio
kill $P; wait 2>/dev/null
