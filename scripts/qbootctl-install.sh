#!/bin/sh
# (en el móvil, root) Instala qbootctl y marca el arranque actual como correcto en cada inicio,
# para que el bootloader A/B no agote los reintentos del slot a y caiga en fastboot.
set -e
apk add --allow-untrusted --no-network /tmp/qbootctl-*.apk 2>&1 | tail -2
echo "== estado antes"; qbootctl 2>&1 | head -20
ls /usr/lib/systemd/system/ /etc/systemd/system/ 2>/dev/null | grep -i qboot || true
cat > /etc/systemd/system/mark-boot-successful.service <<'EOF'
[Unit]
Description=Mark the current A/B slot as successfully booted (qbootctl -m)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/qbootctl -m

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now mark-boot-successful.service
echo "== estado después"; qbootctl 2>&1 | head -20
