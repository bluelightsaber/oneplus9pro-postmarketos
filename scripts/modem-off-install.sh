#!/bin/sh
# Instala un servicio que detiene el coprocesador del módem al arrancar (no se usa el módem).
# La lógica va en un script aparte: systemd expande los "$" de ExecStart por su cuenta.
set -e
mkdir -p /usr/local/sbin
cat > /usr/local/sbin/modem-off <<'EOF'
#!/bin/sh
# Espera hasta 120 s a que el módem (4080000.remoteproc) esté en marcha y lo detiene.
for i in $(seq 1 120); do
  for r in /sys/class/remoteproc/remoteproc*; do
    if [ "$(cat "$r/name")" = 4080000.remoteproc ]; then
      case "$(cat "$r/state")" in
        running) echo stop > "$r/state"; echo "modem detenido ($r)"; exit 0 ;;
        offline) [ "$i" -gt 30 ] && { echo "modem ya offline"; exit 0; } ;;
      esac
    fi
  done
  sleep 1
done
echo "modem no encontrado"; exit 0
EOF
chmod 755 /usr/local/sbin/modem-off
cat > /etc/systemd/system/modem-off.service <<'EOF'
[Unit]
Description=Stop the unused modem remote processor (4080000.remoteproc)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/modem-off

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable modem-off.service
systemctl is-enabled modem-off.service
