#!/bin/sh

export TERM=linux
. gettext.sh
export TEXTDOMAIN=openpctv
modeconf=/etc/X11/xorg.conf.d/100-mode.conf

dialog --title "$(gettext "Do you need to set the monitor's best resolution?")" --defaultno --yesno "$(gettext "Most modern monitors/TVs can be probed for EDID data concerning their capabilities and requirements.So normally you do not need to make any settings for Xorg. But EDID is not always completely accurate, and for some situations such as older or unusual display hardware or many HDTVs, it will be necessary to create a modeline to get the setting right. We'll enter the monitor configuration if you select 'Yes'")" 11 70

[ $? -eq 1 ] && exit

x=1920
y=1080
refresh=60
returncode=0
while test $returncode != 1 && test $returncode != 250
do
exec 3>&1
value=`dialog --ok-label "$(gettext "Submit")" --backtitle "$(gettext "Set the monitor's best resolution")" --clear \
	--form "$(gettext "Confirm the optimal resolution your monitor supported. Note that the full HD resolution is 1920x1080.")" 15 60 3 \
	"X:"		1 15	"$x"		1 25 5 0 \
	"Y:"		2 15	"$y"		2 25 5 0 \
	"Refresh:"	3 15	"$refresh"	3 25 5 0 \
2>&1 1>&3`
returncode=$?
exec 3>&-
show=`echo "$value" |sed -e 's/^/       /'`

        case $returncode in
        	1)
                dialog \
                --clear \
                --backtitle "$(gettext "Set the monitor's best resolution")" \
                --yesno "$(gettext "Really quit?")" 10 30
                case $? in
                0)
                        exit
                        ;;
                1)
                        returncode=99
                        ;;
                esac
                ;;
        0)
		break
                ;;
        *)
                echo "Return code was $returncode"
                exit
                ;;
        esac
done

Modeline=$(cvt $show | grep ^Modeline)
Mode=$(echo $show | awk '{print $1"x"$2}')

sed -e "s#%Modeline%#$Modeline#g" -e "s#%Mode%#\"$Mode\"#g" > $modeconf << _EOF
Section "Monitor"
	Identifier	"Monitor0"
	%Modeline%
	Option		"DPMS"
EndSection
Section "Screen"
	Identifier	"Screen0"
	Device		"Device0"
	Monitor		"Monitor0"
	DefaultDepth	24
	SubSection	"Display"
		Depth	24
		Modes	%Mode%
	EndSubSection
EndSection
_EOF
