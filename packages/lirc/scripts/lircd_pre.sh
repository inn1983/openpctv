#!/bin/sh

/bin/mkdir -p /var/run/lirc

TMPFILE=/tmp/TMP.$$

/bin/mkdir -p /var/run/lirc
if [ -f /etc/lirc/hardware.conf ]; then
   source /etc/lirc/hardware.conf
else
   exit 1
fi

for i in 0 1 2 3 4 5 6 7 8 9; do
  [ -d /sys/class/rc ] && break
  sleep 0.2
done

for i in 0 1 2 3 4 5 6 7 8 9; do
  ls /sys/class/rc/* >/dev/null 2>&1 && break
  sleep 0.2
done

FIRSTIR="yes"
for i in /sys/class/rc/*; do
  [ $FIRSTIR == "yes" ] && DEVEVENT2=$(ls -d $i/input*)
  grep -i "$DRV_NAME" $i/uevent >/dev/null 2>&1 && DEVEVENT1=$(ls -d $i/input*)
   FIRSTIR="no"
done

if [ "X$DEVEVENT1" == "X" ]; then
  DEVEVENT=${DEVEVENT2##*input}
else
  DEVEVENT=${DEVEVENT1##*input}
fi

sed -i "s/^DEVICE=.*/DEVICE=\"\/dev\/input\/event$DEVEVENT\"/g" /etc/lirc/hardware.conf
