#!/bin/sh
if lsmod | grep vmwgfx > /dev/null; then
   DRIVER="--video=xshm"
fi
if lsmod | grep nvidia > /dev/null; then
   DRIVER="--video=vdpau"
fi
if lsmod | grep gma500_gfx > /dev/null; then
   DRIVER="--video=xshm"
fi
HUDOPTS=""
XINELIBOUTPUTOPTS="$DRIVER --fullscreen --aspect=16:9 --reconnect --post tvtime:method=use_vo_driver --audio=alsa --syslog --silent --tcp --hud=xshape"
CONFIG="--config /etc/vdr-sxfe/config_xineliboutput"

while  ! netcat -z localhost 37890; do sleep 0.1; done;
#while ! grep -q "^ 1" /proc/asound/cards ; do sleep 1 ; done
#while ! grep -q "^ 0" /proc/asound/cards ; do sleep 1 ; done
/usr/bin/vdr-sxfe $XINELIBOUTPUTOPTS $CONFIG xvdr://127.0.0.1:37890 &> /tmp/vdr-frontend.log 

