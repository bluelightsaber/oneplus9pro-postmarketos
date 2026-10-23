set -e
install -m 755 /tmp/usb-gadget-ensure /usr/local/sbin/usb-gadget-ensure
install -m 644 /tmp/usb-gadget-ensure.service /etc/systemd/system/usb-gadget-ensure.service
systemctl daemon-reload
systemctl enable usb-gadget-ensure.service
systemctl start usb-gadget-ensure.service
journalctl -u usb-gadget-ensure -b --no-pager -o cat | tail -3
