#!/bin/sh
# (en el móvil, root) Pasa el USB a modo host durante ~45 s y vuelve a device automáticamente.
# La vuelta se programa ANTES con systemd-run, para que ocurra aunque se corte el SSH.
# el interruptor de rol no permite control desde espacio de usuario: se usa el control "mode" del debugfs de dwc3
R=/sys/kernel/debug/usb/a600000.usb/mode
echo "rol actual: $(cat $R)"
systemd-run --on-active=45 --unit=usb-role-revert /bin/sh -c "echo device > $R"
systemd-run --on-active=150 --unit=usb-role-safety /bin/sh -c "[ \"\$(cat $R)\" = device ] || systemctl reboot"
dmesg -c >/dev/null
( sleep 2; echo host > $R ) &
echo "cambiando a host en 2 s"
