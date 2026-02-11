#!/bin/bash
#
# Configure And Start RDP FOR Fedora.
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
dnf update -y
dnf install -y sudo wget curl vim net-tools xorg-x11-xauth dbus-x11

# --- 2. 语言环境配置 ---
echo ">>> [2/7] Configuring Locale (English System + Chinese Support)..."
dnf install -y glibc-langpack-en glibc-langpack-zh 2>/dev/null || true
localectl set-locale LANG=en_US.UTF-8 2>/dev/null || \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8

# --- 3. 创建用户 ---
logPath='./oneKeyRdp.log'
userName=${1:-"fedora"}
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
dnf groupinstall -y "Xfce Desktop" 2>/dev/null || \
    dnf install -y @xfce-desktop-environment 2>/dev/null || \
    dnf install -y xfce4-session xfwm4 xfce4-panel xfdesktop xfce4-terminal thunar 2>/dev/null || true

# X Window System 基础
dnf groupinstall -y "base-x" 2>/dev/null || \
    dnf install -y xorg-x11-server-Xorg xorg-x11-xinit 2>/dev/null || true

# 安装中文字体
dnf install -y wqy-zenhei-fonts wqy-microhei-fonts google-noto-sans-cjk-fonts 2>/dev/null || true

# 安装 IBus 中文输入法
dnf install -y ibus ibus-libpinyin ibus-gtk3 ibus-gtk2 2>/dev/null || true

# 安装额外工具
dnf install -y mousepad nano firefox 2>/dev/null || true

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
dnf install -y xrdp

# 修复 Polkit 弹窗 (Fedora 使用 rules.d)
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

# --- 7. 安装 Chrome ---
echo ">>> [7/7] Installing Chrome..."
if ! command -v google-chrome &>/dev/null; then
    wget -q -O /tmp/google-chrome.rpm https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
    dnf install -y /tmp/google-chrome.rpm || true
    rm -f /tmp/google-chrome.rpm
fi

# --- 完成 ---
date "+【%Y-%m-%d %H:%M:%S】 Setup Completed." >> $logPath
echo "Username: ${userName}  Password: ${passWord}" >> $logPath

public_ip=$(curl -s --max-time 5 ifconfig.me)
[ -z "$public_ip" ] && public_ip="Your_Server_IP"

echo "-------------------------------------------------------"
echo "  Fedora RDP Installation Completed!"
echo "  Desktop     : XFCE"
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
