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
userName=${1:-"centos"}
passWord=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c10;echo`

printf "RDP installing... \n" >&2
date "+【%Y-%m-%d %H:%M:%S】 Generate User ${userName}:${passWord}" 2>&1 | tee -a $logPath
{
sudo yum update -y
sudo useradd -s /bin/bash -m $userName
echo "${userName}:${passWord}" | sudo chpasswd
echo "${userName}  ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/${userName}"

date "+【%Y-%m-%d %H:%M:%S】 Install ${userName} DeskTop System." 2>&1 | tee -a $logPath
sudo yum -y update
sudo yum -y upgrade		
sudo yum install -y epel-release
sudo yum groupinstall "X window system" -y		
yum --enablerepo=epel group -y install "Xfce" "base-x"		
echo "xfce4-session" > /home/"${userName}"/.Xclients
chmod a+x /home/"${userName}"/.Xclients	
sudo systemctl set-default graphical.target
sudo yum install -y firefox
sudo yum install wqy* cjkuni* -y
systemctl start xrdp

date "+【%Y-%m-%d %H:%M:%S】 Install Software." 2>&1 | tee -a $logPath
sudo su - $userName -c "wget -O ~/google-chrome-stable_current_x86_64.rpm https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
sudo su - $userName -c "sudo yum install ~/google-chrome-stable_current_x86_64.rpm"
} &> /dev/null && 
date "+【%Y-%m-%d %H:%M:%S】 Setup Completed." 2>&1; printf "Your ${userName} Pasword Is ${passWord} \n";>&2 || 
printf "\nError Occured " >&2


echo "Press any key to continue Reboot!"
char=`get_char`
sudo reboot
