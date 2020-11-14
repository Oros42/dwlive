# mount lvm volume
vgscan
vgchange -ay ubuntu-vg
mount /dev/ubuntu-vg/ubuntu-lv /media/


# Run OS via nspawn with X11
mount /dev/sdb1 /media
startx -display :1 -- :1 vt3 &
xhost +local:
systemd-nspawn --boot --directory=/media --bind-ro=/tmp/.X11-unix -E DISPLAY=:1.0
# In container
export DISPLAY=:1
mate-session&
