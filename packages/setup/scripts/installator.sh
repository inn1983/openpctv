#!/bin/sh

systemctl start plymouth-quit
export TERM=linux
. gettext.sh
export TEXTDOMAIN=openpctv

LOGFILE=/tmp/install.log
BOOTDISK_MNT=/mnt/BootDisk
. /etc/os-release

installmsg () {
# Convert an OS device to the corresponding GRUB drive.
MSG_DEV_NO_BLOCK="$(gettext "Not found or not a block device.")"
MSG_BIOS_NO_DRIVE="$(gettext "does not have any corresponding BIOS drive.")"

# Keymap Setup
MSG_KEYMAP_CONFIG="$(gettext "Keymap selection")"

MSG_KEYMAP="$(gettext "Choose Keymap")"
MSG_KEYMAP_DESC="$(gettext "Which keymap do you want to use ?")"

# Disk Setup
MSG_DISK_WARNING="$(gettext "Warning")"
MSG_DISK_ERROR="$(gettext "ERROR")"

MSG_DISK_NOT_FOUND="$(gettext "No disks found on this system.\nCheck again ?")"
MSG_DISK_REFRESH="$(gettext "refresh list")"

MSG_DISK_DEVICE="$(gettext "Installation device")"
MSG_DISK_DEVICE_DESC="$(gettext "You are going to install OpenPCTV. For this you will need an empty partition with about 5 GB of free space. Be careful to choose the right disk! We won't take responsibility for any data loss.")"

MSG_DISK_PART="$(gettext "Linux EXT4 partition")"

MSG_CFDISK_BEGIN="$(gettext "Before continue the installator program you need to define the Linux partition(s) on your hard disk. We can use other partitioning tool under Linux/Windows before this. Or if you select 'Yes', you'll use cfdisk to edit your partition table to create a")"
MSG_CFDISK_END="$(gettext "with about 5 GB of free space. The partition type can be arbitrary. Don't forget to set the bootable flag to this partition. Remember to commit the changes when done. We won't take responsibility for any data loss. If you choose 'No' means that you've prepared a partition for it.")"

# Installation
MSG_INSTALL_DEV_CONFIG="$(gettext "Installation device")"

MSG_INSTALL_DEV_NOPART_BEGIN="$(gettext "You don't have any")"
MSG_INSTALL_DEV_NOPART_END="$(gettext "partition on your system. Please create a partition first using for example cfdisk.")"
MSG_INSTALL_DEV_DESC="$(gettext "Where do you want to install OpenPCTV? Please choose carefully!")"
MSG_INSTALL_DEV_BAD_BLOCK="$(gettext "is not a valid block device.")"

MSG_INSTALL_DEV_NO_FORMAT="$(gettext "Partition is not formated")"
MSG_INSTALL_DEV_FORMAT_BEGIN="$(gettext "Partition format type")"
MSG_INSTALL_DEV_FORMAT_END="$(gettext "is not supported in your partition type")"
MSG_INSTALL_DEV_FORMATED="$(gettext "Partition is already formated")"
MSG_INSTALL_DEV_FORMAT="$(gettext "Formatting")"
MSG_INSTALL_DEV_FORMAT_DESC="$(gettext "Do you want to format")"
MSG_INSTALL_DEV_FORMATTING_WAIT_BEGIN="$(gettext "Formatting")"
MSG_INSTALL_DEV_FORMATTING_WAIT_END="$(gettext "...\nPlease wait")"

MSG_INSTALL_PART_TYPE="$(gettext "Linux partition type")"
MSG_INSTALL_PART_TYPE_DESC="$(gettext "Which type of Linux partition you want ?")"

MSG_INSTALL_FORMAT_NO_TOOLS="$(gettext "As you don't have formatting tool installed, I won't be able to format the partition.")"
MSG_INSTALL_FORMAT_ALREADY="$(gettext "Hopefully it is already formatted.")"
MSG_INSTALL_FORMAT_BAD_TYPE="$(gettext "should be formatted as")"

MSG_INSTALL_MOUNT_FAILED="$(gettext "Failed to mount")"

MSG_INSTALLING_WAIT="$(gettext "Installing... Please wait")"

# Config Options
MSG_CFG_HDTV="$(gettext "Support for HDTV through X.Org ?")"
MSG_CFG_HDTV_DESC="$(gettext "It appears that this version of OpenPCTV has been compiled with support for HDTV through X.Org video server. Remember that X.Org is only useful if you want to display high-resolution movies on a wide display (LCD TVs, Plasma screens ...). It doesn't provide TVOut support any longer. Do you want to enable support for HDTV as a default ? (previous non-HD mode will still be available)")"

# Bootloader
MSG_BOOTLOADER="$(gettext "Bootloader")"

MSG_GRUB_NO_ROOTDEV="$(gettext "Couldn't find my GRUB partition representation")"
MSG_GRUB_SETUP_ERROR="$(gettext "Couldn't install GRUB bootloader!")"

MSG_LOADER_MULTIBOOT_BEGIN="$(gettext "is now a OpenPCTV partition. To boot from it, you will need to install a bootloader. I can install one for you. If you have any other operating system on your computer, I will also install a multiboot for you. If you do not want me to install a new bootloader, you will need to configure yours alone.\nI have found:")"
MSG_LOADER_MULTIBOOT_END="$(gettext "Do you want to install me to install the boot loader (GRUB) for you ?")"
MSG_LOADER_NONE="$(gettext "is now a OpenPCTV partition. I didn't recognize any other OS on your system, want me to install boot loader on your MBR ?")"
MSG_LOADER_ERROR="$(gettext "You must install a boot loader to boot OpenPCTV")"

# Log Messages
MSG_LOG="$(gettext "Installation Log")"
MSG_LOG_DESC="$(gettext "Do you want to check installation logs ? (it is probably useful for debug purpose only)")"

# End of install
MSG_SUCCESS="$(gettext "Have Fun!")"
MSG_SUCCESS_DESC_BEGIN="$(gettext "OpenPCTV is now installed on")"
MSG_SUCCESS_DESC_END="$(gettext "Do you want to reboot? Or press Alt+F2 to configure by manual")"

MSG_GRUB_START="$(gettext "Start")"
MSG_GRUB_DEFAULT="$(gettext "Default target")"
MSG_GRUB_SETUP="$(gettext "setup mode")"
MSG_GRUB_DEBUG="$(gettext "debugging mode")"
}

# Acts just like echo cmd, with automatic redirection
dbglg () {
  echo "$@" >> $LOGFILE
}

# Detect whether partition ($1) mounted at ($2) with type ($3) is microsoft.
detect_os_microsoft () {
  local LONGNAME

  if [ "$3" != ntfs -a "$3" != vfat -a "$3" != msdos -a "$3" != fuseblk ]; then
    return
  fi

  if [ -e "$2/ntldr" -a -e "$2/NTDETECT.COM" ]; then
    LONGNAME="Windows NT/2000/XP/Vista"
  elif [ -e "$2/windows/win.com" ]; then
    LONGNAME="Windows 95/98/Me"
  elif [ -e "$2/bootmgr" -a -d "$2/Boot" ]; then
    LONGNAME="Windows 7"
  elif [ -d "$2/dos" ]; then
    LONGNAME="MS-DOS 5.x/6.x/Win3.1"
  else
    return
  fi

  echo "$1:$LONGNAME:chain"
}

detect_os () {
  local PARTNAME PARTITION TYPE MPOINT

  mkdir -p tmpmnt

  for PARTNAME in `sed -n "s/\ *[0-9][0-9]*\ *[0-9][0-9]*\ *[0-9][0-9][0-9]*\ \([a-z]*[0-9][0-9]*\)/\1/p" /proc/partitions`; do
    PARTITION="/dev/$PARTNAME"

    if ! grep -q "^$PARTITION " /proc/mounts; then
      if mount -o ro $PARTITION tmpmnt >/dev/null 2>&1; then
        TYPE=$(grep "^$PARTITION " /proc/mounts | cut -d " " -f 3)
        detect_os_microsoft $PARTITION tmpmnt $TYPE

        umount tmpmnt >/dev/null || return
      fi
    else
      MPOINT=$(grep "^$PARTITION " /proc/mounts | cut -d " " -f 2)
      TYPE=$(grep "^$PARTITION " /proc/mounts | cut -d " " -f 3)

      detect_os_microsoft $PARTITION $MPOINT $TYPE
    fi
  done

  rmdir tmpmnt
}

# Usage: convert os_device
# Convert an OS device to the corresponding GRUB drive.
# This part is OS-specific.
# -- taken from `grub-install`
# $1 is DEV
# $2 is DEVICE_MAP
convert () {
  local TMP_DRIVE TMP_DISK TMP_PART

  if test ! -e "$1"; then
    echo "$1: $MSG_DEV_NO_BLOCK" 1>&2
    exit 1
  fi

  TMP_DISK=`echo "$1" | sed -e 's%\([sh]d[a-z]\)[0-9]*$%\1%'`
  TMP_PART=`echo "$1" | sed -e 's%.*/[sh]d[a-z]\([0-9]*\)$%\1%'`

  TMP_DRIVE=`grep -v '^#' $2 | grep "$TMP_DISK *$" \
			| sed 's%.*\(([hf]d[0-9][a-g0-9,]*)\).*%\1%'`

  if [ -z "$TMP_DRIVE" ]; then
    echo "$1 $MSG_BIOS_NO_DRIVE" 1>&2
    exit 1
  fi

  if [ -n "$TMP_PART" ]; then
    # If a partition is specified, we need to translate it into the
    # GRUB's syntax.
    echo "$TMP_DRIVE" | sed "s%)$%,$(($TMP_PART)))%"
  else
    # If no partition is specified, just print the drive name.
    echo "$TMP_DRIVE"
  fi
}

# Returns the value to use for a given variable ($1) as was found
# in the boot arguments, otherwise returns a default value ($2)
cmdline_default () {
  local RET=`sed -n "s/.*$1=\([^ ]*\).*/\1/p" /proc/cmdline`
  test -z $RET && RET=$2
  echo $RET
}

# Select language definitions
setup_lang () {
  /usr/bin/select-language
  . /etc/locale.conf && export LANG
  installmsg
}

# Select keymap: Prompts users for available keymaps, and loads the selected one
setup_keymap () {
  local i 
  local KEYMAP_OLD=`cmdline_default keymap qwerty`
  local KEYMAPS="qwerty qwerty"
  for i in `ls /etc/keymaps`; do
    KEYMAPS="$KEYMAPS $i $i"
  done

  KEYMAP=`dialog --no-cancel --stdout \
    --backtitle "$BACKTITLE : $MSG_KEYMAP_CONFIG" --title "$MSG_KEYMAP" \
    --default-item $KEYMAP_OLD --menu "$MSG_KEYMAP_DESC" 0 0 0 $KEYMAPS ` \
    || exit 1

  test -f "/etc/keymaps/$KEYMAP" && loadkmap < "/etc/keymaps/$KEYMAP"
}

# Offer a list of possible disks on which to install to the user,
# and return with the selected disk name
choose_disk () {
  local DISK_LIST SELECTED_DISK SIZE VENDOR MODEL DISKNAME i
  while true; do
    DISK_LIST=""
    for i in `cat /proc/partitions | sed -n "s/\ *[0-9][0-9]*\ *[0-9][0-9]*\ *[0-9][0-9]*\ \([a-z]*\)$/\1/p"`; do
      SIZE=`sfdisk -s /dev/$i | sed 's/\([0-9]*\)[0-9]\{3\}/\1/'`
      VENDOR=`[ -f /sys/block/$i/device/vendor ] \
              && cat /sys/block/$i/device/vendor`
      MODEL=`[ -f /sys/block/$i/device/model ] \
             && cat /sys/block/$i/device/model`
      DISKNAME=`echo $VENDOR $MODEL ${SIZE}MB | sed 's/ /_/g'`
      DISK_LIST="$DISK_LIST $i $DISKNAME"
    done

    if [ -z "$DISK_LIST" ]; then
      dialog --aspect 15 --backtitle "$BACKTITLE" --title "$MSG_DISK_ERROR" \
        --yesno "\n${MSG_DISK_NOT_FOUND}" 0 0 1>&2 || exit 1
    else
      SELECTED_DISK=`dialog --stdout --backtitle "$BACKTITLE" \
                       --title "$MSG_DISK_DEVICE" \
                       --menu "\n${MSG_DISK_DEVICE_DESC}" 0 0 0 $DISK_LIST refresh "$MSG_DISK_REFRESH"`
      [ -z "$SELECTED_DISK" ] && break
      [ $SELECTED_DISK != refresh ] && break
    fi
  done

  echo $SELECTED_DISK
}

# Prompt and get the desired partition name from the selected disk ($1),
# and returns the device name of that partition
choose_partition_dev () {
  local LOC_DISK="$1"
  local DEV_SEL DEV_LIST SIZE VENDOR MODEL FSTYPE DEVNAME i
  dbglg "Input arg for DISK is $1"
  while [ ! -b "$DEV_SEL" ]; do
    DEV_LIST=""
    for i in `fdisk -l /dev/$LOC_DISK 2>/dev/null | grep ${LOC_DISK%disc} | \
              cut -f1 -d' ' | grep dev`; do
      case `sfdisk --print-id ${i%%[0-9]*} ${i#${i%%[0-9]*}}` in
        f)
	  ;;
	*)
          SIZE=`sfdisk -s "$i" | sed 's/\([0-9]*\)[0-9]\{3\}/\1/'`
          VENDOR=`cat /sys/block/$LOC_DISK/device/vendor`
          MODEL=`cat /sys/block/$LOC_DISK/device/model`
          FSTYPE=`grub-probe -d $i -t fs`
          DEVNAME=`echo $VENDOR $MODEL $FSTYPE ${SIZE}MB | sed 's/ /_/g'`
          DEV_LIST="$DEV_LIST $i $DEVNAME"
          LASTITEM="--default-item $i"
          ;;
      esac
    done
    
    [ -x /usr/sbin/lvm ] && for i in `lvm lvs --noheadings --nosuffix --units M --separator ":" $LOC_DISK 2>/dev/null | sed "s/^\ *//g"`; do
      SIZE=`echo $i | cut -d\: -f4 | sed "s/\.[0-9]*//g"`
      VENDOR="LVM"
      MODEL="Logical Volume"
      LVNAME=`echo $i | cut -d\: -f1 | sed 's/ /_/g'`
      DEVNAME=`echo $VENDOR $MODEL ${SIZE}MB | sed 's/ /_/g'`
      DEV_LIST="$DEV_LIST /dev/${LOC_DISK}/${LVNAME} $DEVNAME"
      LASTITEM="--default-item $i"
    done

    if [ -z "$DEV_LIST" ]; then
      dbglg "DEV_LIST var empty!"
      dialog --aspect 15 --backtitle "$BACKTITLE" --title "$MSG_DISK_ERROR" \
        --msgbox "\n$MSG_INSTALL_DEV_NOPART_BEGIN $MSG_DISK_PART $MSG_INSTALL_DEV_NOPART_END\n" 0 0 1>&2
      exit 1
    else
      DEV_SEL=`dialog --stdout --aspect 15 --backtitle "$BACKTITLE" $LASTITEM \
        --title "$MSG_INSTALL_DEV_CONFIG" --menu "$MSG_INSTALL_DEV_DESC" \
        0 0 0 $DEV_LIST`
    fi
    [ -z "$DEV_SEL" ] && exit 1
    if [ ! -b "$DEV_SEL" ]; then
      dbglg "DEV_SEL $DEV_SEL is not a valid block device!"
      dialog --aspect 15 --backtitle "$BACKTITLE" --title "$MSG_DISK_ERROR" \
        --msgbox "\n'$DEV_SEL' $MSG_INSTALL_DEV_BAD_BLOCK\n" 0 0 1>&2 \
        || exit 1
    fi
  done

  echo "$DEV_SEL"
}


# Try to guess current partition fs type of dev ($1).
guess_partition_type () {
  local type FS_TYPE=""
  for type in vfat ext4 ext3 ext2 auto; do
    if mount -o ro -t $type "$1" $BOOTDISK_MNT 2>/dev/null; then
      FS_TYPE=`grep "^$1 " /proc/mounts | cut -d " " -f 3`
      umount $BOOTDISK_MNT
      break
    fi
  done
  dbglg "guess_partition_type() returned \"$FS_TYPE\""
  echo $FS_TYPE
}

# Decides if a format is needed (or desired) and manages the process
# $1 is global MKFS_TYPE, and also updates MKFS_TYPE variable
# $2 is DEV
format_if_needed () {
  local NEED_FORMAT=yes
  local FORMAT_DEFAULT=""
  local LOC_MKFS_TYPE="$1"
  local LOC_DEV="$2"
  local FORMAT_MSG FORMAT MKFS MKFS_OPT MKFS_TYPENAME FORMAT
  local SUPPORTED_TYPES PART_TYPE

  # Set valid FS types based on selected install partition
  if ( [ -x /usr/sbin/lvm ] && lvm lvdisplay $LOC_DEV >/dev/null 2>&1 ); then
    SUPPORTED_TYPES="vfat ext4 ext3 ext2"
    PART_TYPE="LVM"
  else
    case `sfdisk --print-id ${LOC_DEV%%[0-9]*} ${LOC_DEV#${LOC_DEV%%[0-9]*}}` in
      1|11|6|e|16|1e|14|b|c|1b|1c)
        SUPPORTED_TYPES="vfat"
        PART_TYPE="FAT"
        ;;
      83) # Linux
        SUPPORTED_TYPES="ext4 ext3 ext2"
        PART_TYPE="Linux"
        ;;
    esac
  fi

  dbglg "SUPPORTED_TYPES $SUPPORTED_TYPES PART_TYPE $PART_TYPE"
  dbglg "LOC_MKFS_TYPE \"$LOC_MKFS_TYPE\" LOC_DEV \"$LOC_DEV\""

  if [ -z "$LOC_MKFS_TYPE" ]; then
    FORMAT_MSG="$MSG_INSTALL_DEV_NO_FORMAT"
    FORMAT_DEFAULT=""
  else
    for type in $SUPPORTED_TYPES; do
      [ $type = $LOC_MKFS_TYPE ] && NEED_FORMAT=no
    done

    if [ "$NEED_FORMAT" = yes ]; then
      FORMAT_MSG="$MSG_INSTALL_DEV_FORMAT_BEGIN ($LOC_MKFS_TYPE) $MSG_INSTALL_DEV_FORMAT_END ($PART_TYPE)."
      FORMAT_DEFAULT=""
    else
      FORMAT_MSG="$MSG_INSTALL_DEV_FORMATED"
    fi
  fi

  dialog --aspect 15 --backtitle "$BACKTITLE" \
    --title "$MSG_INSTALL_DEV_FORMAT" $FORMAT_DEFAULT \
    --yesno "${FORMAT_MSG}\n${MSG_INSTALL_DEV_FORMAT_DESC} '$LOC_DEV' ?\n" \
    0 0 1>&2 \
    && FORMAT=yes

  if [ "$FORMAT" = yes ]; then
    if ( [ -x /usr/sbin/lvm ] && lvm lvdisplay $LOC_DEV >/dev/null 2>&1 ); then
      LOC_MKFS_TYPE=`dialog --stdout --aspect 15 --backtitle "$BACKTITLE" \
        --title "$MSG_INSTALL_PART_TYPE" --menu "$MSG_INSTALL_PART_TYPE_DESC"\
        0 0 0 ext4 "Linux ext4" ext3 "Linux ext3" ext2 "Linux ext2" vfat "Dos vfat"` \
        || exit 1
    else
      case `sfdisk --print-id ${LOC_DEV%%[0-9]*} ${LOC_DEV#${LOC_DEV%%[0-9]*}}` in
        1|11|6|e|16|1e|14) # FAT12 and FAT16
          LOC_MKFS_TYPE="vfat"
          ;;
        b|c|1b|1c) # FAT32
          LOC_MKFS_TYPE="vfat"
          ;;
        83) # Linux
          LOC_MKFS_TYPE=`dialog --stdout --aspect 15 --backtitle "$BACKTITLE" \
            --title "$MSG_INSTALL_PART_TYPE" --menu "$MSG_INSTALL_PART_TYPE_DESC"\
            0 0 0 ext4 "Linux ext4" ext3 "Linux ext3" ext2 "Linux ext2"` \
            || exit 1
          ;;
      esac
    fi
    case $LOC_MKFS_TYPE in
      vfat)
        MKFS=mkfs.vfat
        MKFS_OPT="-n OPENPCTV"
        LOC_MKFS_TYPE=vfat
        MKFS_TYPENAME="FAT"
        ;;
      ext2)
        MKFS=mke2fs
        MKFS_OPT="-L OPENPCTV"
        MKFS_TYPENAME="Linux ext2"
        ;;
      ext3)
        MKFS=mke2fs
        MKFS_OPT="-L OPENPCTV -j"
        MKFS_TYPENAME="Linux ext3"
        ;;
      ext4)
        MKFS=mke2fs
        MKFS_OPT="-L OPENPCTV -t ext4"
        MKFS_TYPENAME="Linux ext4"
    esac

    if [ -z "$MKFS" ]; then
      if [ "$NEED_FORMAT" = yes ]; then
        dialog --aspect 15 --backtitle "$BACKTITLE" --title "$MSG_DISK_ERROR" \
          --msgbox "\n${MSG_INSTALL_DEV_NO_FORMAT} ('$LOC_DEV'). ${MSG_INSTALL_FORMAT_NO_TOOLS}\n" 0 0 1>&2
        rmdir $BOOTDISK_MNT
        exit 1
      else
        dialog --aspect 15 --backtitle "$BACKTITLE" --title "$MSG_DISK_WARNING"\
          --msgbox "\n'$LOC_DEV' $MSG_INSTALL_FORMAT_BAD_TYPE $MKFS_TYPENAME. ${MSG_INSTALL_FORMAT_NO_TOOLS}. ${MSG_INSTALL_FORMAT_ALREADY}\n" 0 0 1>&2 \
          || exit 1
      fi
    else
      dbglg "$MKFS $MKFS_OPT \"$LOC_DEV\""
      dialog --backtitle "$BACKTITLE" \
        --infobox "$MSG_INSTALL_DEV_FORMATTING_WAIT_BEGIN '$LOC_DEV'$MSG_INSTALL_DEV_FORMATTING_WAIT_END" 0 0
      $MKFS $MKFS_OPT "$LOC_DEV" >> $LOGFILE 2>&1
    fi

  elif [ "$NEED_FORMAT" = yes ]; then
    dialog --aspect 15 --backtitle "$BACKTITLE" --title "$MSG_DISK_ERROR" \
      --msgbox "\n${MSG_INSTALL_DEV_NO_FORMAT} ('$LOC_DEV')\n" 0 0 1>&2
    rmdir $BOOTDISK_MNT
    exit 1
  fi

  dbglg "format_if_needed() returned \"$LOC_MKFS_TYPE\""
  # Update the global variable
  MKFS_TYPE="$LOC_MKFS_TYPE"
}

#FIXME: function's obsolete now
# Get the uuid of the device given by input $1
get_uuid () {
  local DEV_REALNAME NAME LOC_DEV LOC_UUID

  # restart UDEV scan to get device UUID if
  # user just created/formatted a new disk/partition
  udevadm trigger
  udevadm settle --timeout=180

  DEV_REALNAME=`echo ${1##/dev/}`
  for LOC_DEV in `ls /dev/disk/by-uuid/*`; do
    NAME=`ls -l "$LOC_DEV" | sed "s/.*-> \(.*\)/\1/" | sed 's%../../%%'`
    if [ "$NAME" = "$DEV_REALNAME" ]; then
      LOC_UUID="`echo $LOC_DEV | sed 's%/dev/disk/by-uuid/%%'`"
      dbglg "get_uuid() returned \"$LOC_UUID\""
      DEV_UUID="$LOC_UUID"
      break
    fi
  done
}

# Installs and configures the GRUB bootloader
# $1 is DEV
# $2 is MKFS_TYPE
install_grub (){
  local GRUBPREFIX=/boot/grub
  local GRUBDIR=$BOOTDISK_MNT/$GRUBPREFIX
  local SPLASHIMAGE="grub-splash.png"
  local LOC_DEV=$1
  local LOC_MKFS_TYPE=$2
  local ARCH=i386-pc

  TMP_DISK=`echo "$LOC_DEV" | sed -e 's%\([sh]d[a-z]\)[0-9]*$%\1%'`
  TMP_DISKNAME="${TMP_DISK#/dev/}"

  rm -rf $GRUBDIR
  mkdir -p $GRUBDIR

  [ -f "$BOOTDISK_MNT/usr/share/grub-i386-pc.tar.lzma" ] \
    && tar xaf "$BOOTDISK_MNT/usr/share/grub-i386-pc.tar.lzma" -C /usr \
    >> $LOGFILE 2>&1

#  [ -f "$BOOTDISK_MNT/usr/share/${SPLASHIMAGE}" ] && cp -f "$BOOTDISK_MNT/usr/share/${SPLASHIMAGE}" $GRUBDIR 

  DEV_UUID=$(grub-probe --target=fs_uuid $BOOTDISK_MNT)
  BOOT_DRV="(UUID=${DEV_UUID})"

  dbglg "boot drive: $BOOT_DRV"

  # Detect others OS and ask for MBR only in the case where OpenPCTV
  # is not installed on a removable device.
  # Note: lvm is not recognized as removable no matter what it's installed on!
  # should be possible to have lvm boot on removable device as well, but with less priority
  dialog --aspect 15 --backtitle "$BACKTITLE" --title "$MSG_BOOTLOADER" \
         --yesno "\n'$LOC_DEV' $MSG_LOADER_MULTIBOOT_BEGIN $supported_os_list\n${MSG_LOADER_MULTIBOOT_END}\n" 0 0 1>&2 \
         && MBR=yes

  sed /usr/share/installator/grub.cfg \
      -e "s/ID_FS_UUID/$DEV_UUID/" \
      -e "s/INSTALL_FSYS/$INSTALL_FSYS/" \
      -e "s/DISTRO/$DISTRO/" \
      -e "s/ARCH/$ARCH/" \
      -e "s/VERSION/$BUILD_DATE/" \
      -e "s/Start/$MSG_GRUB_START/" \
      -e "s/Default target/$MSG_GRUB_DEFAULT/" \
      -e "s/setup mode/$MSG_GRUB_SETUP/" \
      -e "s/debugging mode/$MSG_GRUB_DEBUG/" >> \
      $BOOTDISK_MNT/etc/grub.d/08_openpctv
  chmod 755 $BOOTDISK_MNT/etc/grub.d/08_openpctv

  if [ "$MBR" = "yes" ]; then
    grub-install --root-directory=$BOOTDISK_MNT $TMP_DISK
  else #try to install into partition
    grub-install --root-directory=$BOOTDISK_MNT $LOC_DEV
  fi
  cp -rf /usr/lib/grub/themes $BOOTDISK_MNT/boot/grub/
  cp -rf /usr/lib/grub/fonts $BOOTDISK_MNT/boot/grub/

  mount -t proc none $BOOTDISK_MNT/proc
  mount -t sysfs sys $BOOTDISK_MNT/sys
  mount -o bind /dev $BOOTDISK_MNT/dev

  dbglg "chroot $BOOTDISK_MNT /bin/bash -c \"grub-mkconfig -o /boot/grub/grub.cfg\""
  chroot $BOOTDISK_MNT /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
}

has_ssd_with_tirm() {
  [ -z "$1" -o ! -r $1 ] && return 2

  hdparm -I $1 | grep TRIM > /dev/null 2>&1
  RETVAL=$?

  return $RETVAL
}

DISTRO=OpenPCTV
INSTALL_FSYS=flat
BACKTITLE="OpenPCTV $VERSION installator"

# should not be present in install mode, but in case of ...
systemctl stop automountd >/dev/null 2>&1
killall -9 automountd >/dev/null 2>&1

for i in /media/*; do
  umount "$i" >/dev/null 2>&1
done

setup_lang

# disable kernel messages to avoid screen corruption
echo 0 > /proc/sys/kernel/printk

#setup_keymap

DISK="`choose_disk`"
[ -z "$DISK" ] && exit 1

# Make sure disk partitions are not already mounted in case it's no VG
if ( [ -x /usr/sbin/lvm ] && vgdisplay /dev/$DISK >/dev/null 2>&1 ); then
  umount /dev/$DISK/* 2>/dev/null
else
  umount /dev/${DISK}* 2>/dev/null
fi
for d in /media/*; do rmdir $d >/dev/null 2>&1; done

# Create directory for the install partition to be mounted
mkdir -p $BOOTDISK_MNT

CFDISK_MSG="$MSG_CFDISK_BEGIN $MSG_DISK_PART $MSG_CFDISK_END"

# Guide user on how to setup with cfdisk tool in the next step only if no VG was selected
if ( ! [ -x /usr/sbin/lvm ] || ! lvm vgdisplay /dev/$DISK >/dev/null 2>&1 ); then
  if dialog --stdout --defaultno --backtitle "$BACKTITLE" --title "$MSG_INSTALL_DEV_CONFIG" \
    --yesno "$CFDISK_MSG" 10 80; then
    cfdisk /dev/$DISK
  fi
fi

DEV="`choose_partition_dev $DISK`"
[ -z "$DEV" ] && exit 1

PARTID=`echo "$DEV" | sed "s#/dev/$DISK##"`

fdisk /dev/$DISK << _EOF
t
$PARTID
83
w
_EOF

MKFS_TYPE="`guess_partition_type $DEV`"

#format_if_needed "$MKFS_TYPE" "$DEV"
dbglg "mke2fs -L OPENPCTV -t ext4 \"$DEV\""
dialog --backtitle "$BACKTITLE" \
       --infobox "$MSG_INSTALL_DEV_FORMATTING_WAIT_BEGIN '$DEV'$MSG_INSTALL_DEV_FORMATTING_WAIT_END" 0 0
mke2fs -L OPENPCTV -t ext4 "$DEV" >> $LOGFILE 2>&1

# Attempt to mount the prepared partition using the given partition fs type
dbglg "mount $DEV $BOOTDISK_MNT"
mount "$DEV" $BOOTDISK_MNT
ret=$?
if [ $ret -ne 0 ]; then
  # FS is not mountable! Return an error msg and exit
  dbglg "mount returned $ret"
  dialog --aspect 15 --backtitle "$BACKTITLE" --title "$MSG_DISK_ERROR" \
    --msgbox "\n${MSG_INSTALL_MOUNT_FAILED} '$DEV' ($MKFS_TYPENAME).\n" 0 0
  rmdir $BOOTDISK_MNT
  exit 1
fi

dialog --backtitle "$BACKTITLE" --infobox "$MSG_INSTALLING_WAIT" 0 0

# Copying files
dbglg "cp -PR /.squashfs/* $BOOTDISK_MNT/"
cp -PR /.squashfs/* $BOOTDISK_MNT/ 2>&1 >> $LOGFILE

dbglg "UUID=${ID_FS_UUID} / ext4 relatime,errors=remount-ro 0 1"
blkid -o udev $DEV > /tmp/blkid
. /tmp/blkid
echo "proc /proc proc defaults 0 0" > $BOOTDISK_MNT/etc/fstab
echo "UUID=${ID_FS_UUID} / ext4 relatime,errors=remount-ro 0 1" >> $BOOTDISK_MNT/etc/fstab

# Installing the kernel
mkdir -p $BOOTDISK_MNT/boot >> $LOGFILE 2>&1
cp -P /.root/boot/vmlinuz $BOOTDISK_MNT/boot >> $LOGFILE 2>&1
cp -P /.root/boot/initrd $BOOTDISK_MNT/boot >> $LOGFILE 2>&1

# Add SSD batch discard if needed
has_ssd_with_tirm $DEV
INSTALL_SSD=$?
if [ "$INSTALL_SSD" = 0 ]; then
  echo "* */4 * * * fstrim /" >> $BOOTDISK_MNT/var/spool/cron/crontabs/root
fi

install_grub "$DEV" "$MKFS_TYPE"

# Softlink grub.cfg
rm -f $BOOTDISK_MNT/etc/grub/grub.cfg
ln -s /boot/grub/grub.cfg $BOOTDISK_MNT/etc/grub/grub.cfg

# Eject CD if it was the boot media
[ -n "$CDROM" ] && eject -s /dev/cdrom &

# Prompt to view logging file
dialog --aspect 15 --backtitle "$BACKTITLE" \
                             --title "$MSG_LOG" --defaultno \
                             --yesno "$MSG_LOG_DESC" 0 0 \
                             && dialog --textbox $LOGFILE 0 0

dialog --aspect 15 --backtitle "$BACKTITLE" --title "$MSG_SUCCESS" \
  --yesno "\n${MSG_SUCCESS_DESC_BEGIN} '$DEV' !! ${MSG_SUCCESS_DESC_END}\n" \
  0 0 \
  && reboot

# Cleanup
# umount $BOOTDISK_MNT && rmdir $BOOTDISK_MNT

# Exit cleanly
agetty tty1 &
return 0
