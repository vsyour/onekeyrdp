#!/bin/bash
#
# Configure And Start RDP FOR openSUSE (Leap / Tumbleweed).
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
zypper --non-interactive refresh
zypper --non-interactive update
zypper --non-interactive install sudo wget curl vim net-tools xauth dbus-1-x11

# --- 2. 语言环境配置 ---
echo -e "${Green}>>> [2/5] Configuring Locale...${Font}"
zypper --non-interactive install glibc-locale glibc-locale-base 2>/dev/null || true

localectl set-locale LANG=en_US.UTF-8 2>/dev/null || \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8

# --- 3. 用户与 Swap 设置 (使用 common.sh) ---
echo -e "${Green}>>> [3/5] Setting up User and Swap...${Font}"
userName=${1:-"suse"}
passWord=$(create_user "$userName")
setup_swap

# --- 4. 安装桌面环境 ---
echo -e "${Green}>>> [4/5] Installing Desktop (XFCE) & Input Method...${Font}"

# 安装 XFCE
zypper --non-interactive install -t pattern xfce 2>/dev/null || \
    zypper --non-interactive install xfce4-session xfwm4 xfce4-panel xfdesktop xfce4-terminal thunar 2>/dev/null || true

# X Window System 基础
zypper --non-interactive install xorg-x11-server xorg-x11-driver-video xinit 2>/dev/null || true

# 安装中文字体
zypper --non-interactive install google-noto-sans-sc-fonts wqy-zenhei-fonts wqy-microhei-fonts 2>/dev/null || \
    zypper --non-interactive install intlfonts-chinese-big-bitmap-fonts 2>/dev/null || true

# 安装 IBus
zypper --non-interactive install ibus ibus-libpinyin ibus-gtk ibus-gtk3 2>/dev/null || true
zypper --non-interactive install mousepad nano MozillaFirefox 2>/dev/null || true

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
zypper --non-interactive install xrdp

# 修复 Polkit (openSUSE 使用新版规则)
fix_polkit_new

# 配置 Session
su - $userName -c "echo 'startxfce4' > ~/.xsession"
su - $userName -c "chmod +x ~/.xsession"

systemctl restart xrdp
systemctl enable xrdp

# --- 6. 安装 Chromium ---
echo -e "${Green}>>> [6/6] Installing Chromium...${Font}"
zypper --non-interactive install chromium 2>/dev/null || true

# --- 完成 (使用 common.sh) ---
public_ip=$(get_public_ip)
print_summary "$public_ip" "$userName" "$passWord" "XFCE" "IBus"
