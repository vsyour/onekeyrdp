#!/bin/bash
#
# Configure And Start RDP FOR Ubuntu 20.04+.
# Optimized: English Environment + Chinese Support (Fonts & Fcitx Input)
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
apt-get install -y sudo wget curl vim locales net-tools xauth dbus-x11

# --- 2. 语言环境配置 ---
echo ">>> [2/7] Configuring Locale (English System + Chinese Support)..."

if [ ! -f /etc/locale.gen ]; then
    apt-get install -y locales
fi

sed -i 's/^# *zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# --- 3. 创建用户 ---
logPath='./oneKeyRdp.log'
userName=${1:-"ubuntu"}
passWord=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12;echo)

echo ">>> [3/7] Creating User: $userName..."
date "+【%Y-%m-%d %H:%M:%S】 Creating User..." >> $logPath

if id "$userName" &>/dev/null; then
    echo "User ${userName} already exists. Updating password."
else
    useradd -s /bin/bash -m "$userName"
fi
echo "${userName}:${passWord}" | chpasswd
echo "${userName} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${userName}"
chmod 0440 "/etc/sudoers.d/${userName}"

# --- 4. 设置 Swap ---
echo ">>> [4/7] Configuring Swap..."
if [ "$(free -m | grep Swap | awk '{print $2}')" -eq 0 ]; then
    echo "Creating 2GB swap file..."
    fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
else
    echo "Swap already exists, skipping."
fi

# --- 5. 安装桌面、字体与输入法 ---
echo ">>> [5/7] Installing Desktop (LXDE), Fonts & Fcitx..."

# 安装 LXDE 桌面
apt-get install -y lxde-core lxterminal mousepad

# 安装中文字体 (兼容新旧包名)
apt-get install -y fonts-wqy-zenhei fonts-wqy-microhei fonts-noto-cjk 2>/dev/null || \
    apt-get install -y ttf-wqy-zenhei ttf-wqy-microhei fonts-noto-cjk 2>/dev/null || true

# 安装 Fcitx 输入法 (Ubuntu 20-22 用 fcitx, 24+ 用 fcitx5)
apt-get install -y fcitx fcitx-googlepinyin fcitx-table-wbpy fcitx-ui-classic fcitx-config-gtk 2>/dev/null || \
    apt-get install -y fcitx5 fcitx5-chinese-addons fcitx5-frontend-gtk3 fcitx5-frontend-qt5 2>/dev/null || true

# 设置时区
timedatectl set-timezone Asia/Shanghai 2>/dev/null || \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# --- 配置用户环境 ---
cat <<EOF > /home/${userName}/.xsessionrc
# Load Fcitx input method environment variables
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

# Start Fcitx automatically
if command -v fcitx5 &>/dev/null; then
    fcitx5 -d &
elif command -v fcitx &>/dev/null; then
    fcitx -d &
fi
EOF
chown ${userName}:${userName} /home/${userName}/.xsessionrc

# --- 6. 安装与修复 XRDP ---
echo ">>> [6/7] Installing & Configuring XRDP..."
apt-get install -y xrdp

# 修复 Polkit 弹窗 (兼容新旧 Polkit)
mkdir -p /etc/polkit-1/localauthority/50-local.d/ 2>/dev/null
cat <<EOF > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# 对于使用 polkit rules.d 的新系统 (Ubuntu 24+)
mkdir -p /etc/polkit-1/rules.d/ 2>/dev/null
cat <<EOF > /etc/polkit-1/rules.d/45-allow-colord.rules
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.color-manager.create-device" ||
         action.id == "org.freedesktop.color-manager.create-profile" ||
         action.id == "org.freedesktop.color-manager.delete-device" ||
         action.id == "org.freedesktop.color-manager.delete-profile" ||
         action.id == "org.freedesktop.color-manager.modify-device" ||
         action.id == "org.freedesktop.color-manager.modify-profile") &&
        subject.isInGroup("users")) {
        return polkit.Result.YES;
    }
});
EOF

# 配置 XRDP 启动 Session
su - $userName -c "echo 'startlxde' > ~/.xsession"

# 启动 XRDP
systemctl restart xrdp
systemctl enable xrdp

# --- 7. 安装 Chrome ---
echo ">>> [7/7] Installing Chrome..."
if ! command -v google-chrome &>/dev/null; then
    wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt-get install -y /tmp/google-chrome.deb || true
    rm -f /tmp/google-chrome.deb
fi

# --- 完成 ---
date "+【%Y-%m-%d %H:%M:%S】 Setup Completed." >> $logPath
echo "Username: ${userName}  Password: ${passWord}" >> $logPath

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
echo "Press any key to REBOOT system..."

read -n 1 -s -r -p ""
reboot
