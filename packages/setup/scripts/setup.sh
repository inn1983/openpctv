#!/bin/bash

export TERM=linux
. gettext.sh
export TEXTDOMAIN=openpctv

DIALOG=/usr/bin/dialog
SYSCONFIG="/etc/sysconfig"
DIALOGOUT="/tmp/dialogout"
VDRETCDIR=/etc/vdr
EDIT=/bin/nano

function updatelocale
{
. /etc/locale.conf && export LANG
}

function selectSMBFS
{
setConfig SMBFS ""
smbtree --no-pass | sed -e '/^[\t][\t]\\\\/!d' -e '/\$/d' -e '/OpenPCTV/d' -e 's/^[\t][\t]//g' -e 's/  /\t/g' -e 's/\\/\//g' | \
  awk -F"\t" '{print $1}' | sed 's/[[:blank:]]\+$//' | while read line; do
  SERVER=`echo $line | cut -d\/ -f3`
  SHARE=`echo $line | cut -d\/ -f4`
  MNTPOINT="/media/${SERVER}/$(echo ${SHARE} | tr " " "|")"
  IP=`nmblookup.samba3 ${SERVER} | sed -n '2p' | awk '{print $1}'`
  SMBFS=$(getConfig "SMBFS")
  if [ ! -d ${MNTPOINT} ]; then
    mkdir -p ${MNTPOINT}
  elif mountpoint ${MNTPOINT} > /dev/null 2>&1 ; then
    umount ${MNTPOINT}
  fi
  if mount -t cifs -o iocharset=utf8,guest "//${IP}/${SHARE}" ${MNTPOINT} > /dev/null 2>&1 ; then
    ${DIALOG} --ok-label $(gettext "OK") --no-cancel --title "$(gettext "Auto mount cifs")" --pause "Mount //${SERVER}/${SHARE} on ${MNTPOINT} success" 12 60 2
    SMBFS2=`echo "guest@${SERVER}/${SHARE}" | tr ' ' '|'`
    if [ X"${SMBFS}" = "X" ]; then
      setConfig SMBFS "${SMBFS2}"
    else
      setConfig SMBFS "${SMBFS} ${SMBFS2}"
    fi
  else
    if ${DIALOG} --title "$(gettext MSSMBMNT)" --yesno "$(gettext MSSMBMNTINFO)://${SERVER}/${SHARE} on ${MNTPOINT}" 6 80 2>/dev/null; then
      ${DIALOG} --nocancel --title "$(gettext "Auto mount cifs")" --inputbox "$(gettext "Specifies")://${SERVER}/${SHARE} $(gettext "the username"):" 10 70 "${user:=root}" 2> $DIALOGOUT
      user=$(cat $DIALOGOUT)
      ${DIALOG} --nocancel --title "$(gettext "Auto mount cifs")" --inputbox "$(gettext "Specifies")://${SERVER}/${SHARE} $(gettext "the password"):" 10 70 "${pass:=password}" 2> $DIALOGOUT
      pass=$(cat $DIALOGOUT)
      if mount -t cifs -o iocharset=utf8,user=${user},pass=${pass} "//${IP}/${SHARE}" ${MNTPOINT} > /dev/null 2>&1 ; then
        ${DIALOG} --ok-label $(gettext "OK") --no-cancel --title "$(gettext "Auto mount cifs")" --pause "$(gettext "Mount") //${SERVER}/${SHARE} $(gettext "to") ${MNTPOINT} $(gettext "success")" 12 60 2
        SMBFS2=`echo "${user}:${pass}@${SERVER}/${SHARE}" | tr ' ' '|'`
        if [ "X${SMBFS}" = "X" ]; then
          setConfig SMBFS "${SMBFS2}"
        else
          setConfig SMBFS "${SMBFS} ${SMBFS2}"
        fi
      else
        ${DIALOG} --ok-label $(gettext "OK") --no-cancel --title "$(gettext "Auto mount cifs")" --pause "$(gettext "Mount") //${SERVER}/${SHARE} $(gettext "to") ${MNTPOINT} $(gettext "fail")" 12 60 2
      fi
    fi
  fi
done
}

function selectNFSMNT
{
unset line server port user pass cfgkey
NFSMNT=$(getConfig "NFSMNT")
if [ X"NFSMNT" != "X" ]; then
   server=$(echo $NFSMNT | cut -d: -f1)
   share=$(echo $NFSMNT  | cut -d: -f2)
fi
${DIALOG} --nocancel --title "$(gettext MSNFSMNT)" --inputbox "$(gettext "The NFS server name or IP address")" 10 70 "${server:=192.168.1.10}" 2> $DIALOGOUT
server=$(cat $DIALOGOUT)
${DIALOG} --nocancel --title "$(gettext MSNFSMNT)" --inputbox "$(gettext "The name of the NFS share")" 10 70 "${share:=/home}" 2> $DIALOGOUT
share=$(cat $DIALOGOUT)
setConfig NFSMNT "${server}:${share}"
}

function selectSCINPUT
{
  ${DIALOG} --nocancel --title "$(gettext MSSC)" --inputbox "$(gettext "The server name or IP address")" 10 70 "${server}" 2> $DIALOGOUT
  server=$(cat $DIALOGOUT)
  [ "X$server" = "X" ] && scfailinput
  if [ "X$exitsc" != "Xyes" ]; then
     ${DIALOG} --nocancel --title "$(gettext MSSC)" --inputbox "$(gettext "The port of the server")" 10 70 "${port}" 2> $DIALOGOUT
     port=$(cat $DIALOGOUT)
     [ "X$port" = "X" ] && scfailinput
  fi
  if [ "X$exitsc" != "Xyes" ]; then
     ${DIALOG} --nocancel --title "$(gettext MSSC)" --inputbox "$(gettext "Specifies the username")" 10 70 "${user}" 2> $DIALOGOUT
     user=$(cat $DIALOGOUT)
     [ "X$user" = "X" ] && scfailinput
  fi
  if [ "X$exitsc" != "Xyes" ]; then
     ${DIALOG} --nocancel --title "$(gettext MSSC)" --inputbox "$(gettext "Specifies the password")" 10 70 "${pass}" 2> $DIALOGOUT
     pass=$(cat $DIALOGOUT)
     [ "X$pass" = "X" ] && scfailinput
  fi
}

function selectCCCAM
{
  if grep "^cccam2" ${VDRETCDIR}/plugins/sc/cardclient.conf > /dev/null; then
     line=$(grep "^cccam2" ${VDRETCDIR}/plugins/sc/cardclient.conf | sed -n '1p')
     server=$(echo $line | cut -d: -f2)
     port=$(echo $line | cut -d: -f3)
     user=$(echo $line | cut -d: -f5)
     pass=$(echo $line | cut -d: -f6)
  fi
  selectSCINPUT
  if [ "X$server" != "X" -a "X$port" != "X" -a "X$user" != "X" -a "X$pass" != "X" ]; then
     if [ "X$line" = "X" ]; then
        echo "cccam2:${server}:${port}:0/0000/0000:${user}:${pass}" >> ${VDRETCDIR}/plugins/sc/cardclient.conf
     else
        sed -i "s#^cccam2.*#cccam2:${server}:${port}:0/0000/0000:${user}:${pass}#g" ${VDRETCDIR}/plugins/sc/cardclient.conf
     fi
  fi
}

function selectCAMD35
{
  if grep "^camd35" ${VDRETCDIR}/plugins/sc/cardclient.conf > /dev/null; then
     line=$(grep "^camd35" ${VDRETCDIR}/plugins/sc/cardclient.conf | sed -n '1p')
     server=$(echo $line | cut -d: -f2)
     port=$(echo $line | cut -d: -f3)
     user=$(echo $line | cut -d: -f5)
     pass=$(echo $line | cut -d: -f6)
  fi
  selectSCINPUT
  if [ "X$server" != "X" -a "X$port" != "X" -a "X$user" != "X" -a "X$pass" != "X" ]; then
     if [ "X$line" = "X" ]; then
        echo "camd35:${server}:${port}:0/0500,0600,1800,1801,0B00,0602,0604,0606/FFFF:${user}:${pass}" >> ${VDRETCDIR}/plugins/sc/cardclient.conf
     else
        sed -i "s#^camd35.*#camd35:${server}:${port}:0/0500,0600,1800,1801,0B00,0602,0604,0606/FFFF:${user}:${pass}#g" ${VDRETCDIR}/plugins/sc/cardclient.conf
     fi
  fi
}

function selectNEWCAMD
{
  if grep "^newcamd" ${VDRETCDIR}/plugins/sc/cardclient.conf > /dev/null; then
     line=$(grep "^newcamd" ${VDRETCDIR}/plugins/sc/cardclient.conf | sed -n '1p')
     server=$(echo $line | cut -d: -f2)
     port=$(echo $line | cut -d: -f3)
     user=$(echo $line | cut -d: -f5)
     pass=$(echo $line | cut -d: -f6)
     cfgkey=$(echo $line | cut -d: -f7)
  fi
  selectSCINPUT
  if [ "X$exitsc" != "Xyes" ]; then
     ${DIALOG} --nocancel --title "$(gettext MSSC)" --inputbox "$(gettext "Specifies the newcamd cfgkey")" 10 70 "${cfgkey:=0102030405060708091011121314}" 2> $DIALOGOUT
     cfgkey=$(cat $DIALOGOUT)
  fi
  if [ "X$server" != "X" -a "X$port" != "X" -a "X$user" != "X" -a "X$pass" != "X" -a "X${cfgkey}" != "X" ]; then
     if [ "X$line" = "X" ]; then
        echo "newcamd:${server}:${port}:0/0500,0600,1800,1801,0B00,0602,0604,0606/FFFF:${user}:${pass}:${cfgkey}" >> ${VDRETCDIR}/plugins/sc/cardclient.conf
     else
        sed -i "s#^newcamd.*#newcamd:${server}:${port}:0/0500,0600,1800,1801,0B00,0602,0604,0606/FFFF:${user}:${pass}:${cfgkey}#g" ${VDRETCDIR}/plugins/sc/cardclient.conf
     fi
  fi
}

function selectSC
{
  unset line server port user pass cfgkey
  ${DIALOG} --no-cancel --default-item "NoSC" --menu "$(gettext MSSCMENU)" 12 50 5 CCcam "$(gettext MSCCCAM)" Camd35 "$(gettext MSCAMD35)" Newcamd "$(gettext MSNEWCAMD)" NoSC "$(gettext MSNOSC)" 2> $DIALOGOUT
  case $(cat $DIALOGOUT) in
    CCcam)	selectCCCAM
  		;;
    Camd35)	selectCAMD35
  		;;
    Newcamd)	selectNEWCAMD
  		;;
  esac
  ${DIALOG} --defaultno --yesno "$(gettext "EditSC")" 10 70
  if [ $? -eq 0 ]; then
    $EDIT ${VDRETCDIR}/plugins/sc/cardclient.conf
  fi
}

function selectCACHE
{
CACHE="$(getConfig "CACHE")"
if [ x"${CACHE}" != x ]; then
   DEFAULTITEM="--default-item ${CACHE}"
else
   DEFAULTITEM=""
fi
echo "${DIALOG} ${DEFAULTITEM} --no-cancel --menu \"$(gettext "Select a partition for OpenPCTV cache...")\" 12 65 10 \\" > /tmp/selectCACHEMENU
df  | grep "/media" | awk '{if($4 > 6000000) print $2,$3,$4,$6}' | while read line; do
  Size=$(($(echo ${line} | awk '{print $1}')/1048576))G
  Used=$(($(echo ${line} | awk '{print $2}')/1048576))G
  Available=$(($(echo ${line} | awk '{print $3}')/1048576))G
  Mounted=`echo ${line} | awk '{print $4}'`
  if touch ${Mounted}/testfile 2> /dev/null; then
    rm ${Mounted}/testfile
    echo "${Mounted} \"$(gettext Size):${Size},$(gettext Used):${Used},$(gettext Available):${Available}\" \\" >> /tmp/selectCACHEMENU
  fi
done
echo "None \"$(gettext "Don't mount bind for OpenPCTV cache")\" \\" >> /tmp/selectCACHEMENU
echo "2> $DIALOGOUT" >> /tmp/selectCACHEMENU
. /tmp/selectCACHEMENU
CACHE=`cat $DIALOGOUT`
rm /tmp/selectCACHEMENU
if [ X"${CACHE}" != "XNone" ]; then
   [ ! -d ${CACHE}/cnvdrcache ] && mkdir -p ${CACHE}/cnvdrcache
   [ ! -d ${CACHE}/cnvdrcache/video ] && mkdir -p ${CACHE}/cnvdrcache/video
   [ ! -d ${CACHE}/cnvdrcache/pps ] && mkdir -p ${CACHE}/cnvdrcache/pps
   setConfig "CACHE" "$CACHE"
fi
}

function setupinit
{
/usr/bin/select-language
updatelocale
/usr/bin/select-target
/usr/bin/netconfig
/usr/bin/install-drivers
/usr/bin/select-irdrv
systemctl restart lircd
systemctl stop vdr
systemctl stop vdr-backend
/usr/bin/monitor.sh
/usr/bin/audio-config init
/usr/bin/getcam
/usr/bin/update-epg
/usr/bin/update-transponders
dialog --defaultno --clear --yesno "$(gettext "Would you like to configure DiSEqC and scan channels for VDR/XBMC? If you use only enigma2, then you could not continue with the configuration.")" 7 70
if [ $? -eq 0 ]; then
  /usr/bin/diseqcsetup
  /usr/bin/update-channels
fi
}

function MainMenu
{
updatelocale
  ${DIALOG} --no-cancel --backtitle "$(gettext "OpenPCTV configurator")" --menu "$(gettext "Main menu")" 21 60 14 Lang "$(gettext "Set global locale and language")" Target "$(gettext "Set the default target")" Netconf "$(gettext "Configure Network Environment")" Driver "$(gettext "Install additional V4L and DVB drive")" Lirc "$(gettext "Select IR device")" Monitor "$(gettext "Set the monitor's best resolution")" Audio "$(gettext "Soundcard Configuration")" Uptran "$(gettext "Auto update Satellite Transponders and EPG data")" CAM "$(gettext "Select a software emulated CAM")" DiSEqC "$(gettext "DiSEqC configurator")" Scan "$(gettext "Auto scan channels")" Reboot "$(gettext "Reboot OpenPCTV")" Exit "$(gettext "Exit to login shell")" 2> $DIALOGOUT
  case "$(cat $DIALOGOUT)" in
    Lang)	/usr/bin/select-language
		MainMenu
		;;
    Target)	/usr/bin/select-target
		MainMenu
		;;
    Netconf)	/usr/bin/netconfig
		MainMenu
		;;
    Driver)	/usr/bin/install-drivers
		MainMenu
		;;
    Lirc)	/usr/bin/select-irdrv
		systemctl restart lircd
    		MainMenu
 		;;
    Uptran)	/usr/bin/update-transponders
		/usr/bin/update-epg
    		MainMenu
  		;;
    CAM)	/usr/bin/getcam
		MainMenu
		;;
    DiSEqC)	systemctl stop vdr
		systemctl stop vdr-backend
		/usr/bin/diseqcsetup
    		MainMenu
  		;;
    Scan)	systemctl stop vdr
		systemctl stop vdr-backend
                /usr/bin/update-channels
		MainMenu
		;;
    Monitor)	/usr/bin/monitor.sh
		MainMenu
		;;
    Audio)	/usr/bin/audio-config
		MainMenu
		;;
    Reboot)	reboot
		;;
    Exit)	clear
    		exit 0
    		;;
  esac
}

[ X$1 = "Xinit" -a ! -f /etc/system.options ] && setupinit
MainMenu
