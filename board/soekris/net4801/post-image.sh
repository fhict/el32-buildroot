#!/bin/sh
#
# Buildroot post-image script for Soekris board
#
# Author: e.dortmans@fontys.nl

IMAGESDIR=$1

echo "This script requires root (sudo) permission."

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
dd if=/dev/zero of=$IMAGE bs=1 seek=$SIZE$UNIT count=0 2>/dev/null

#
# Partition it
#
FSTYPE=ext4
BEGIN=2048
END=100%
echo "Partition it"
sudo parted $IMAGE mktable msdos
sudo parted -a opt $IMAGE unit s mkpart primary $FSTYPE $BEGIN $END
sudo parted $IMAGE set 1 boot on
#parted $IMAGE unit s print

#
# Format root partition
# Assume kpartx is installed. If not: sudo apt-get install kpartx
#
PART=1
LABEL=ROOT
LOOPDEVICE=`sudo losetup -f|sed -e 's|/dev/||'`
MAPPERDEVICE=/dev/mapper/${LOOPDEVICE}p${PART}
echo "Format partition"
sudo kpartx -a $IMAGE 1>/dev/null 2>/dev/null
sudo mkfs -v -t $FSTYPE -L $LABEL $MAPPERDEVICE 1>/dev/null 2>/dev/null
# tune2fs .....

#
# Install rootfs
#
ROOTFS=$IMAGESDIR/rootfs.tar
MOUNTPOINT=/mnt/rootfs
echo "Install Root Filesystem"
[ -e $MOUNTPOINT ] && sudo chattr -Ri $MOUNTPOINT && sudo rm -rf $MOUNTPOINT
# http://www.linuxquestions.org/questions/linux-server-73/cannot-remove-file-operation-not-permitted-836139/
sudo mkdir $MOUNTPOINT
sudo mount -t $FSTYPE $MAPPERDEVICE $MOUNTPOINT
sudo tar -xaf $ROOTFS -C $MOUNTPOINT

#
# Install bootloader
# http://shallowsky.com/linux/extlinux.html
# Assume extlinux is installed. If not: sudo apt-get install extlinux
#
echo "Install Bootloader"
sudo extlinux --install $MOUNTPOINT/boot/extlinux 1>/dev/null 2>/dev/null
dd conv=notrunc bs=440 count=1 if=/usr/lib/extlinux/mbr.bin of=$IMAGE 1>/dev/null 2>/dev/null

#
# Cleanup
#
echo "Cleanup"
sudo umount $MOUNTPOINT
sudo rm -rf $MOUNTPOINT
sudo kpartx -d $IMAGE 1>/dev/null 2>/dev/null

echo "DONE."

