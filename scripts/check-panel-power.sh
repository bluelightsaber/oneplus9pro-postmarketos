echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"
touch /run/keep-experiment
for i in $(seq 1 30); do [ -e /sys/class/graphics/fb0 ] && grep -q msmdrmfb /proc/fb && break; sleep 1; done
B=$(ls -d /sys/class/backlight/* | head -1); FB=/sys/class/graphics/fb0
say() { printf '\n\n   >>> %s\n' "$1" > /dev/tty1; echo "$(cut -d' ' -f1 /proc/uptime) $1"; }
echo "backlight: $B max=$(cat $B/max_brightness) cur=$(cat $B/brightness) actual=$(cat $B/actual_brightness 2>/dev/null)"
for v in 4095 400 1500; do echo $v > $B/brightness; say "BRILLO $v"; sleep 4; done
say "APAGANDO PANTALLA 10 s"; sleep 2
echo 4 > $FB/blank; echo "blank rc=$?"
sleep 2; grep -E "pm8350c_l12|pm8350c_l13|mdss_gdsc" /sys/kernel/debug/regulator/regulator_summary /sys/kernel/debug/pm_genpd/pm_genpd_summary 2>/dev/null | head -4
sleep 8
echo 0 > $FB/blank; echo "unblank rc=$?"
sleep 1; say "PANTALLA ENCENDIDA DE NUEVO"
sleep 1; dmesg | grep -E "amb670|power mode|display on|dsi|dpu" | tail -8
for i in $(seq 1 10); do say "contador tras reencendido [$i]"; sleep 2; done
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
