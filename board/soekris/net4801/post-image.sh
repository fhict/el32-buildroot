#!/bin/bash
#
# Buildroot post-image script for Soekris board
#
# Author: e.dortmans@fontys.nl

IMAGESDIR=$1

# Check if we're root and if we have access to sudo
if [[ $EUID -ne 0 ]]; then
  if ! [ -x "$(command -v sudo)" ]; then
      echo "Notice: This script requires root privileges but 'sudo' not found, executing it using 'su' (you'll be asked for root password)"
      exec su "root" "$0" "$@"
  else
    echo "Notice: This script requires root privileges, we'll use 'sudo' for that"
    SU="sudo"
  fi
else
  SU=""
fi

# Check if required additional software is installed
if ! [ -x "$(command -v parted)" ]; then
      echo "Error: This script requires 'parted' but it's not installed on your system!"
      exit 1
fi
if ! [ -x "$(command -v kpartx)" ]; then
      echo "Error: This script requires 'kpartx' but it's not installed on your system!"
      exit 1
fi

#
# Create CF image
#
NAME=soekris.img
SIZE=128
UNIT=M
IMAGE=$IMAGESDIR/$NAME
[ -f $IMAGE ] && echo "Deleting old image" && rm $IMAGE
echo "Creating fresh image file '$NAME' of size $SIZE$UNIT"
#dd if=/dev/zero of=$IMAGE bs=1$UNIT count=$SIZE 2>/dev/null
dd if=/dev/zero of=$IMAGE bs=1 seek=$SIZE$UNIT count=0

#
# Partition it
#
FSTYPE=ext4
BEGIN=2048
END=100%
echo "Partition it"
$SU parted $IMAGE mktable msdos
$SU parted -a opt $IMAGE unit s mkpart primary $FSTYPE $BEGIN $END
$SU parted $IMAGE set 1 boot on
#parted $IMAGE unit s print

#
# Format root partition
# Assume kpartx is installed. If not: sudo apt-get install kpartx
#
PART=1
LABEL=ROOT
LOOPDEVICE=`$SU losetup -f --show $IMAGE|sed -e 's|/dev/||'`
MAPPERDEVICE="/dev/mapper/${LOOPDEVICE}p${PART}"
echo "Format partition"
$SU kpartx -a /dev/${LOOPDEVICE}
sleep 1
$SU mkfs -v -t $FSTYPE -L $LABEL $MAPPERDEVICE
# tune2fs .....

#
# Install rootfs
#
ROOTFS=$IMAGESDIR/rootfs.tar
MOUNTPOINT=/mnt/rootfs
echo "Install Root Filesystem"
[ -e $MOUNTPOINT ] && $SU chattr -Ri $MOUNTPOINT && $SU rm -rf $MOUNTPOINT
# http://www.linuxquestions.org/questions/linux-server-73/cannot-remove-file-operation-not-permitted-836139/
$SU mkdir $MOUNTPOINT
$SU mount -t $FSTYPE $MAPPERDEVICE $MOUNTPOINT
$SU tar -xaf $ROOTFS -C $MOUNTPOINT

#
# Install bootloader
# http://shallowsky.com/linux/extlinux.html
# Assume extlinux is installed. If not: sudo apt-get install extlinux
#
echo "Install Bootloader"
#MBR_BIN=$(find /usr/lib -name "mbr.bin")
MBR_BIN=/usr/lib/EXTLINUX/mbr.bin
$SU extlinux --install $MOUNTPOINT/boot/extlinux
dd conv=notrunc bs=440 count=1 if=${MBR_BIN} of=$IMAGE

#
# Cleanup
#
echo "Cleanup"
$SU umount $MOUNTPOINT
$SU rm -rf $MOUNTPOINT
$SU kpartx -d $IMAGE

echo "DONE."

