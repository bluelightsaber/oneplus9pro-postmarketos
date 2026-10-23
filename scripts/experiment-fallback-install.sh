#!/bin/bash
# Installs experiment-fallback.service on the phone (run from the host while the phone runs production).
# When the running kernel is not the production one:
#  - after 90 s it saves a diagnostic snapshot to /var/log/experiments/<kernel>-<date>/ (dmesg,
#    devices_deferred, USB sysfs, clk_summary, lsmod, remoteprocs, power supplies), readable later
#    from production;
#  - after FALLBACK_MIN minutes it reboots (the ABL then boots boot_a = production), unless
#    /run/keep-experiment exists (touch it over SSH).
# Makes RAM experiments safe and informative without anyone at the phone or any network.
set -euo pipefail
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
$SSHP 'cat > /tmp/experiment-fallback' <<'SCRIPT'
#!/bin/sh
# Reboot back to production if an experimental kernel is running and nobody asked to keep it.
. /etc/experiment-fallback.conf
[ "$(uname -r)" = "$PRODUCTION_KERNEL" ] && exit 0
echo "experimental kernel $(uname -r): snapshot in 90 s, reboot to production in $FALLBACK_MIN min unless /run/keep-experiment exists"
sleep 90
D=/var/log/experiments/$(uname -r)-$(date +%Y%m%d-%H%M%S); mkdir -p "$D"
mount -t debugfs none /sys/kernel/debug 2>/dev/null
cat /sys/kernel/debug/devices_deferred > "$D/devices_deferred.txt" 2>&1
cat /sys/kernel/debug/clk/clk_summary > "$D/clk_summary.txt" 2>&1
{ ls -la /sys/class/udc; for d in /sys/bus/platform/devices/a6f8800.usb /sys/bus/platform/devices/a600000.usb; do
    echo "== $d"; ls -la "$d/"; echo "waiting_for_supplier: $(cat $d/waiting_for_supplier)"; readlink "$d/driver"; done; } > "$D/usb-sysfs.txt" 2>&1
dmesg > "$D/dmesg.txt" 2>&1
lsmod > "$D/lsmod.txt" 2>&1
systemctl --failed --no-legend > "$D/failed.txt" 2>&1
for r in /sys/class/remoteproc/*; do echo "$(cat $r/name) $(cat $r/state)"; done > "$D/remoteproc.txt" 2>&1
cat /sys/class/power_supply/*/uevent > "$D/power.txt" 2>&1
sync
echo "snapshot saved to $D"
sleep $((FALLBACK_MIN * 60 - 90))
[ -e /run/keep-experiment ] && { echo "kept by /run/keep-experiment"; exit 0; }
echo "fallback: rebooting"; systemctl reboot
SCRIPT
$SSHP 'cat > /tmp/experiment-fallback.service' <<'UNIT'
[Unit]
Description=Reboot to production if an experimental kernel is left running

[Service]
Type=simple
ExecStart=/usr/local/sbin/experiment-fallback

[Install]
WantedBy=multi-user.target
UNIT
$SSHP 'printf "PRODUCTION_KERNEL=6.7.0\nFALLBACK_MIN=15\n" > /tmp/experiment-fallback.conf'
$SSHP 'sudo -S -p "" sh -c "install -m 755 /tmp/experiment-fallback /usr/local/sbin/ && install -m 644 /tmp/experiment-fallback.service /etc/systemd/system/ && install -m 644 /tmp/experiment-fallback.conf /etc/ && systemctl daemon-reload && systemctl enable experiment-fallback.service && systemctl start experiment-fallback.service; journalctl -u experiment-fallback -b --no-pager | tail -2"' < $HOME/oneplus9pro-password.txt
echo FALLBACK-INSTALLED
