which gpioset >/dev/null 2>&1 || apk add -q libgpiod 2>&1 | tail -1
gpioset --version 2>&1 | head -1
CHIP=$(gpiodetect | grep -m1 f100000 | cut -d' ' -f1); echo "tlmm chip: $CHIP"
show() { echo "-- $1"; grep -E "gpio(20|21|22|23|31|99|126|197) " /sys/kernel/debug/gpio; }
show "inicial"
for v in 1 0; do
  timeout 3 gpioset -c $CHIP 126=$v 2>/dev/null || timeout 3 gpioset --mode=time --sec=2 $CHIP 126=$v &
  sleep 1; show "gpio126=$v"; wait
done
