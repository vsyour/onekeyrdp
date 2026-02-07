#!/bin/bash
#
# Configure And Start RDP FOR Debian/Ubuntu.
# Optimized: English Environment + Chinese Support (Fonts & Input)
#

# --- 0. 权限检查 ---
if [ "$(id -u)" != "0" ]; then
    echo "Error: You must be root to run this script."
    echo "Please run: sudo $0"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# --- 1. 环境准备 ---
echo ">>> [1/7] Updating system and installing base tools..."
apt-get update -y
# 安装基础工具 + xauth/dbus (解决XRDP闪退)
apt-get install -y sudo wget curl vim locales net-tools xauth dbus-x11

# --- 2. 语言环境配置 (关键修改：保持英文系统，支持中文显示) ---
echo ">>> [2/7] Configuring Locale (English System + Chinese Support)..."

# 确保 locale.gen 存在
if [ ! -f /etc/locale.gen ]; then
    apt-get install -y locales
fi

# 启用 en_US 和 zh_CN
sed -i 's/^# *zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen

# 生成语言包
locale-gen

# 关键：设置默认系统语言为英文 (这样界面就是英文的)
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# --- 3. 创建用户 ---
logPath='./oneKeyRdp.log'
# 如果未指定参数，默认用户名为 debian
userName=${1:-"debian"}
# 生成随机密码
passWord=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12;echo)

echo ">>> [3/7] Creating User: $userName..."
date "+【%Y-%m-%d %H:%M:%S】 Creating User..." >> $logPath

if id "$userName" &>/dev/null; then
    echo "User ${userName} already exists. Updating password."
else
    useradd -s /bin/bash -m $userName
fi
# 设置密码
echo "${userName}:${passWord}" | chpasswd
# 设置 sudo 权限 (使用独立文件更安全)
echo "${userName} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${userName}"
chmod 0440 "/etc/sudoers.d/${userName}"

# --- 4. 设置 Swap (防止 Chrome 崩溃) ---
echo ">>> [4/7] Configuring Swap..."
# 只有当 swap 为 0 时才创建，避免重复
if [ $(free -m | grep Swap | awk '{print $2}') -eq 0 ]; then
    echo "Creating 2GB swap file..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    # 检查 fstab 防止重复写入
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
else
    echo "Swap already exists, skipping."
fi

# --- 5. 安装桌面、字体与输入法 ---
echo ">>> [5/7] Installing Desktop (LXDE), Fonts & Fcitx..."

# 安装 LXDE 核心 (轻量)
apt-get install -y lxde-core lxterminal mousepad

# 关键：安装中文字体 (解决方块字)
apt-get install -y ttf-wqy-zenhei ttf-wqy-microhei fonts-noto-cjk

# 关键：安装 Fcitx 输入法及拼音
apt-get install -y fcitx fcitx-googlepinyin fcitx-table-wbpy fcitx-ui-classic fcitx-config-gtk

# 设置时区为上海
timedatectl set-timezone Asia/Shanghai

# --- 配置用户环境 (支持英文环境下输入中文) ---
# 使用 .xsessionrc 确保 XRDP 登录时加载输入法变量
cat <<EOF > /home/${userName}/.xsessionrc
# Load Fcitx specific environment variables
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

# Start Fcitx automatically
fcitx -d &
EOF

# 修复权限
chown $userName:$userName /home/${userName}/.xsessionrc

# --- 6. 安装与修复 XRDP ---
echo ">>> [6/7] Installing & Configuring XRDP..."
apt-get install -y xrdp

# 修复 Polkit 弹窗 (Debian/Ubuntu 通用修复)
cat <<EOF > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# 配置 XRDP 启动 Session (保证启动 LXDE)
# 注意：这里我们让 .xsession 调用 startlxde，而 .xsessionrc 会被 X11 自动调用加载变量
su - $userName -c "echo 'startlxde' > ~/.xsession"

# 重启 XRDP 服务
systemctl restart xrdp
systemctl enable xrdp

# --- 7. 安装 Chrome ---
echo ">>> [7/7] Installing Chrome..."
if ! command -v google-chrome &> /dev/null; then
    wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    # 使用 apt install ./file.deb 可以自动解决依赖，比 dpkg -i 更安全
    apt-get install -y /tmp/google-chrome.deb
    rm -f /tmp/google-chrome.deb
fi

# --- 完成 ---
#获取公网IP
public_ip=$(curl -s --max-time 5 ifconfig.me)
[ -z "$public_ip" ] && public_ip="Your_Server_IP"

echo "-------------------------------------------------------"
echo "  Installation Completed!"
echo "  System Language : English (en_US.UTF-8)"
echo "  Input Support   : Chinese (Fcitx)"
echo ""
echo "  Address  : ${public_ip}"
echo "  Username : ${userName}"
echo "  Password : ${passWord}"
echo "-------------------------------------------------------"
echo "IMPORTANT: Using RDP, use 'Ctrl + Space' to toggle Chinese Input."
echo "Press any key to REBOOT system (Apply changes)..."

read -n 1 -s -r -p ""
reboot
