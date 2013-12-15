#!/bin/sh

. /etc/system.options

target=$(systemctl get-default)
if (grep -v -q "systemd" /proc/cmdline && test X$target = "Xenigma2pc.target") || grep -q enigma2pc /proc/cmdline; then
  target=enigma2pc
  for i in 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1; do
    if [ -c /dev/dvb/adapter0/dvr0 -a -c /dev/dvb/adapter0/frontend0 ]; then
       [ $(lsmod | grep -c dvbsoftwareca) -eq 0 ] && modprobe dvbsoftwareca
       sleep 0.1
       for j in /dev/dvb/adapter*; do
         [ -L $j/dvr1 ] || ln -s $j/dvr0 $j/dvr1
         [ -L $j/demux1 ] || ln -s $j/demux0 $j/demux1
       done
       break
    else
       sleep 0.6
    fi
  done
  [ -c /dev/dvb/adapter0/ca0 ] || (sleep 1;rmmod dvbsoftwareca; modprobe dvbsoftwareca)
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
