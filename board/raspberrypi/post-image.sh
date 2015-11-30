#!/bin/bash
#
# Buildroot post-image script for Raspberry Pi (rpi)
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

echo "### CREATE IMAGE ###"

#
# Create image file
#
NAME=rpi.img
SIZE=256
UNIT=MB
IMAGE=${IMAGESDIR}/${NAME}
[ -f ${IMAGE} ] && echo "Deleting old image" && $SU rm ${IMAGE}
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
$SU parted  ${IMAGE} mktable msdos 
$SU parted  -a opt ${IMAGE} unit s mkpart primary ${BOOTFSTYPE} ${BEGIN1} ${END1}
$SU parted  -a opt ${IMAGE} unit s mkpart primary ${ROOTFSTYPE} ${BEGIN2} ${END2}
$SU parted  ${IMAGE} set 1 boot on

#
# Map partitions to devices
#
LOOPDEVICE=`$SU losetup -f|sed -e 's|/dev/||'`
MAPPERDEVICE=/dev/mapper/${LOOPDEVICE}p
$SU kpartx -a -s ${IMAGE} #1>/dev/null 2>/dev/null

#
# Setup mountpoint
#
MOUNTPOINT=${IMAGESDIR}/mountpoint
$SU sync
[ -d "${MOUNTPOINT}" ] && $SU umount ${MOUNTPOINT}
[ ! -d "${MOUNTPOINT}" ] && $SU mkdir -p ${MOUNTPOINT}

#
# Format boot partition
#
LABEL=BOOT
FSTYPE=vfat
FSOPTIONS="-n ${LABEL}"
[ ${BOOTFSTYPE} = fat32 ] && FSOPTIONS="${FSOPTIONS} -F 32"
PARTITION=${MAPPERDEVICE}1
echo "Format ${LABEL} partition"
$SU mkfs -t ${FSTYPE} ${FSOPTIONS} ${PARTITION} 1>/dev/null 2>/dev/null
$SU parted -s ${IMAGE} set 1 lba on

#
# Mount boot partition
#
PARTITION=${MAPPERDEVICE}1
$SU mount ${PARTITION} ${MOUNTPOINT}

#
# Install firmware
#
FIRMWARE="${IMAGESDIR}/rpi-firmware"
echo "Install Firmware"
$SU cp ${FIRMWARE}/* ${MOUNTPOINT}

#
# Install kernel
#
KERNEL=${IMAGESDIR}/zImage
echo "Install Kernel"
$SU cp ${IMAGESDIR}/*.dtb ${MOUNTPOINT}
$SU ${IMAGESDIR}/../host/usr/bin/mkknlimg ${KERNEL} ${MOUNTPOINT}/zImage

#
# Unmount boot partition
#
$SU sync
$SU umount ${MOUNTPOINT}

#
# Format root partition
#
LABEL=ROOT
FSTYPE=${ROOTFSTYPE}
FSOPTIONS="-L ${LABEL}"
PARTITION=${MAPPERDEVICE}2
echo "Format ${LABEL} partition"
$SU mkfs -t ${FSTYPE} ${FSOPTIONS} ${PARTITION} 1>/dev/null 2>/dev/null

#
# Mount root partition
#
PARTITION=${MAPPERDEVICE}2
$SU mount ${PARTITION} ${MOUNTPOINT}

#
# Install rootfs
#
ROOTFS=${IMAGESDIR}/rootfs.tar
echo "Install Root FileSystem"
#$SU tar -xaf ${ROOTFS} -C ${MOUNTPOINT}
$SU tar xf ${ROOTFS} -C ${MOUNTPOINT}

#
# Unmount root partition
#
$SU sync
$SU umount ${MOUNTPOINT}

#
# Cleanup
#
echo "Cleanup"
$SU rm -rf ${MOUNTPOINT}
$SU kpartx -d ${IMAGE} 1>/dev/null 2>/dev/null
#
# Print info
#
echo "### IMAGE CREATED ###"
$SU parted ${IMAGE} print

