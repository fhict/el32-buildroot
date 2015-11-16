#!/bin/sh
#
# Buildroot post-image script for Raspberry Pi (rpi)
#
# Author: e.dortmans@fontys.nl

IMAGESDIR=$1

echo "### CREATE IMAGE ###"

echo "Note: This script requires root (sudo) permission."

#
# Create image file
#
NAME=rpi.img
SIZE=256
UNIT=MB
IMAGE=${IMAGESDIR}/${NAME}
[ -f ${IMAGE} ] && echo "Deleting old image" && sudo rm ${IMAGE}
echo "Creating fresh image '${NAME}' of size ${SIZE}${UNIT}"
#dd if=/dev/zero of=${IMAGE} bs=1${UNIT} count=$SIZE 1>/dev/null 2>/dev/null
dd if=/dev/zero of=${IMAGE} bs=1 seek=${SIZE}${UNIT} count=0 1>/dev/null 2>/dev/null

#
# Partition it
#
BOOTFSTYPE=fat32
ROOTFSTYPE=ext4
BOOTSIZE=50
UNIT=MB
echo "Making partitions..."
BEGIN1=2048
END1=${BOOTSIZE}${UNIT}
BEGIN2=${END1}
END2=100%
sudo parted  ${IMAGE} mktable msdos 
sudo parted  -a opt ${IMAGE} unit s mkpart primary ${BOOTFSTYPE} ${BEGIN1} ${END1}
sudo parted  -a opt ${IMAGE} unit s mkpart primary ${ROOTFSTYPE} ${BEGIN2} ${END2}
sudo parted  ${IMAGE} set 1 boot on

#
# Map partitions to devices
#
LOOPDEVICE=`sudo losetup -f|sed -e 's|/dev/||'`
MAPPERDEVICE=/dev/mapper/${LOOPDEVICE}p
sudo kpartx -a -s ${IMAGE} #1>/dev/null 2>/dev/null

#
# Setup mountpoint
#
MOUNTPOINT=${IMAGESDIR}/mountpoint
sudo sync
[ -d "${MOUNTPOINT}" ] && sudo umount ${MOUNTPOINT}
[ ! -d "${MOUNTPOINT}" ] && sudo mkdir -p ${MOUNTPOINT}

#
# Format boot partition
#
LABEL=BOOT
FSTYPE=vfat
FSOPTIONS="-n ${LABEL}"
[ ${BOOTFSTYPE} = fat32 ] && FSOPTIONS="${FSOPTIONS} -F 32"
PARTITION=${MAPPERDEVICE}1
echo "Format ${LABEL} partition"
sudo mkfs -t ${FSTYPE} ${FSOPTIONS} ${PARTITION} 1>/dev/null 2>/dev/null
sudo parted -s ${IMAGE} set 1 lba on

#
# Mount boot partition
#
PARTITION=${MAPPERDEVICE}1
sudo mount ${PARTITION} ${MOUNTPOINT}

#
# Install firmware
#
FIRMWARE="${IMAGESDIR}/rpi-firmware"
echo "Install Firmware"
sudo cp ${FIRMWARE}/* ${MOUNTPOINT}

#
# Install kernel
#
KERNEL=${IMAGESDIR}/zImage
echo "Install Kernel"
sudo cp ${IMAGESDIR}/*.dtb ${MOUNTPOINT}
sudo ${IMAGESDIR}/../host/usr/bin/mkknlimg ${KERNEL} ${MOUNTPOINT}/zImage

#
# Unmount boot partition
#
sudo sync
sudo umount ${MOUNTPOINT}

#
# Format root partition
#
LABEL=ROOT
FSTYPE=${ROOTFSTYPE}
FSOPTIONS="-L ${LABEL}"
PARTITION=${MAPPERDEVICE}2
echo "Format ${LABEL} partition"
sudo mkfs -t ${FSTYPE} ${FSOPTIONS} ${PARTITION} 1>/dev/null 2>/dev/null

#
# Mount root partition
#
PARTITION=${MAPPERDEVICE}2
sudo mount ${PARTITION} ${MOUNTPOINT}

#
# Install rootfs
#
ROOTFS=${IMAGESDIR}/rootfs.tar
echo "Install Root FileSystem"
#sudo tar -xaf ${ROOTFS} -C ${MOUNTPOINT}
sudo tar xf ${ROOTFS} -C ${MOUNTPOINT}

#
# Unmount root partition
#
sudo sync
sudo umount ${MOUNTPOINT}

#
# Cleanup
#
echo "Cleanup"
sudo rm -rf ${MOUNTPOINT}
sudo kpartx -d ${IMAGE} 1>/dev/null 2>/dev/null
#
# Print info
#
echo "### IMAGE CREATED ###"
sudo parted ${IMAGE} print

