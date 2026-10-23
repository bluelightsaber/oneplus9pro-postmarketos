C=gpiochip6
show() { echo "-- $1: $(grep -E "gpio(20|21|23) " /sys/kernel/debug/gpio | awk '{printf "%s=%s ", $1, $4}')"; }
grep -E "pm8350c_l3 " /sys/kernel/debug/regulator/regulator_summary
show inicial
gpioset -c $C 31=1 & P1=$!; sleep 0.3; show "31=1 (2v8)"
gpioset -c $C 197=1 & P2=$!; sleep 0.3; show "197=1 (1v8)"
gpioset -c $C 22=0 & P3=$!; sleep 0.2; show "reset low"; kill $P3; wait $P3 2>/dev/null
gpioset -c $C 22=1 & P3=$!; sleep 0.5; show "reset high +0.5s"; sleep 2; show "reset high +2.5s"
kill $P1 $P2 $P3; wait 2>/dev/null; sleep 0.3; show "todo liberado"
