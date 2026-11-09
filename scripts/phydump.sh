# read-only dump: HS PHY (0x88e3000..+0x120), dwc3 qscratch, EUD enable; tag = $1
T=${1:-x}; O=/root/phydump-$T.txt
cp /tmp/rdmem /root/rdmem 2>/dev/null; chmod +x /root/rdmem
{ echo "== $T $(date +%T) lockdown=$(cat /sys/kernel/security/lockdown) role=$(cat /sys/class/usb_role/*/role) typec=$(cat /sys/class/typec/port0/data_role)"
  a=0; L=""; while [ $a -le 288 ]; do L="$L $(printf 0x%x $((0x88e3000 + a)))"; a=$((a+4)); done; /root/rdmem $L
  echo "-- qscratch"; /root/rdmem 0xa6f8800 0xa6f8804 0xa6f8808 0xa6f880c 0xa6f8810 0xa6f8814 0xa6f8818 0xa6f881c 0xa6f8830 0xa6f8834 0xa6f8838
  echo "-- eud"; /root/rdmem 0x88e2014 0x88e1004
} > $O 2>&1
cat $O
