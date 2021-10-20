#!/bin/bash
#
# Configure And Start RDP FOR CentOS/Ubuntu/Debian.
#
# Copyright © 2015-2099 vksec <QQ Group: 397745473>
#
# Reference URL:
# https://www.vksec.com


function checkSystem(){
  if [[ -f /etc/redhat-release ]]; then
    release="centos"
  elif cat /etc/issue | grep -q -E -i "debian"; then
    release="debian"
  elif cat /etc/issue | grep -q -E -i "ubuntu 2"; then
    release="ubuntu2"
  elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="ubuntu"	
  elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
  elif cat /proc/version | grep -q -E -i "debian"; then
    release="debian"
  elif cat /proc/version | grep -q -E -i "ubuntu"; then
    release="ubuntu"
  elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
  fi
  #bit=`uname -m`
}


checkSystem
[[ "$release" = "debian" ]] && source <(curl -sL https://raw.githubusercontent.com/vsyour/onekeyrdp/main/debian.sh "debian") 
[[ "$release" = "ubuntu" ]] && source <(curl -sL https://raw.githubusercontent.com/vsyour/onekeyrdp/main/debian.sh "ubuntu") 
[[ "$release" = "centos" ]] && source <(curl -sL https://raw.githubusercontent.com/vsyour/onekeyrdp/main/centos.sh "centos")
[[ "$release" = "ubuntu2" ]] && source <(curl -sL https://raw.githubusercontent.com/vsyour/onekeyrdp/main/ubuntu2.sh "ubuntu")
