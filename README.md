# dwlive
Make a live CD Debian with dwagent (https://www.dwservice.net/)

## Make dwlive

### Install
```
sudo apt install debootstrap xorriso live-build syslinux mksquashfs
```
### Make
```
sudo ./make_iso.sh
```
If no error, you should get dwlive-debian-amd64.iso.  
Now, you can copy the iso on a usb stick.  

## User dwlive

«IT support» = the person helping  
«client» = the person who needs help  

### IT support (person who helping)
Sign up on https://www.dwservice.net/  
Go to Agents. Add new Agent.  
Send the code (like 123-456-789) and the dwlive's iso to your client  
Wait your client enter the code.  
Afer that, you have access to his computer.

#### Tips
If you whant to fix de Gnu/Linux, you can run it with display.  
This is how to do.  
Mount the OS partition :  
```
mount /dev/sda1 /media/ # change sda1 to your conf
```
or for lvm  
```
vgscan
vgchange -ay ubuntu-vg # change ubuntu-vg to your conf
mount /dev/ubuntu-vg/ubuntu-lv /media/
```
Start X server :  
```
./1_startx.sh
```
Now on https://www.dwservice.net/, you can select a screen.  
Go to the screen tab, and  
```
2_run_os.sh
```
After login, you can do :  
```
export DISPLAY=:1
mate-session& # or cinamon-session or kde-session or...
```

### Client (person who needs help)
Copy dwlive on a usb stick.  
Boot the computer on the usb stick.  
Valide questions about the key board. If you didn't know the answer, just press enter.  
At the question «Please choose an operation», select 1.  
Then enter the code given by your IT support (like 123-456-789).  

