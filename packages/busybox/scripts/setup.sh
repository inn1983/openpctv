#!/bin/bash

. gettext.sh
export TEXTDOMAIN=openpctv

DIALOG=/usr/bin/dialog
SYSCONFIG="/etc/sysconfig"
DIALOGOUT="/tmp/dialogout"
PLUGINDIR=/usr/lib/vdr
CHANNELDIR=/etc/vdr/channels
VDRETCDIR=/etc/vdr
VDRBIN=/usr/bin/vdr
EDIT=/bin/nano
ACTIVYFOUND="no"
BACKUPDATE=$(date +%Y%m%d%H%M%S)

function selectaudio
{
echo "${DIALOG} --no-cancel --title \"$(gettext "Select Audio Output")\" --menu \"$(gettext "please select a card/device for audio output")\" 11 80 4 \\" > /tmp/selectaudio.menu
aplay -l | grep card | while read line; do
   echo "\"$line\" \"\" \\" >> /tmp/selectaudio.menu
done
echo "2> /tmp/selectaudio" >> /tmp/selectaudio.menu
sh /tmp/selectaudio.menu

card=`awk '{print $2}' /tmp/selectaudio | sed 's/://'`
device=`awk -F, '{print $2}' /tmp/selectaudio | awk '{print $2}' |sed 's/://'`

if grep -iq "HDMI" /tmp/selectaudio 2>/dev/null || grep -iq "Digital" /tmp/selectaudio 2>/dev/null; then
   mode="SPDIF"
else
   mode="analog"
fi

rm /tmp/selectaudio /tmp/selectaudio.menu

sed -i -e "s/^ALSA_CARD=.*/ALSA_CARD=\"$card\"/g" \
    -e "s/^SOUNDCARD_MODE=.*/SOUNDCARD_MODE=\"$mode\"/g" /etc/audio

sed -i -e "s/^card.*/card ${card}/g" \
    -e "s/^pcm \"hw:.*/pcm \"hw:${card},${device}\"/g" /root/.asoundrc

/etc/init.d/alsa

mplayer -ao alsa:device=hw=${card}.${device} /usr/share/sounds/test.ogg > /dev/null 2>&1 &

left=12
while test $left != 0
do

${DIALOG} --sleep 1 \
       --title "$(gettext "Test Audio Output")" \
       --infobox "$(gettext "Playing music, please wait for") $left $(gettext "seconds ...")" 6 60
left=`expr $left - 1`
test $left = 1
done
}

function setAudio()
{
retval=1
while [ $retval -eq 1 ]; do
 selectaudio
 ${DIALOG} --title "$(gettext "Can you hear the test music?")" --clear \
  	--yesno "$(gettext "If not, please check your audio output device. Here you can select \"No\" to re-set the audio output interface.")" 7 60
 retval=$?
done
}

function getCDRom()
{
  CDROM="/dev/$(CDRomDEV)"
  if [ ! -z ${CDROM} ]; then
    ${DIALOG} --infobox "$(gettext "Found a cdrom")" 5 40
  else
    ${DIALOG} --msgbox "$(gettext "Not findout any cdrom")" 5 40
  fi
}

function cleanUp()
{
  if [ -r ${DIALOGOUT} ]; then
    rm -f ${DIALOGOUT}
  fi
}

# <-------------- Dialoge ---------------->
# ========================================================
# Sprachauswahl
function getLanguage()
{
  LC_ALL=$(getConfig "LC_ALL")
  if [ "X$LC_ALL" != "X" ]; then
     ${DIALOG} --ok-label $(gettext "OK") --default-item "$LC_ALL" --no-cancel --menu "Select Language" 11 40 4 zh_CN.UTF-8 "简体中文" zh_TW.UTF-8 "繁體中文" en_US.UTF-8 "English" 2> $DIALOGOUT
  else
     export LC_ALL=zh_CN.UTF-8
     export LANGUAGE=zh_CN.UTF-8
     export LANG=zh_CN.UTF-8
     ${DIALOG} --ok-label $(gettext "OK") --no-cancel --menu "Select Language" 11 40 4 zh_CN.UTF-8 "简体中文" zh_TW.UTF-8 "繁體中文" en_US.UTF-8 "English" 2> $DIALOGOUT
  fi
  export LC_ALL=$(cat $DIALOGOUT)
  export LANGUAGE=$LC_ALL
  LANG=$(echo $LC_ALL | cut -d. -f1)
  sed -i "s/OSDLanguage.*/OSDLanguage = ${LANG}/g" ${VDRETCDIR}/setup.conf
  if [ -f ${VDRETCDIR}/channels.conf.${LANG} ]; then
     cp ${VDRETCDIR}/channels.conf ${VDRETCDIR}/channels.conf.${BACKUPDATE}
     cp ${VDRETCDIR}/channels.conf.${LANG} ${VDRETCDIR}/channels.conf
  fi
  . gettext.sh
  export TEXTDOMAIN=cnvdrsetup
  setConfig "LC_ALL" "${LC_ALL}"
}

function selectSMBFS
{
setConfig SMBFS ""
smbtree --no-pass | sed -e '/^[\t][\t]\\\\/!d' -e '/\$/d' -e '/CNVDR/d' -e 's/^[\t][\t]//g' -e 's/  /\t/g' -e 's/\\/\//g' | \
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

function selectCDRom
{
  CDROM=$(getConfig "CDROM")
  CMD="${DIALOG} --no-cancel --menu \"$(gettext selectCDRom)\" 20 70 10 "
  for cdrom in $(CDRomDEV); do
    CMD="$CMD $cdrom \"$(gettext $cdrom)\" "
  done
  CMD="$CMD 2> $DIALOGOUT"
  echo "$CMD" >/tmp/CDCMD
  eval $CMD
  CDROM="/dev/$(cat $DIALOGOUT)"
  setConfig "CDROM" "${CDROM}"
  ln -sf ${CDROM} /dev/cdrom
}

# ========================================================
# Channelauswahl
function selectChannels()
{
  CMD=""
  CHANNELDIALOG=""
  if [ "${ACTIVYFOUND}" == "yes" ]; then
    ${DIALOG} --msgbox "$(gettext ActivyPluginSelect)" 10 70
  fi
  ${DIALOG} --infobox "$(gettext "ChannelSearch")" 5 70
  for CHANNEL in $(ls ${CHANNELDIR}/*); do
    CHANNELDIALOG="${CHANNELDIALOG} \"$(basename $CHANNEL)\" \"<-- \" $(isChannel $CHANNEL)"
  done
  
  CMD="${DIALOG} --ok-label \"$(gettext OK)\" --no-cancel --menu \"$(gettext selectChannel)\" 25 78 16 ${CHANNELDIALOG} 2> $DIALOGOUT"
  eval $CMD

  CHANNEL=$(cat $DIALOGOUT)
  if [ ! -z $CHANNEL ]; then
    rm -f ${VDRETCDIR}/channels.conf 2> /dev/null
    ln -s ${CHANNELDIR}/$(basename ${CHANNEL}) ${VDRETCDIR}/channels.conf
    export CHANNELSCONF="$(ls -l ${VDRETCDIR}/channels.conf | awk -F "-> " '{ print $2 }')"
  fi
}


function scfailinput
{
  ${DIALOG} --yesno "$(gettext "MSSCFIALINPUT")" 10 70
  if [ $? -eq 0 ]; then
    selectSC
  else
    exitsc="yes"
  fi
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
echo "${DIALOG} ${DEFAULTITEM} --no-cancel --menu \"$(gettext "Select a partition for CNVDR cache...")\" 12 65 10 \\" > /tmp/selectCACHEMENU
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
echo "None \"$(gettext "Don't mount bind for CNVDR cache")\" \\" >> /tmp/selectCACHEMENU
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

# ======================================================
# Main Menu
function MainMenu
{
  ${DIALOG} --no-cancel --backtitle "$(gettext "OpenPCTV configurator")" --menu "$(gettext "Main menu")" 13 70 6 Lirc "$(gettext "Select IR device")" Uptran "$(gettext "Auto update Satellite Transponders from fastsatfinder")" DiSEqC "$(gettext "DiSEqC configurator")" Scan "$(gettext "Auto scan channels")" Exit "$(gettext Exit)" 2> $DIALOGOUT
  case "$(cat $DIALOGOUT)" in
    Lirc)		select-irdrv
			systemctl restart lircd
    			MainMenu
 			;;
    Uptran)		/usr/bin/update-transponders
    			MainMenu
  			;;
    DiSEqC)		systemctl stop vdr
			/usr/bin/diseqcsetup
    			MainMenu
  			;;
    Scan)		systemctl stop vdr
                        /usr/bin/update-channels
			MainMenu
			;;
    Exit)		#saveSysconfig
    			clear
    			exit 0
    			;;
  esac
}

# ======================================================
# Funktionen durchlaufen

MainMenu
