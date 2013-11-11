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
# Install firmware
#
FIRMWARE="${IMAGESDIR}/rpi-firmware"
PARTITION=${MAPPERDEVICE}1
echo "Install Firmware"
sudo mount ${PARTITION} ${MOUNTPOINT}
#sudo cp ${FIRMWARE}/* ${MOUNTPOINT}
sudo cp ${FIRMWARE}/bootcode.bin ${MOUNTPOINT}
sudo cp ${FIRMWARE}/start.elf ${MOUNTPOINT}
sudo cp ${FIRMWARE}/fixup.dat ${MOUNTPOINT}
echo 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait' > ${FIRMWARE}/cmdline.txt
sudo cp ${FIRMWARE}/cmdline.txt ${MOUNTPOINT}
cat > ${FIRMWARE}/config.txt << EOF
# uncomment if you get no picture on HDMI for a default "safe" mode
#hdmi_safe=1

# uncomment this if your display has a black border of unused pixels visible
# and your display can output without overscan
#disable_overscan=1

# uncomment the following to adjust overscan. Use positive numbers if console
# goes off screen, and negative if there is too much border
#overscan_left=16
#overscan_right=16
#overscan_top=16
#overscan_bottom=16

# uncomment to force a console size. By default it will be display's size minus
# overscan.
#framebuffer_width=1280
#framebuffer_height=720

# uncomment if hdmi display is not detected and composite is being output
#hdmi_force_hotplug=1

# uncomment to force a specific HDMI mode (this will force VGA)
#hdmi_group=1
#hdmi_mode=1

# uncomment to force a HDMI mode rather than DVI. This can make audio work in
# DMT (computer monitor) modes
#hdmi_drive=2

# uncomment to increase signal to HDMI, if you have interference, blanking, or
# no display
#config_hdmi_boost=4

# uncomment for composite PAL
#sdtv_mode=2

#uncomment to overclock the arm. 700 MHz is the default.
#arm_freq=800

# for more options see http://elinux.org/RPi_config.txt
EOF
sudo cp ${FIRMWARE}/config.txt ${MOUNTPOINT}
sudo sync
sudo umount ${MOUNTPOINT}

#
# Install kernel
#
KERNEL=${IMAGESDIR}/zImage
PARTITION=${MAPPERDEVICE}1
echo "Install Kernel"
sudo mount ${PARTITION} ${MOUNTPOINT}
sudo cp ${KERNEL} ${MOUNTPOINT}/kernel.img
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
# Install rootfs
#
ROOTFS=${IMAGESDIR}/rootfs.tar
PARTITION=${MAPPERDEVICE}2
echo "Install Root FileSystem"
sudo mount ${PARTITION} ${MOUNTPOINT}
sudo tar -xaf ${ROOTFS} -C ${MOUNTPOINT}
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

