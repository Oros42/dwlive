#!/bin/bash
# author : Oros
# 2020-11-07
#
# This script create a light Debian ISO which include dwagent (https://www.dwservice.net/)

set -euo pipefail

if [ ! -f config ]; then
	if [ -f config.dist ]; then
		cp config.dist config
	else
		echo "$0: ${1:-"config file not found"}" 1>&2
		exit 1
	fi
fi
. ./config


if [ "$EUID" -ne 0 ]; then 
	echo -e "\033[31mPlease run as root\033[0m" 1>&2
	exit 1
fi

if [ ! `which debootstrap` ]; then
	apt-get install -y debootstrap
fi
if [ ! `which xorriso` ]; then
	apt-get install -y xorriso
fi
if [ ! `which live-build` ]; then
	apt-get install -y live-build
fi
if [ ! `which syslinux` ]; then
	apt-get install -y syslinux
fi
if [ ! `which mksquashfs` ]; then
	apt-get install -y squashfs-tools
fi

home_project=$(pwd)
chroot_files="$home_project/chroot_files"
iso_files="$home_project/iso_files"
mkdir -p $livework
cd $livework

# build OS
rm -fr chroot
debootstrap --arch=amd64 $os_version chroot $repositories

# configure the OS
cp -r $chroot_files/* chroot/
chmod +x chroot/install_in_chroot.sh
echo "${dist_name}" > chroot/etc/hostname

chroot chroot /install_in_chroot.sh

# clean tmp files
rm -r chroot/install_in_chroot.sh
rm -r chroot/tmp/*
rm -f chroot/root/.keyboard_ok

# make filesystem.squashfs
mkdir -p binary/{live,isolinux}
cp $(ls chroot/boot/vmlinuz* |sort --version-sort -f|tail -n1) binary/live/vmlinuz
cp $(ls chroot/boot/initrd* |sort --version-sort -f|tail -n1) binary/live/initrd
if [ -f binary/live/filesystem.squashfs ]; then rm binary/live/filesystem.squashfs; fi
mksquashfs chroot binary/live/filesystem.squashfs -comp xz

# copy boot files
isohdpfx_path=/usr/lib/syslinux/isohdpfx.bin
if [ -f /usr/lib/syslinux/isolinux.bin ]; then
	cp /usr/lib/syslinux/isolinux.bin binary/isolinux/
elif [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
	cp /usr/lib/ISOLINUX/isolinux.bin binary/isolinux/
	isohdpfx_path=/usr/lib/ISOLINUX/isohdpfx.bin
fi

if [ ! -f $isohdpfx_path ]; then
	echo -e "\033[31m${isohdpfx_path} not found!\033[0m" 1>&2
	exit 1
fi

if [ -d /usr/lib/syslinux/modules/bios/ ]; then
	cp /usr/lib/syslinux/modules/bios/{ldlinux.c32,libcom32.c32,libutil.c32,vesamenu.c32} binary/isolinux/
else
	echo -e "\033[31m/usr/lib/syslinux/modules/bios/ not found!\033[0m" 1>&2
	exit 1
fi

cp $iso_files/{splash.png,isolinux.cfg} binary/isolinux/

# make iso
if [ -f "${iso_name}" ]; then rm "${iso_name}"; fi
xorriso -as mkisofs -r -J -joliet-long -l -cache-inodes -isohybrid-mbr $isohdpfx_path -partition_offset 16 -A "${dist_name}"  -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o "${home_project}/${iso_name}" binary

echo "ISO build in ${home_project}/${iso_name}"

