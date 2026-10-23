#!/bin/bash
# Full unattended 7.3 round:
#  A) build + modules + RAM test with dispcc blacklisted: checks battery/charge_behaviour/nftables/zram
#  B) back to production, then RAM test WITHOUT the dispcc blacklist (tests the no-init-park clk patch)
# The experiment-fallback service brings the phone back to production if a test kernel gets stuck.
set -uo pipefail
P=/srv/oneplus9pro-pmos; V=$P/pmbootstrap-work/chroot_native/home/pmos/v2
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt
wait_production() {
  echo "== waiting for production $(date +%T)"
  for i in $(seq 1 120); do
    [ "$($SSHP uname -r 2>/dev/null)" = "6.7.0" ] && { echo "== production $(date +%T)"; sleep 30; return 0; }
    I=$(ls /sys/bus/usb/devices/1-1:*/net/ 2>/dev/null | head -1)
    [ -n "$I" ] && { sudo ip link set $I up; ip -4 addr show $I | grep -q inet || sudo ip addr add 172.16.42.2/24 dev $I; }
    sleep 15
  done
  echo "PRODUCTION NOT BACK"; return 1
}
cat > /tmp/check73.sh <<'EOF'
echo "== kernel $(uname -r)"; uptime
[ "$(uname -r)" = "6.7.0" ] && { echo "production kernel: check skipped (test kernel did not boot)"; exit 0; }
touch /run/keep-experiment
B=/sys/class/power_supply/qcom-battmgr-bat
echo "charge_behaviour: $(cat $B/charge_behaviour)"
echo inhibit-charge > $B/charge_behaviour && echo "write inhibit-charge: OK -> $(cat $B/charge_behaviour)"
sleep 20; echo "bq27541: $(cat /sys/class/power_supply/bq27541-0/status) $(cat /sys/class/power_supply/bq27541-0/current_now) uA"
echo auto > $B/charge_behaviour && echo "write auto: OK -> $(cat $B/charge_behaviour)"
sleep 20; echo "bq27541: $(cat /sys/class/power_supply/bq27541-0/status) $(cat /sys/class/power_supply/bq27541-0/current_now) uA"
nft list ruleset >/dev/null 2>&1 && echo "nftables: OK" || echo "nftables: FAIL"
modprobe zram && echo "zram: OK" || echo "zram: FAIL"
for m in tun veth bridge overlay; do modprobe $m && echo -n "$m:OK " || echo -n "$m:FAIL "; done; echo
systemctl --failed --no-legend
for r in /sys/class/remoteproc/*; do echo -n "$(cat $r/name)=$(cat $r/state) "; done; echo
dmesg | grep -iE "dispcc|disp_cc|af00000" | head -5
rm -f /run/keep-experiment; systemctl reboot
EOF

echo "######## A: build + test with dispcc blacklisted ($(date +%T))"
~/cycle-73.sh 2>&1 | grep -vE "^\[|^-rw|^  (CC|LD|AR)"
$SSHP "sudo -S -p '' sh -s" < <(cat $PW; cat /tmp/check73.sh) 2>&1 | grep -v "^$" || echo "(check A could not run: no SSH)"
wait_production || exit 1

echo "######## B: no dispcc blacklist, no-init-park clk patch ($(date +%T))"
export DTB_CMDS="fdtput -t s \$DTB /soc@0/usb@a6f8800/usb@a600000 dr_mode peripheral"
KBUILD=$P/src/build-7.3-fb ~/variant-7.3.sh "fbcon=font:TER16x32 loglevel=8 ignore_loglevel panic=0" 2>&1 | tail -1
sudo cp $V/boot-uboot-7.3.img $V/boot-uboot-7.3fb-dispfix.img
~/exp-ram.sh $V/boot-uboot-7.3fb-dispfix.img /dev/null
$SSHP "sudo -S -p '' sh -s" < <(cat $PW; cat /tmp/check73.sh) 2>&1 | grep -v "^$" || echo "(check B could not run: no SSH)"
wait_production
echo FULL73-DONE
