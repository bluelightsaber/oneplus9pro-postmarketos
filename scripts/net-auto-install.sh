set -e
# 1) usb-mode: MODE=auto (UCSI picks the data role: device with a PC, host with a hub)
cp /usr/local/sbin/usb-mode /usr/local/sbin/usb-mode.pre-auto
sed -i 's|^  boot) . /etc/usb-mode.conf$|  boot) . /etc/usb-mode.conf\n        if [ "${MODE:-auto}" = auto ]; then echo "usb-mode: auto (UCSI decides), current: $(get)"; exit 0; fi|' /usr/local/sbin/usb-mode
cat > /etc/usb-mode.conf <<'C'
# USB-C data role:
#   auto   = let UCSI/USB-PD decide (default): connected to a PC (buildhost) -> device (USB network),
#            connected to a hub -> host (Ethernet, keyboard, disks...)
#   host   = force host, falling back to device after FALLBACK_SECS without LAN (usb-host-try does the same)
#   device = force device
MODE=auto
FALLBACK_SECS=300
C
# 2) NetworkManager dispatcher: wired Ethernet up -> Wi-Fi off; last one down -> Wi-Fi on
mkdir -p /etc/NetworkManager/dispatcher.d
cat > /etc/NetworkManager/dispatcher.d/70-ethernet-wifi <<'D'
#!/bin/sh
# Wired Ethernet (e.g. USB-C hub) connected -> turn Wi-Fi off; when no wired link is left -> Wi-Fi on.
# usb0 (USB network to the PC) is not managed by NetworkManager and is ignored.
IF="$1"; ACT="$2"
case "$ACT" in up|down) ;; *) exit 0 ;; esac
[ "$IF" = usb0 ] && exit 0
TYPE=$(nmcli -g GENERAL.TYPE device show "$IF" 2>/dev/null)
[ "$TYPE" = ethernet ] || [ "$ACT" = down ] || exit 0
eth_connected() { nmcli -t -f TYPE,STATE,DEVICE device | awk -F: '$1=="ethernet" && $2=="connected" && $3!="usb0"' | grep -q .; }
if [ "$ACT" = up ] && [ "$TYPE" = ethernet ]; then
	nmcli radio wifi off && logger -t ethernet-wifi "$IF up: Wi-Fi off"
elif [ "$ACT" = down ] && ! eth_connected; then
	[ "$(nmcli radio wifi)" = enabled ] || { nmcli radio wifi on && logger -t ethernet-wifi "$IF down: Wi-Fi on"; }
fi
D
chmod 755 /etc/NetworkManager/dispatcher.d/70-ethernet-wifi
# 3) boot safety: NM persists "Wi-Fi off"; if no wired link 45 s after boot, turn Wi-Fi back on
cat > /usr/local/sbin/wifi-boot-safety <<'W'
#!/bin/sh
sleep 45
if ! nmcli -t -f TYPE,STATE,DEVICE device | awk -F: '$1=="ethernet" && $2=="connected" && $3!="usb0"' | grep -q .; then
	[ "$(nmcli radio wifi)" = enabled ] || { nmcli radio wifi on; echo "no wired link at boot: Wi-Fi on"; }
fi
W
chmod 755 /usr/local/sbin/wifi-boot-safety
cat > /etc/systemd/system/wifi-boot-safety.service <<'U'
[Unit]
Description=Turn Wi-Fi back on at boot if no wired Ethernet is connected
After=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/wifi-boot-safety

[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable wifi-boot-safety.service
/usr/local/sbin/usb-mode boot
grep -n "auto" /usr/local/sbin/usb-mode | head -3
