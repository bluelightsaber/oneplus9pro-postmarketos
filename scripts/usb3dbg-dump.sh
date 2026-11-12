#!/bin/sh
# USB 3 bring-up debug: only runs when the kernel cmdline has "usb3dbg" (test images). Saves dmesg and
# blocked-task stacks to /data/usb3dbg so they survive a forced reset.
O=/data/usb3dbg; mkdir -p $O; T=$(date +%m%d-%H%M%S)
for i in $(seq 1 90); do
  dmesg > $O/dmesg-$T.txt
  ps -eo stat,pid,comm,wchan:32 | awk '$1 ~ /^D/' > $O/dstate-$T.txt
  [ $i = 18 ] && echo w > /proc/sysrq-trigger
  [ $i = 36 ] && echo w > /proc/sysrq-trigger
  sync; sleep 5
done
