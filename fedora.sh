#!/bin/bash
#
# Configure And Start RDP FOR Fedora.
# Optimized: English Environment + Chinese Support (Fonts & IBus Input)
#

# 引入公共函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" 2>/dev/null && pwd)"
if [ -f "${SCRIPT_DIR}/common.sh" ]; then
    source "${SCRIPT_DIR}/common.sh"
else
    source <(curl -sL https://raw.githubusercontent.com/vsyour/onekeyrdp/main/common.sh)
fi

# --- 1. 基础检查与准备 ---
check_root

echo -e "${Green}>>> [1/5] Updating system and installing base tools...${Font}"
dnf update -y
dnf install -y sudo wget curl vim net-tools xorg-x11-xauth dbus-x11

# --- 2. 语言环境配置 ---
echo -e "${Green}>>> [2/5] Configuring Locale...${Font}"
dnf install -y glibc-langpack-en glibc-langpack-zh 2>/dev/null || true
localectl set-locale LANG=en_US.UTF-8 2>/dev/null || \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8

# --- 3. 用户与 Swap 设置 (使用 common.sh) ---
echo -e "${Green}>>> [3/5] Setting up User and Swap...${Font}"
userName=${1:-"fedora"}
passWord=$(create_user "$userName")
setup_swap

# --- 4. 安装桌面环境 ---
echo -e "${Green}>>> [4/5] Installing Desktop (XFCE) & Input Method...${Font}"

# 安装 XFCE
dnf groupinstall -y "Xfce Desktop" 2>/dev/null || \
    dnf install -y @xfce-desktop-environment 2>/dev/null || \
    dnf install -y xfce4-session xfwm4 xfce4-panel xfdesktop xfce4-terminal thunar 2>/dev/null || true

# X Window System 基础
dnf groupinstall -y "base-x" 2>/dev/null || \
    dnf install -y xorg-x11-server-Xorg xorg-x11-xinit 2>/dev/null || true

# 安装中文字体
dnf install -y wqy-zenhei-fonts wqy-microhei-fonts google-noto-sans-cjk-fonts 2>/dev/null || true

# 安装 IBus
dnf install -y ibus ibus-libpinyin ibus-gtk3 ibus-gtk2 2>/dev/null || true
dnf install -y mousepad nano firefox 2>/dev/null || true

# 设置时区
timedatectl set-timezone Asia/Shanghai 2>/dev/null || \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 配置用户环境
cat <<EOF > /home/${userName}/.xsessionrc
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
ibus-daemon -drx &
EOF
chown ${userName}:${userName} /home/${userName}/.xsessionrc

# --- 5. 配置 XRDP ---
echo -e "${Green}>>> [5/5] Configuring XRDP...${Font}"
dnf install -y xrdp

# 修复 Polkit (Fedora 使用新版规则)
fix_polkit_new

# 配置 Session
su - $userName -c "echo 'startxfce4' > ~/.xsession"
su - $userName -c "chmod +x ~/.xsession"

systemctl restart xrdp
systemctl enable xrdp

# --- 6. 安装 Chrome ---
if ! command -v google-chrome &>/dev/null; then
    wget -q -O /tmp/google-chrome.rpm https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
    dnf install -y /tmp/google-chrome.rpm || true
    rm -f /tmp/google-chrome.rpm
fi

# --- 完成 (使用 common.sh) ---
public_ip=$(get_public_ip)
print_summary "$public_ip" "$userName" "$passWord" "XFCE" "IBus"
