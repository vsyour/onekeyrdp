#!/bin/bash
#
# Configure And Start RDP FOR CentOS/Ubuntu/Debian.
#
# Copyright © 2015-2099 vksec <QQ Group: 397745473>
#
# Reference URL:
# https://www.vksec.com

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
userName='debian'
passWord=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c10;echo`
date "+【%Y-%m-%d %H:%M:%S】 Generate User ${userName}:${passWord}" 2>&1 | tee -a $logPath


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


__Auto_Swap(){
    swap=$(free |grep Swap|awk '{print $2}')
	if [ "${swap}" -gt 1 ];then
	    echo "Swap total sizse: $swap";
		return;
    fi
	
	swapFile="/var/swapfile"
	dd if=/dev/zero of=$swapFile bs=1M count=1025
	mkswap -f $swapFile
	swapon $swapFile
	echo "$swapFile    swap    swap    defaults    0 0" >> /etc/fstab
	
	swap=`free |grep Swap|awk '{print $2}'`
	if [ $swap -gt 1 ];then
	    echo "Swap total sizse: $swap";
		return;
	fi
	
	sed -i "/\/var\/swapfile/d" /etc/fstab
	rm -f $swapFile
}

__initSystem(){
	PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
	export PATH
	LANG=en_US.UTF-8
	cd ~
	
	red='\e[91m'
	green='\e[92m'
	yellow='\e[93m'
	magenta='\e[95m'
	cyan='\e[96m'
	none='\e[0m'
	_red() { echo -e ${red}$*${none}; }
	_green() { echo -e ${green}$*${none}; }
	_yellow() { echo -e ${yellow}$*${none}; }
	_magenta() { echo -e ${magenta}$*${none}; }
	_cyan() { echo -e ${cyan}$*${none}; }
	
	# Root
	[[ $(id -u) != 0 ]] && echo -e "\n You must be ${red}root ${none}to run this script ( Enter: sudo su) ${yellow}~(^_^) ${none}\n" && exit 1

	PM="apt-get install --assume-yes"
	DEBIAN_FRONTEND=noninteractive	
	sys_bit=$(uname -m)

	# check os
	if [[ $(command -v apt-get) || $(command -v yum) ]] && [[ $(command -v systemctl) ]]; then
		if [[ $(command -v yum) ]]; then
			PM="yum install"			
		fi
	else
		echo -e " 
		LoL ... This ${red}junk script${none} does not support your system.。 ${yellow}(-_-) ${none}

		Note: Only support Ubuntu 16+ / Debian 8+ / CentOS 7+ system
		" && exit 1
	fi
}

__addUser(){
	grep "${userName}" /etc/passwd || sudo useradd -m "${userName}" && echo "${userName}  ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/${userName}" && echo "${userName}:${passWord}" | sudo chpasswd && sed -i "/${userName}:x:1000:1000::\/home\/${userName}:\/bin\/sh/d" /etc/passwd && echo "${userName}:x:1000:1000::/home/${userName}:/bin/bash" >> /etc/passwd
}

__update(){
	if [[ ${PM} == "yum install" ]]; then
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
	else
	    sudo apt-get -y update
		sudo apt-get -y upgrade
	fi
	
}

__installDesktop(){
	sudo $PM --fix-broken
	sudo $PM xfce4 desktop-base xrdp lxterminal mousepad -y
	sudo $PM xscreensaver -y
	sudo systemctl disable lightdm.service
	sudo systemctl enable xrdp
	sudo /etc/init.d/xrdp restart
}

__installSoftware(){
	sudo $PM firefox-esr
	sudo $PM firefox
	sudo $PM locales ttf-wqy-zenhei ttf-wqy-microhei
	sudo $PM nautilus nano -y
}

__Auto_Swap
__initSystem
__addUser
__update
__installDesktop
__installSoftware

printf "Your ${userName} Pasword Is ${passWord} \n"
echo "Press any key to continue Reboot!"
char=`get_char`
reboot



