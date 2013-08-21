#!/bin/bash

set -e
TARGET=""
MBR=""

# Find out which partition or disk are we using
MYMNT=$(cd -P $(dirname $0) ; pwd)
while [ "$MYMNT" != "" -a "$MYMNT" != "." -a "$MYMNT" != "/" ]; do
   #TARGET=$(egrep "[^[:space:]]+[[:space:]]+$MYMNT[[:space:]]+" /proc/mounts | cut -d " " -f 1)
   TARGET=$(mount | egrep "[^[:space:]]+[[:space:]]+$MYMNT[[:space:]]+" | cut -d " " -f 1)
   if [ "$TARGET" != "" ]; then break; fi
   MYMNT=$(dirname "$MYMNT")
done

if [ "$TARGET" = "" ]; then
   echo "Can't find device to install to."
   echo "Make sure you run this script from a mounted device."
   exit 1
fi

MBR=$(echo "$TARGET" | sed -r "s/[0-9]+\$//g")
NUM=${TARGET:${#MBR}}
cd "$MYMNT"

clear
echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
echo "                        Welcome to OPENPCTV boot installer                         "
echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
echo
echo "This installer will setup disk $TARGET to boot only OPENPCTV."
if [ "$MBR" != "$TARGET" ]; then
   echo
   echo "Warning! Master boot record (MBR) of $MBR will be overwritten."
   echo "If you use $MBR to boot any existing operating system, it will not work"
   echo "anymore. Only OPENPCTV will boot from this device. Be careful!"
fi
echo
echo "Press any key to continue, or Ctrl+C to abort..."
read junk
clear

echo "Flushing filesystem buffers, this may take a while..."
cp ./boot/syslinux/syslinux /tmp
chmod 755 /tmp/syslinux
sync

# setup MBR if the device is not in superfloppy format
if [ "$MBR" != "$TARGET" ]; then
   echo "Updating MBR on $MBR..." # this must be here because LILO mbr is bad. mbr.bin is from syslinux
   cat ./boot/syslinux/mbr.bin > $MBR
fi

echo "Setting up boot record for $TARGET..."
/tmp/syslinux -d boot/syslinux $TARGET

echo "Disk $TARGET should be bootable now. Installation finished."
rm /tmp/syslinux

echo
echo "Read the information above and then press any key to exit..."
read junk
