#!/bin/bash
# Barrido automático de parámetros de arranque para el kernel 7.3, todo en remoto y en RAM:
# para cada combinación genera la variante, reinicia a fastboot desde producción, la arranca con
# "fastboot boot" y comprueba qué kernel responde por SSH. Si el 7.3 cae, el móvil vuelve solo a producción.
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; W=$P/pmbootstrap-work/chroot_native/home/pmos/v2
O=$P/tests/sweep-7.3-$(date +%m%d-%H%M); mkdir -p $O
SSHP="ssh -o BatchMode=yes -o ConnectTimeout=8 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_phone -i $HOME/.ssh/id_ed25519_phone user@172.16.42.1"
PW=$HOME/oneplus9pro-password.txt
netup() {
  for i in $(seq 1 ${1:-60}); do lsusb | grep -q 18d1:d001 && break; sleep 2; done
  lsusb | grep -q 18d1:d001 || return 1
  sleep 4; I=$(ls /sys/bus/usb/devices/1-1:*/net/ 2>/dev/null | head -1)
  [ -n "$I" ] && { sudo ip link set $I up; sleep 2; ip -4 addr show $I | grep -q inet || sudo ip addr add 172.16.42.2/24 dev $I 2>/dev/null; }
  for i in $(seq 1 40); do timeout 3 bash -c "echo > /dev/tcp/172.16.42.1/22" 2>/dev/null && return 0; sleep 3; done; return 1
}
SETS=(
  "cpuidle.off=1"
  "nosmp"
  "cpuidle.off=1 nosmp"
  "arm-smmu.disable_bypass=0"
  "cpuidle.off=1 nosmp arm-smmu.disable_bypass=0 fw_devlink.sync_state=strict regulator_ignore_unused"
  "maxcpus=1 cpuidle.off=1 arm64.nopauth arm64.nobti kpti=0"
)
n=0
for S in "${SETS[@]}"; do
  n=$((n+1)); echo "===== [$n] $S ($(date +%T))"
  ~/variant-7.3.sh "$S" > $O/build-$n.log 2>&1 || { echo "  fallo al generar"; continue; }
  netup 30 || { echo "  producción no responde, paro"; break; }
  B=$($SSHP 'cat /sys/class/power_supply/bq27541-0/capacity' 2>/dev/null); echo "  batería $B%"
  [ -n "$B" ] && [ "$B" -lt 40 ] && { echo "  batería baja, paro"; break; }
  $SSHP "sudo -S -p '' systemctl reboot --reboot-argument=bootloader" < $PW >/dev/null 2>&1
  for i in $(seq 1 45); do timeout 5 fastboot devices 2>/dev/null | grep -q fastboot && break; sleep 2; done
  timeout 5 fastboot devices | grep -q fastboot || { echo "  no llegó a fastboot, paro"; break; }
  timeout 180 fastboot boot $W/boot-uboot-7.3.img 2>&1 | grep -E "Booting" | sed "s/^/  /"
  if netup 90; then
    K=$($SSHP uname -r 2>/dev/null); U=$($SSHP 'cut -d. -f1 /proc/uptime' 2>/dev/null)
    echo "  responde: kernel=$K uptime=${U}s"
    if [[ "$K" == 7.3* ]]; then
      echo "  >>> EL 7.3 ARRANCA con: $S"
      $SSHP 'dmesg' > $O/dmesg-$n.txt 2>&1; $SSHP sh -s < $HOME/diag-7.3.sh > $O/diag-$n.txt 2>&1
      echo "$S" > $O/FUNCIONA.txt
      $SSHP "sudo -S -p '' systemctl reboot" < $PW >/dev/null 2>&1; sleep 20; netup 90 >/dev/null
      break
    fi
  else
    echo "  sin respuesta tras 3 min"; netup 90 || { echo "  producción tampoco vuelve, paro"; break; }
  fi
done
echo "resultados en $O"; echo SWEEP-DONE
