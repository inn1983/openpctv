#!/bin/sh

[ -f /etc/system.options ] || echo "CAM=OScam" > /etc/system.options
. /etc/system.options

for i in 10 9 8 7 6 5 4 3 2 1; do
  if [ -c /dev/dvb/adapter0/dvr0 -a -c /dev/dvb/adapter0/demux0 ]; then
     [ $(lsmod | grep -c dvbsoftwareca) -eq 0 ] && modprobe dvbsoftwareca
     [ -L /dev/dvb/adapter0/dvr1 ] || ln -s /dev/dvb/adapter0/dvr0 /dev/dvb/adapter0/dvr1
     [ -L /dev/dvb/adapter0/demux1 ] || ln -s /dev/dvb/adapter0/demux0 /dev/dvb/adapter0/demux1
     break
  else
     sleep 0.6
  fi
done
target=$(systemctl get-default)
if (grep -v -q "systemd" /proc/cmdline && test X$target = "Xenigma2pc.target") || grep -q enigma2pc /proc/cmdline; then
  target=enigma2pc
  if grep -q "^boxtype" /etc/oscam/oscam.conf; then
    sed -i 's/^boxtype.*/boxtype       = dreambox/g' /etc/oscam/oscam.conf
  else
    sed -i '/^\[dvbapi\].*/aboxtype       = dreambox' /etc/oscam/oscam.conf
  fi
else
  target=vdr_xbmc
  [ X$CAM = "XVDR-SC" ] && exit 1
  if grep -q "^boxtype" /etc/oscam/oscam.conf; then
    sed -i 's/^boxtype.*/boxtype       = pc/g' /etc/oscam/oscam.conf
  else
    sed -i '/^\[dvbapi\].*/aboxtype       = pc' /etc/oscam/oscam.conf
  fi
fi
/usr/bin/getcam auto
sleep 0.1
[ -c /dev/dvb/adapter0/ca0 ] || exit 1
