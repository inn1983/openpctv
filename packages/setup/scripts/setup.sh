#!/bin/bash

export TERM=linux

. gettext.sh
export TEXTDOMAIN=openpctv

source /etc/profile

if grep -q -i arm /proc/cpuinfo; then
  ARCH=arm
  echo -e -n "\e[31m$(gettext "Press any key to enter setup,")\e[0m \e[32m$(gettext "or 3 seconds after enter XBMC automatically.")\e[0m"
  read -s -n1 -t3
  result=$?
  if [ $result = 142 -o $result = 130 ]; then
    systemctl start getty\@ttymxc0
    systemctl start vdr-backend
    systemctl start xbmc
    exit 0
  elif [ $result = 0 ]; then
    chvt 1
    clear
  fi
else
  systemctl start plymouth-quit
fi


DIALOG=/usr/bin/dialog
DIALOGOUT="/tmp/dialogout"
VDRETCDIR=/etc/vdr
EDIT=/bin/nano

MENUTMP=/tmp/menu.$$

RUN_LANG=/usr/bin/select-language
RUN_TARGET=/usr/bin/select-target
RUN_NET=/usr/bin/netconfig
RUN_DRV=/usr/bin/install-drivers
RUN_IR=/usr/bin/select-irdrv
RUN_MONITOR=/usr/bin/monitor.sh
RUN_AUDIO=/usr/bin/audio-config
RUN_CAM=/usr/bin/getcam
RUN_EPG=/usr/bin/update-epg
RUN_TRANS=/usr/bin/update-transponders
RUN_DVB=/usr/bin/update-dvbdevice
RUN_DISEQC=/usr/bin/diseqcsetup
RUN_CHANNELS=/usr/bin/update-channels

function updatelocale
{
. /etc/locale.conf && export LANG
}

function setupinit
{
if [ X$ARCH = arm ]; then
  $RUN_LANG
  updatelocale
  $RUN_NET
  systemctl stop vdr
  systemctl stop vdr-backend
  $RUN_AUDIO init
  $RUN_CAM
  $RUN_EPG
  $RUN_TRANS
  $RUN_DISEQC
else
  $RUN_LANG
  updatelocale
  $RUN_TARGET
  $RUN_NET
  $RUN_DRV
  $RUN_IR
  systemctl restart lircd
  systemctl stop vdr
  systemctl stop vdr-backend
  $RUN_MONITOR
  $RUN_AUDIO init
  $RUN_CAM
  $RUN_EPG
  $RUN_TRANS
  $RUN_DVB
  $RUN_DISEQC
fi
dialog --defaultno --clear --yesno "$(gettext "Would you like to scan channels for VDR/XBMC(It'll take quiet long to do it)?  You can also scan channels with vdr reelscanchannels plugin in vdr.")" 7 70
if [ $? -eq 0 ]; then
  $RUN_CHANNELS
fi
}

function MainMenu
{
updatelocale
echo "${DIALOG} --clear --no-cancel --backtitle \"$(gettext "OpenPCTV configurator")\" --menu \"$(gettext "Main menu")\" 21 60 14 \\" > $MENUTMP
[ -f $RUN_LANG ] && echo "Lang \"$(gettext "Set global locale and language")\" \\" >> $MENUTMP
[ -f $RUN_TARGET ] && echo "Target \"$(gettext "Set the default target")\" \\" >> $MENUTMP
[ -f $RUN_NET ] && echo "Netconf \"$(gettext "Configure Network Environment")\" \\" >> $MENUTMP
[ -f $RUN_DRV ] && echo "Driver \"$(gettext "Install additional V4L and DVB drive")\" \\" >> $MENUTMP
[ -f $RUN_IR ] && echo "Lirc \"$(gettext "Select IR device")\" \\" >> $MENUTMP
[ -f $RUN_MONITOR ] && echo "Monitor \"$(gettext "Set the monitor's best resolution")\" \\" >> $MENUTMP
[ -f $RUN_AUDIO ] && echo "Audio \"$(gettext "Soundcard Configuration")\" \\" >> $MENUTMP
[ -f $RUN_TRANS ] && echo "Uptran \"$(gettext "Update Satellite Transponders")\" \\" >> $MENUTMP
[ -f $RUN_EPG ] && echo "EPG \"$(gettext "Update EPG data")\" \\" >> $MENUTMP
[ -f $RUN_CAM ] && echo "CAM \"$(gettext "Select a software emulated CAM")\" \\" >> $MENUTMP
[ -f $RUN_DISEQC ] && echo "DiSEqC \"$(gettext "DiSEqC configurator")\" \\" >> $MENUTMP
[ -f $RUN_CHANNELS ] && echo "Scan \"$(gettext "Auto scan channels")\" \\" >> $MENUTMP
[ X$ARCH = "Xarm" ] && echo "XBMC \"$(gettext "Start XBMC with VDR")\" \\" >> $MENUTMP
echo "Reboot \"$(gettext "Reboot OpenPCTV")\" \\" >> $MENUTMP
echo "Exit \"$(gettext "Exit to login shell")\" 2> $DIALOGOUT" >> $MENUTMP
. $MENUTMP
rm $MENUTMP
case "$(cat $DIALOGOUT)" in
    Lang)	$RUN_LANG
		MainMenu
		;;
    Target)	$RUN_TARGET
		MainMenu
		;;
    Netconf)	$RUN_NET
		MainMenu
		;;
    Driver)	$RUN_DRV
		MainMenu
		;;
    Lirc)	$RUN_IR
		systemctl restart lircd
    		MainMenu
 		;;
    Uptran)	$RUN_TRANS
    		MainMenu
  		;;
    EPG)	$RUN_EPG
		MainMenu
		;;
    CAM)	$RUN_CAM
		MainMenu
		;;
    DiSEqC)	systemctl stop vdr
		systemctl stop vdr-backend
		$RUN_DISEQC
    		MainMenu
  		;;
    Scan)	systemctl stop vdr
		systemctl stop vdr-backend
		$RUN_CHANNELS
		MainMenu
		;;
    Monitor)	$RUN_MONITOR
		MainMenu
		;;
    Audio)	$RUN_AUDIO
		MainMenu
		;;
    XBMC)	systemctl start getty\@ttymxc0
		systemctl start vdr-backend
		systemctl start xbmc
		;;
    Reboot)	reboot
		;;
    Exit)	clear
		systemctl start getty\@tty1
		systemctl start getty\@ttymxc0
    		exit 0
    		;;
esac
rm $DIALOGOUT
}

[ X$1 = "Xinit" -a ! -f /etc/system.options ] && setupinit
MainMenu
