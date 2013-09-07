#!/bin/sh

/usr/bin/videocache

for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  if pidof vdr > /dev/null 2>&1; then
    break
  else
    sleep 2
  fi
done
sleep 1

if pidof vdr > /dev/null 2>&1; then
  /usr/bin/xmltv2vdr.pl -x /video/epg.xml -c /etc/vdr/plugins/channels.xml
else
  exit
fi
