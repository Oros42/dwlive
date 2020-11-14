#!/bin/bash
mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C
export PS1="\e[01;31m(live):\W \$ \e[00m"

finish() {
    echo "exit chroot"
    apt-get clean
    umount /proc /sys /dev/pts
    exit
}
trap finish EXIT
trap finish SIGINT

set -euo pipefail

apt update
apt upgrade -y
apt install -y --no-install-recommends linux-image-amd64 live-boot systemd-sysv
sed -i "s|KEYMAP=n|KEYMAP=y|" /etc/initramfs-tools/initramfs.conf
update-initramfs -u


# auto login as root
sed -i "s|#NAutoVTs=6|NAutoVTs=1|" /etc/systemd/logind.conf
mkdir -p /etc/systemd/system/getty@tty1.service.d
echo "[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux
" > /etc/systemd/system/getty@tty1.service.d/override.conf
systemctl enable getty@tty1.service

apt install -y wget systemd-container xterm expect console-setup keyboard-configuration lvm2 htop xinit x11-xserver-utils cryptsetup

echo "
if [ ! -f ~/.setup_ok ]; then
touch ~/.setup_ok
dpkg-reconfigure keyboard-configuration
setupcon
clear
echo 'Configure DWAgent (ctrl+c to exit)'
dwagconfigure
fi" >> /root/.profile
echo "
alias ll='ls -l'
if [ \"$DISPLAY\" != '' ]; then xhost +local:; fi" >> /root/.bashrc

cd /tmp/
wget https://www.dwservice.net/download/dwagent_x86.sh
chmod +x dwagent_x86.sh

set +e
#FIXME not realy good but didn't find better
{ echo -e "1\r"; sleep 2; echo -e "\r"; sleep 1; echo -e "1\r";  sleep 20; killall dwagent;} | ./dwagent_x86.sh
set -e

