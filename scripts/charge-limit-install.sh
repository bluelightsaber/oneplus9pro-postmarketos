#!/bin/sh
# (en el móvil, root) Instala el servicio de límite de carga con histéresis (45-65 % por defecto).
# Usa charge_behaviour de qcom_battmgr (parche local) y la capacidad del medidor bq27541.
set -e
mkdir -p /usr/local/sbin
cat > /etc/charge-limit.conf <<'EOF'
# Límite de carga con histéresis: deja de cargar al llegar a STOP y reanuda al bajar a START.
START=45
STOP=65
INTERVAL=60
EOF
cat > /usr/local/sbin/charge-limit <<'EOF'
#!/bin/sh
# Bucle de histéresis de carga. Lee /etc/charge-limit.conf en cada vuelta (se puede cambiar en caliente).
B=/sys/class/power_supply/qcom-battmgr-bat/charge_behaviour
G=/sys/class/power_supply/bq27541-0/capacity
want=""
# El firmware del ADSP vuelve a activar la carga cuando se reinicia (p.ej. al arrancar), así que el
# modo deseado se reafirma en cada vuelta, no solo cuando cambia. Solo se registra en el log al cambiar.
apply() {
  if echo "$1" > "$B" 2>/dev/null; then
    [ "$1" != "$want" ] && echo "charge-limit: $(cat $G)% -> $1"
    want=$1
  fi
}
while true; do
  . /etc/charge-limit.conf
  if [ -w "$B" ] && [ -r "$G" ]; then
    c=$(cat $G)
    if [ "$c" -ge "$STOP" ]; then apply inhibit-charge
    elif [ "$c" -le "$START" ]; then apply auto
    else apply "${want:-auto}"   # entre umbrales: mantener lo último decidido (al arrancar: cargar)
    fi
  fi
  sleep "${INTERVAL:-60}"
done
EOF
chmod 755 /usr/local/sbin/charge-limit
cat > /etc/systemd/system/charge-limit.service <<'EOF'
[Unit]
Description=Battery charge limit with hysteresis (see /etc/charge-limit.conf)
After=multi-user.target

[Service]
ExecStart=/usr/local/sbin/charge-limit
# al parar el servicio, dejar la carga en automático
ExecStopPost=/bin/sh -c 'echo auto > /sys/class/power_supply/qcom-battmgr-bat/charge_behaviour 2>/dev/null; true'
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now charge-limit.service
sleep 3
systemctl is-active charge-limit.service
journalctl -u charge-limit.service --no-pager -n 3 | tail -2
echo "behaviour: $(cat /sys/class/power_supply/qcom-battmgr-bat/charge_behaviour)"
