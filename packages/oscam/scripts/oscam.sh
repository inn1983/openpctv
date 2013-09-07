#!/bin/sh

. /etc/system.options
if [ X$CAM = "XOScam" ]; then
  /usr/bin/oscam -c /etc/oscam
elif [ X$CAM = "XTTcam" ]; then
  /usr/bin/ttcam -c /etc/oscam -u
fi
