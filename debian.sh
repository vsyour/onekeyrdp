#!/bin/bash
#
# Configure And Start RDP FOR CentOS/Ubuntu/Debian.
#
# Copyright © 2015-2099 vksec <QQ Group: 397745473>
#
# Reference URL:
# https://www.vksec.com

# --- 0. 环境自检与修复 (核心修复部分) ---
# 必须以 root 运行
if [ "$(id -u)" != "0" ]; then
   echo "Error: You must be root to run this script."
   echo "Please run: sudo $0"
   exit 1
fi

# 临时设置非交互模式
export DEBIAN_FRONTEND=noninteractive

echo ">>> Checking system environment..."

# 检测并安装 sudo (如果你没有 sudo，脚本后面会全报错)
if ! command -v sudo &> /dev/null; then
    echo "(!) 'sudo' not found. Installing..."
    apt-get update -y
    apt-get install -y sudo
fi

# 检测并安装 wget 和 curl
if ! command -v wget &> /dev/null; then
    echo "(!) 'wget' not found. Installing..."
    apt-get install -y wget
fi

if ! command -v curl &> /dev/null; then
    echo "(!) 'curl' not found. Installing..."
    apt-get install -y curl
fi

# 确保基础工具齐全
apt-get install -y vim net-tools

# --- 以下是原有逻辑 ---

get_char() {
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

# 辅助函数：安全写入配置
append_if_missing() {
    local file="$1"
    local line="$2"
    grep -qF -- "$line" "$file" || echo "$line" >> "$file"
}

echo "
+----------------------------------------------------------------------
| One-Key RDP Setup (Self-Healing Edition)
+----------------------------------------------------------------------
| Features: Auto-Dependency Fix + LXDE + Chinese + Swap
+----------------------------------------------------------------------
"; sleep 2

logPath='./oneKeyRdp.log'
userName=${1:-"debian"}
passWord=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12;echo`

printf ">>> Starting Installation... \n" >&2

# --- 1. 创建用户 ---
date "+【%Y-%m-%d %H:%M:%S】 Creating User..." 2>&1 | tee -a $logPath

if id "$userName" &>/dev/null; then
    echo "User ${userName} already exists. Updating password."
else
    useradd -s /bin/bash -m $userName
fi
echo "${userName}:${passWord}" | chpasswd
# 这里使用了 sudo，但前面已经确保安装了
echo "${userName}  ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${userName}"

# --- 2. 设置 Swap (防止内存不足) ---
date "+【%Y-%m-%d %H:%M:%S】 Checking Swap Memory..." 2>&1 | tee -a $logPath
current_swap=$(free -m | grep Swap | awk '{print $2}')
# 如果 swap 为空或为 0
if [ -z "$current_swap" ] || [ "$current_swap" -eq 0 ]; then
    echo "No swap detected. Creating 2GB swap file..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    echo "Swap created successfully."
else
    echo "Swap already exists. Skipping."
fi

# --- 3. 安装桌面环境 ---
date "+【%Y-%m-%d %H:%M:%S】 Installing Desktop (LXDE)..." 2>&1 | tee -a $logPath
apt-get install -y lxde-core lxterminal mousepad

# --- 4. 配置中文环境与时区 ---
date "+【%Y-%m-%d %H:%M:%S】 Configuring Chinese & Timezone..." 2>&1 | tee -a $logPath

# 4.1 设置时区
timedatectl set-timezone Asia/Shanghai

# 4.2 安装语言包和输入法
apt-get install -y locales ttf-wqy-zenhei ttf-wqy-microhei fonts-noto-cjk
apt-get install -y fcitx fcitx-googlepinyin fcitx-table-wbpy im-config

# 4.3 生成语言环境
locale-gen zh_CN.UTF-8
update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8

# 4.4 配置用户变量
BASHRC="/home/${userName}/.bashrc"
touch $BASHRC
chown $userName:$userName $BASHRC

# 使用 su 切换用户身份写入配置
su - $userName -c "grep -q 'export LANG=zh_CN.UTF-8' ~/.bashrc || echo 'export LANG=zh_CN.UTF-8' >> ~/.bashrc"
su - $userName -c "grep -q 'export LC_ALL=zh_CN.UTF-8' ~/.bashrc || echo 'export LC_ALL=zh_CN.UTF-8' >> ~/.bashrc"
su - $userName -c "grep -q 'export GTK_IM_MODULE=fcitx' ~/.bashrc || echo 'export GTK_IM_MODULE=fcitx' >> ~/.bashrc"
su - $userName -c "grep -q 'export XMODIFIERS=@im=fcitx' ~/.bashrc || echo 'export XMODIFIERS=@im=fcitx' >> ~/.bashrc"

# 设置默认输入法
su - $userName -c "im-config -n fcitx"

# --- 5. 安装与修复 XRDP ---
date "+【%Y-%m-%d %H:%M:%S】 Installing & Fixing XRDP..." 2>&1 | tee -a $logPath
apt-get install -y xrdp

# 5.1 修复 Polkit 弹窗
mkdir -p /etc/polkit-1/localauthority/50-local.d/
cat <<EOF | tee /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# 5.2 配置 XRDP 启动 Session
su - $userName -c "echo 'lxsession -s LXDE -e LXDE' > ~/.xsession"

systemctl restart xrdp
systemctl enable xrdp

# --- 6. 安装 Chrome ---
date "+【%Y-%m-%d %H:%M:%S】 Installing Chrome..." 2>&1 | tee -a $logPath
if ! command -v google-chrome &> /dev/null; then
    wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    dpkg -i /tmp/google-chrome.deb
    apt-get install --assume-yes --fix-broken
    rm -f /tmp/google-chrome.deb
else
    echo "Chrome already installed."
fi

# --- 7. 完成 ---
date "+【%Y-%m-%d %H:%M:%S】 Setup Completed." 2>&1
printf "\n"
printf "#######################################################\n"
printf "  RDP Installation Success!\n"
printf "  IP Address: $(curl -s ifconfig.me)\n"
printf "  Username  : ${userName}\n"
printf "  Password  : ${passWord}\n"
printf "  Timezone  : Asia/Shanghai\n"
printf "#######################################################\n"

echo "Press any key to REBOOT the server..."
char=`get_char`
reboot
