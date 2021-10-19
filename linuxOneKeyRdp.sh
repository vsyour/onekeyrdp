#!/bin/bash
#
# Configure And Start RDP FOR CentOS/Ubuntu/Debian.
#
# Copyright © 2015-2099 vksec <QQ Group: 397745473>
#
# Reference URL:
# https://www.vksec.com


RED="\033[31m"      # Error message
GREEN="\033[32m"    # Success message
YELLOW="\033[33m"   # Warning message
BLUE="\033[36m"     # Info message
PLAIN='\033[0m'


function colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

function checkSystem()
{
    #result=$(id | awk '{print $1}')
    #if [ $result != "uid=0(root)" ]; then
    #    colorEcho $RED " 请以root身份执行该脚本"
    #    exit 1
    #fi

    res=`which yum 2>/dev/null`
    if [ "$?" != "0" ]; then
        res=`which apt 2>/dev/null`
        if [ "$?" != "0" ]; then
            colorEcho $RED " 不受支持的Linux系统"
            exit 1
        fi
        PMT=apt
        #CMD_INSTALL="apt install -y "
        #CMD_REMOVE="apt remove -y "
        #CMD_UPGRADE="apt update; apt upgrade -y; apt autoremove -y"
    else
        PMT=yum
        #CMD_INSTALL="yum install -y "
        #CMD_REMOVE="yum remove -y "
        #CMD_UPGRADE="yum update -y"
    fi
    res=`which systemctl 2>/dev/null`
    if [ "$?" != "0" ]; then
        colorEcho $RED " 系统版本过低，请升级到最新版本"
        exit 1
    fi
}


function Auto_Swap(){
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

function InstallSystem_debian(){
	source <(curl -sL https://raw.githubusercontent.com/vsyour/onekeyrdp/main/debian.sh $1)
}

function InstallSystem_centos(){
	source <(curl -sL https://raw.githubusercontent.com/vsyour/onekeyrdp/main/centos.sh $1)
}

[[ "$PMT" = "apt" ]] && InstallSystem_debian "debian"
[[ "$PMT" = "yum" ]] && InstallSystem_centos "centos"
