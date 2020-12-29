#!/bin/bash
# author : Oros
# 2020-12-29
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

home_project=$(pwd)
chroot_files="$home_project/chroot_files"
iso_files="$home_project/iso_files"
mkdir -p "$livework"
cd "$livework"

rm -fr chroot
rm -fr iso
rm -fr tmp

# build OS
debootstrap --arch=amd64 $os_version chroot $repositories

# configure the OS
cp -r "$chroot_files"/* chroot/
chmod +x chroot/install_in_chroot.sh
echo "${dist_name}" > chroot/etc/hostname
dbus-uuidgen > chroot/etc/machine-id

chroot chroot /install_in_chroot.sh

# clean tmp files
rm -r chroot/install_in_chroot.sh
rm -r chroot/tmp/*
rm -f chroot/root/.keyboard_ok
rm -rf chroot/root/.bash_history

mkdir -p {iso/{EFI/boot,boot/grub/x86_64-efi,isolinux,live},tmp}

# make filesystem.squashfs
mksquashfs chroot iso/live/filesystem.squashfs -e boot


touch iso/DWLIVE_DEBIAN
cp chroot/boot/vmlinuz*amd64 iso/live/vmlinuz
cp chroot/boot/initrd.img-*amd64 iso/live/initrd
cp -r $iso_files/iso/* iso/
cp /usr/lib/ISOLINUX/isolinux.bin iso/isolinux/
cp /usr/lib/syslinux/modules/bios/* iso/isolinux/
cp -r /usr/lib/grub/x86_64-efi/* iso/boot/grub/x86_64-efi/


grub-mkstandalone \
    --format=x86_64-efi \
    --output=tmp/bootx64.efi \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=${iso_files}/grub-standalone.cfg"

cd iso/EFI/boot
dd if=/dev/zero of=efiboot.img bs=1M count=20
mkfs.vfat efiboot.img
mmd -i efiboot.img efi efi/boot
mcopy -vi efiboot.img $livework/tmp/bootx64.efi ::efi/boot/

cd $livework

# build ISO
if [ -f "${home_project}/${iso_name}" ]; then rm "${home_project}/${iso_name}"; fi
xorriso \
    -as mkisofs \
    -iso-level 3 \
    -o "${home_project}/${iso_name}" \
    -full-iso9660-filenames \
    -volid "DWLIVE_DEBIAN" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-boot \
        isolinux/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog isolinux/isolinux.cat \
    -eltorito-alt-boot \
        -e /EFI/boot/efiboot.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
    -append_partition 2 0xef ${livework}/iso/EFI/boot/efiboot.img \
    "${livework}/iso"

echo "ISO build in ${home_project}/${iso_name}"
sudo chown $USER: "${home_project}/${iso_name}"
