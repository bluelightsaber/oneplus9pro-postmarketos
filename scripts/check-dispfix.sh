echo "== kernel $(uname -r) up $(cut -d' ' -f1 /proc/uptime)s"; cat /proc/cmdline | grep -c disp_cc_sm8250 | sed 's/^/blacklist in cmdline: /'
touch /run/keep-experiment
cat /proc/fb; ls /sys/class/graphics/ 2>&1 | tr '\n' ' '; echo
echo "== dmesg display"; dmesg | grep -iE "disp_cc|dispcc|af00000|simple-framebuffer|simplefb|e4d00000|mdss|gdsc|fbcon|sync_state" | head -40
echo "== genpd"; grep -iE "mdss|mmcx" /sys/kernel/debug/pm_genpd/pm_genpd_summary 2>/dev/null | head
echo "== clocks"; grep -E "disp_cc_mdss_(mdp|ahb|vsync|mdp_lut)_clk |disp_cc_pll0 " /sys/kernel/debug/clk/clk_summary 2>/dev/null | head
echo "== deferred"; cat /sys/kernel/debug/devices_deferred 2>/dev/null | head
printf '\n\n\n   *** HOLA DESDE LINUX 7.3 - dispcc OK ***\n   %s\n\n' "$(date)" > /dev/tty1 2>/dev/null && echo "text written to tty1"
sleep 45
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
