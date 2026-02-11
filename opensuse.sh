#!/bin/bash
#
# Configure And Start RDP FOR openSUSE (Leap / Tumbleweed).
# Optimized: English Environment + Chinese Support (Fonts & IBus Input)
#

# --- 0. 权限检查 ---
if [ "$(id -u)" != "0" ]; then
    echo "Error: You must be root to run this script."
    echo "Please run: sudo $0"
    exit 1
fi

# --- 1. 环境准备 ---
echo ">>> [1/7] Updating system and installing base tools..."
zypper --non-interactive refresh
zypper --non-interactive update
zypper --non-interactive install sudo wget curl vim net-tools xauth dbus-1-x11

# --- 2. 语言环境配置 ---
echo ">>> [2/7] Configuring Locale (English System + Chinese Support)..."
zypper --non-interactive install glibc-locale glibc-locale-base 2>/dev/null || true

# 设置系统语言为英文
localectl set-locale LANG=en_US.UTF-8 2>/dev/null || \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8

# --- 3. 创建用户 ---
logPath='./oneKeyRdp.log'
userName=${1:-"suse"}
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
echo ">>> [5/7] Installing Desktop (XFCE), Fonts & IBus..."

# 安装 XFCE 桌面
zypper --non-interactive install -t pattern xfce 2>/dev/null || \
    zypper --non-interactive install xfce4-session xfwm4 xfce4-panel xfdesktop xfce4-terminal thunar 2>/dev/null || true

# X Window System 基础
zypper --non-interactive install xorg-x11-server xorg-x11-driver-video xinit 2>/dev/null || true

# 安装中文字体
zypper --non-interactive install google-noto-sans-sc-fonts wqy-zenhei-fonts wqy-microhei-fonts 2>/dev/null || \
    zypper --non-interactive install intlfonts-chinese-big-bitmap-fonts 2>/dev/null || true

# 安装 IBus 中文输入法
zypper --non-interactive install ibus ibus-libpinyin ibus-gtk ibus-gtk3 2>/dev/null || true

# 安装额外工具
zypper --non-interactive install mousepad nano MozillaFirefox 2>/dev/null || true

# 设置时区
timedatectl set-timezone Asia/Shanghai 2>/dev/null || \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# --- 配置用户环境 ---
cat <<EOF > /home/${userName}/.xsessionrc
# Load IBus input method environment variables
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus

# Start IBus automatically
ibus-daemon -drx &
EOF
chown ${userName}:${userName} /home/${userName}/.xsessionrc

# --- 6. 安装与修复 XRDP ---
echo ">>> [6/7] Installing & Configuring XRDP..."
zypper --non-interactive install xrdp

# 修复 Polkit 弹窗
mkdir -p /etc/polkit-1/rules.d/
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
su - $userName -c "echo 'startxfce4' > ~/.xsession"
su - $userName -c "chmod +x ~/.xsession"

# 启动 XRDP
systemctl restart xrdp
systemctl enable xrdp

# --- 7. 安装 Chromium ---
echo ">>> [7/7] Installing Chromium..."
zypper --non-interactive install chromium 2>/dev/null || true

# --- 完成 ---
date "+【%Y-%m-%d %H:%M:%S】 Setup Completed." >> $logPath
echo "Username: ${userName}  Password: ${passWord}" >> $logPath

public_ip=$(curl -s --max-time 5 ifconfig.me)
[ -z "$public_ip" ] && public_ip="Your_Server_IP"

echo "-------------------------------------------------------"
echo "  openSUSE RDP Installation Completed!"
echo "  Desktop     : XFCE"
echo "  Browser     : Chromium"
echo "  System Lang : English (en_US.UTF-8)"
echo "  Input       : Chinese (IBus Pinyin)"
echo ""
echo "  Address  : ${public_ip}"
echo "  Username : ${userName}"
echo "  Password : ${passWord}"
echo "-------------------------------------------------------"
echo "IMPORTANT: Use 'Super + Space' or IBus tray icon to toggle Chinese Input."
echo "Press any key to REBOOT system..."

read -n 1 -s -r -p ""
reboot
