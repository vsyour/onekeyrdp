#!/bin/bash
#
# Configure And Start RDP FOR CentOS/Ubuntu/Debian.
#
# Copyright © 2015-2099 vksec <QQ Group: 397745473>
#
# Reference URL:
# https://www.vksec.com


get_char()
{
SAVEDSTTY=`stty -g`
stty -echo
stty cbreak
dd if=/dev/tty bs=1 count=1 2> /dev/null
stty -raw
stty echo
stty $SAVEDSTTY
}

echo "
+----------------------------------------------------------------------
| Configure And Start RDP FOR CentOS/Ubuntu/Debian
+----------------------------------------------------------------------
| Copyright © 2015-2099 vksec (https://www.vksec.com) All rights reserved.
+----------------------------------------------------------------------
| The Can Use will systemctl status bee when installed.
+----------------------------------------------------------------------
";printf "Check Out My Channel While Waiting- https://github.com/vsyour/onekeyrdp \n\n" >&2;sleep 5
logPath='./oneKeyRdp.log'
userName=$1
passWord=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c10;echo`

printf "RDP installing... \n" >&2
date "+【%Y-%m-%d %H:%M:%S】 Generate User ${userName}:${passWord}" 2>&1 | tee -a $logPath
{
sudo apt-get update -y
sudo useradd -s /bin/bash -m $userName
echo "${userName}:${passWord}" | sudo chpasswd
echo "${userName}  ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/${userName}"

date "+【%Y-%m-%d %H:%M:%S】 Install ${userName} DeskTop System." 2>&1 | tee -a $logPath
sudo su - $userName -c "sudo DEBIAN_FRONTEND=noninteractive apt install xfce4 desktop-base lxterminal mousepad -y < /dev/null > /dev/null"
sudo su - $userName -c "sudo systemctl disable lightdm.service"

date "+【%Y-%m-%d %H:%M:%S】 Install xrdp." 2>&1 | tee -a $logPath
sudo su - $userName -c "sudo apt install xrdp -y"
sudo su - $userName -c "sudo systemctl enable xrdp"
sudo su - $userName -c "sudo /etc/init.d/xrdp restart"
sudo su - $userName -c "sudo apt install --assume-yes --fix-broken"

date "+【%Y-%m-%d %H:%M:%S】 Install Software." 2>&1 | tee -a $logPath
sudo su - $userName -c "wget -O ~/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
sudo su - $userName -c "sudo dpkg --install ~/google-chrome-stable_current_amd64.deb"
sudo su - $userName -c "sudo apt install --assume-yes --fix-broken"
sudo su - $userName -c "sudo apt install nautilus nano -y"
sudo su - $userName -c "sudo apt install locales ttf-wqy-zenhei ttf-wqy-microhei -y"
sudo apt update -y
} &> /dev/null && 
date "+【%Y-%m-%d %H:%M:%S】 Setup Completed." 2>&1; printf "Your ${userName} Pasword Is ${passWord} \n";>&2 || 
printf "\nError Occured " >&2


echo "Press any key to continue Reboot!"
char=`get_char`
sudo reboot
