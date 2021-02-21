#!/bin/bash
# author : Oros
# 2021-02-21
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


function help()
{
	readonly PROGNAME=$(basename $0)
	cat <<- EOF
		$0 [-h] [-k]
		Make a live CD Debian with dwagent (https://www.dwservice.net/)

		Options
		-h : This help
		-k : Keep files in iso, tmp and chroot.
		     Use to only rebuid the ISO.
	EOF
	exit
}

keepFiles=0

eval set -- $(getopt -l keep-files -o kh -- "$@")

while true
do
	name="$1"
	shift
	case $name in
		-k|--keep-files)
			keepFiles=1
			;;
		-h|--help)
			help
			;;
		--)
			break
			;;
		*)
			echo "Illegal option: $name"
			exit 1
			;;
	esac
done

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
mkdir -p "$livework"
cd "$livework"

if [ ! -f "${chroot_files}/root/dwagent_x86.sh" ]; then
	wget -c https://www.dwservice.net/download/dwagent_x86.sh -O "${chroot_files}/root/dwagent_x86.sh"
	chmod +x "${chroot_files}/root/dwagent_x86.sh"
fi

#http://ftp.debian.org/debian/ -> http://ftp.debian.org/debian
repositories="$(echo $repositories| sed 's|/$||')"
repositoriesProxy="$(echo $repositoriesProxy| sed 's|/$||')"

if [ "$keepFiles" -eq "0" ]; then
	rm -fr iso
	rm -fr tmp
	rm -fr chroot

	# build OS
	if [ "$repositoriesProxy" != "" ]; then
		echo "Use proxy $repositoriesProxy"
		repo="${repositoriesProxy}/$(echo $repositories | sed 's|.*://||')"
		# repositories="http://ftp.debian.org/debian"
		# repositoriesProxy="http://myproxy.lan:3142"
		# repo="http://myproxy.lan:3142/ftp.fr.debian.org/debian"
		debootstrap --arch=amd64 $os_version chroot $repo
	else
		debootstrap --arch=amd64 $os_version chroot $repositories
	fi
	# configure the OS
	cp -r "$chroot_files"/* chroot/
	chmod +x chroot/install_in_chroot.sh
	echo "${dist_name}" > chroot/etc/hostname
	dbus-uuidgen > chroot/etc/machine-id

	chroot chroot /install_in_chroot.sh

	# clean tmp files
	rm -r chroot/install_in_chroot.sh
	rm -rf chroot/tmp/*
	rm -f chroot/root/.keyboard_ok
	rm -rf chroot/root/.bash_history
	if [ "$repositoriesProxy" != "" ]; then
		sed -i "s|$repo|$repositories|" chroot/etc/apt/sources.list
	fi
fi

mkdir -p {iso/{EFI/boot,boot/grub/x86_64-efi,isolinux,live},tmp}

# make filesystem.squashfs
if [ -f iso/live/filesystem.squashfs ]; then
	rm iso/live/filesystem.squashfs
fi
mksquashfs chroot iso/live/filesystem.squashfs -e boot


# custom files
cp -r $iso_files/iso/* iso/

touch iso/DWLIVE_DEBIAN
cp chroot/boot/vmlinuz*amd64 iso/live/vmlinuz
cp chroot/boot/initrd.img-*amd64 iso/live/initrd
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
    -eltorito-boot isolinux/isolinux.bin \
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
