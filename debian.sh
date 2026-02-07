#!/bin/bash
#
# Configure And Start RDP FOR CentOS/Ubuntu/Debian.
#
# Copyright © 2015-2099 vksec <QQ Group: 397745473>
#
# Reference URL:
# https://www.vksec.com

# --- 0. 必须以 root 运行 ---
if [ "$(id -u)" != "0" ]; then
   echo "Error: You must be root to run this script."
   echo "Please run: sudo $0"
   exit 1
fi

# 临时设置非交互模式，防止 apt 卡住
export DEBIAN_FRONTEND=noninteractive

# --- 1. 环境自检与修复 (核心修复：解决 command not found) ---
echo ">>> [1/7] Checking system environment..."

# 更新源
apt-get update -y

# 检测并安装 sudo, wget, curl, vim, locales
PACKAGES="sudo wget curl vim locales net-tools"
for pkg in $PACKAGES; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then
        echo "(!) Installing missing package: $pkg..."
        apt-get install -y $pkg
    fi
done

# --- 2. 强制修复中文环境 (核心修复：解决 locale error) ---
echo ">>> [2/7] Configuring Chinese Locale..."

# 强制取消 /etc/locale.gen 文件中 zh_CN.UTF-8 的注释
if [ -f /etc/locale.gen ]; then
    sed -i 's/^# *zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
    sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
fi

# 重新生成语言包
locale-gen zh_CN.UTF-8 en_US.UTF-8

# 设置系统语言变量
update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8

# --- 3. 配置用户信息 ---
logPath='./oneKeyRdp.log'
userName=${1:-"debian"}
passWord=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12;echo)

echo ">>> [3/7] Creating User: $userName..."
date "+【%Y-%m-%d %H:%M:%S】 Creating User..." 2>&1 | tee -a $logPath

if id "$userName" &>/dev/null; then
    echo "User ${userName} already exists. Updating password."
else
    useradd -s /bin/bash -m $userName
fi
echo "${userName}:${passWord}" | chpasswd
echo "${userName}  ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${userName}"

# --- 4. 设置 Swap (防止内存不足) ---
echo ">>> [4/7] Checking Swap..."
current_swap=$(free -m | grep Swap | awk '{print $2}')
if [ -z "$current_swap" ] || [ "$current_swap" -eq 0 ]; then
    echo "Creating 2GB swap file..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- 5. 安装桌面、输入法与字体 ---
echo ">>> [5/7] Installing Desktop (LXDE) & Input Method..."
apt-get install -y lxde-core lxterminal mousepad
# 安装文泉驿字体和 Noto CJK
apt-get install -y ttf-wqy-zenhei ttf-wqy-microhei fonts-noto-cjk
# 安装 Fcitx 输入法
apt-get install -y fcitx fcitx-googlepinyin fcitx-table-wbpy im-config

# 设置时区
timedatectl set-timezone Asia/Shanghai

# --- 配置用户环境变量 (.bashrc) ---
# 使用 EOF 块一次性写入，避免重复逻辑
cat <<EOF >> /home/${userName}/.bashrc
# Chinese Language Support
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
EOF

# 修复权限
chown $userName:$userName /home/${userName}/.bashrc

# 设置默认输入法
su - $userName -c "im-config -n fcitx"

# --- 6. 安装与修复 XRDP ---
echo ">>> [6/7] Installing XRDP..."
apt-get install -y xrdp

# 修复 Polkit 弹窗 (Authentication Required)
mkdir -p /etc/polkit-1/localauthority/50-local.d/
cat <<EOF > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# 配置 XRDP 启动 Session
su - $userName -c "echo 'lxsession -s LXDE -e LXDE' > ~/.xsession"

systemctl restart xrdp
systemctl enable xrdp

# --- 7. 安装 Chrome ---
echo ">>> [7/7] Installing Chrome..."
if ! command -v google-chrome &> /dev/null; then
    wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    dpkg -i /tmp/google-chrome.deb
    apt-get install --assume-yes --fix-broken
    rm -f /tmp/google-chrome.deb
fi

# --- 完成 ---
echo "-------------------------------------------------------"
echo "  Installation Completed!"
echo "  IP Address: $(curl -s ifconfig.me)"
echo "  Username  : ${userName}"
echo "  Password  : ${passWord}"
echo "-------------------------------------------------------"
echo "Press any key to REBOOT system (Required for Chinese locale)..."

# 简化的暂停函数
read -n 1 -s -r -p ""
reboot
