echo "== kernel $(uname -r) $(uname -v | cut -c1-20) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
for i in $(seq 1 30); do grep -q msmdrmfb /proc/fb && break; sleep 1; done
cat /proc/fb; ls /sys/class/drm | tr '\n' ' '; echo
B=$(ls -d /sys/class/backlight/* | head -1); echo "backlight $B max=$(cat $B/max_brightness)"
for v in 2047 100 1000 4095; do
  echo $v > $B/brightness; r=$?; sleep 1
  echo "set $v rc=$r brightness=$(cat $B/brightness) actual=$(cat $B/actual_brightness 2>&1)"
done
dmesg | grep -iE "amb670|backlight|dsi.*(err|fail|timeout)|panel" | tail -10
grep -E "HandlePowerKey|HandlePowerKeyLongPress" /etc/systemd/logind.conf /etc/systemd/logind.conf.d/* 2>/dev/null
cat /sys/module/kernel/parameters/consoleblank 2>/dev/null
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
