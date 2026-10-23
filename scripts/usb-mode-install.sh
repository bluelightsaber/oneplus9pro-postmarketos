#!/bin/sh
# (en el móvil, root) Control del rol USB (dispositivo/host) con red de seguridad.
#  - /etc/usb-mode.conf: MODE=device|host, FALLBACK_SECS
#  - en host, si no hay IPv4 por una interfaz que no sea usb0/lo tras FALLBACK_SECS, vuelve a device
#  - usb-host-try N: prueba host N segundos con la misma lógica
set -e
mkdir -p /usr/local/sbin
[ -f /etc/usb-mode.conf ] || cat > /etc/usb-mode.conf <<'EOF'
# Rol del USB-C: device (red USB con buildhost) o host (hub con Ethernet, teclado, disco...).
MODE=device
# En host: si en este tiempo no hay red por Ethernet, se vuelve a device para no perder el acceso.
FALLBACK_SECS=300
EOF
cat > /usr/local/sbin/usb-mode <<'EOF'
#!/bin/sh
# usb-mode [host|device]  -> cambia el rol ahora (sin argumentos: muestra el actual)
# usb-mode boot           -> aplica /etc/usb-mode.conf (servicio al arrancar)
# usb-mode fallback N     -> en N s, si no hay red LAN, vuelve a device
M=/sys/kernel/debug/usb/a600000.usb/mode
mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug
lan_ok() { ip -4 -o addr show | awk '{print $2}' | grep -vqE '^(lo|usb0)$' && ip -4 -o addr show | grep -vE ' (lo|usb0) ' | grep -q 'inet '; }
case "$1" in
  host|device) echo "$1" > $M; echo "usb-mode: $1" ;;
  boot) . /etc/usb-mode.conf
        if [ "$MODE" = host ]; then echo host > $M; echo "usb-mode: host (arranque)"; exec "$0" fallback "${FALLBACK_SECS:-300}"; fi ;;
  fallback) sleep "${2:-300}"
        if [ "$(cat $M)" = host ] && ! lan_ok; then echo device > $M; echo "usb-mode: sin red LAN tras ${2}s -> device"; fi ;;
  "") cat $M ;;
  *) echo "uso: usb-mode [host|device|boot|fallback N]"; exit 1 ;;
esac
EOF
chmod 755 /usr/local/sbin/usb-mode
cat > /usr/local/sbin/usb-host-try <<'EOF'
#!/bin/sh
# usb-host-try N: pasa a host ahora; si en N s no hay red LAN, vuelve a device (programado con systemd).
N=${1:-300}
systemd-run --on-active="$N" --unit=usb-host-try-fallback /usr/local/sbin/usb-mode fallback 0 >/dev/null
( sleep 2; /usr/local/sbin/usb-mode host ) &
echo "usb-host-try: host en 2 s; vuelta a device en ${N}s si no hay red LAN"
EOF
chmod 755 /usr/local/sbin/usb-host-try
cat > /etc/systemd/system/usb-mode.service <<'EOF'
[Unit]
Description=Apply USB-C role from /etc/usb-mode.conf (with fallback to device if no LAN)
After=multi-user.target NetworkManager.service

[Service]
Type=simple
ExecStart=/usr/local/sbin/usb-mode boot

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable usb-mode.service
/usr/local/sbin/usb-mode
