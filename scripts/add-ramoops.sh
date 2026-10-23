#!/bin/bash
# Añade un nodo ramoops (4 MB en 0x2_0000_0000) a un DTB, para que el log del kernel sobreviva
# a un reinicio en caliente y se pueda leer en /sys/fs/pstore. Idempotente.
# Uso: add-ramoops.sh RUTA_DTB_DENTRO_DEL_CHROOT (p.ej. /home/pmos/v2/orig.dtb)
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
DTB=$1
pmbootstrap chroot -- sh -c "
set -e
fdtget $DTB /reserved-memory '#address-cells' /reserved-memory '#size-cells'
if fdtget -l $DTB /reserved-memory | grep -q '^ramoops@200000000$'; then echo 'ya tiene ramoops'; exit 0; fi
fdtput -c $DTB /reserved-memory/ramoops@200000000
fdtput -t s $DTB /reserved-memory/ramoops@200000000 compatible ramoops
fdtput -t x $DTB /reserved-memory/ramoops@200000000 reg 0x2 0x0 0x0 0x400000
fdtput -t x $DTB /reserved-memory/ramoops@200000000 record-size 0x40000
fdtput -t x $DTB /reserved-memory/ramoops@200000000 console-size 0x200000
fdtput -t x $DTB /reserved-memory/ramoops@200000000 pmsg-size 0x40000
fdtput -t x $DTB /reserved-memory/ramoops@200000000 ecc-size 0x10
dtc -I dtb -O dts $DTB 2>/dev/null | grep -A8 'ramoops@200000000 {'
" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!"
