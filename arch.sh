#!/bin/bash
#
# Configure And Start RDP FOR Arch Linux.
# Optimized: English Environment + Chinese Support + AUR Support + Fix Black Screen
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
pacman -Syu --noconfirm
pacman -S --noconfirm sudo wget curl vim base-devel net-tools xorg-xauth dbus git

# --- 2. 语言环境配置 ---
echo -e "${Green}>>> [2/5] Configuring Locale...${Font}"
sed -i 's/^# *zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# --- 3. 用户与 Swap 设置 (使用 common.sh) ---
echo -e "${Green}>>> [3/5] Setting up User and Swap...${Font}"
userName=${1:-"arch"}
# Arch 需要特殊的用户组设置，但 common.sh 的基本创建也兼容，这里保留 common.sh 调用
# 如果需要特殊组，可以在 common.sh 后追加 usermod
passWord=$(create_user "$userName")

# Arch 推荐将用户加入 wheel 组
usermod -aG wheel "$userName"

# 确保 sudoers 包含 sudoers.d 目录 (Arch 默认可能没有)
if ! grep -q "^#includedir /etc/sudoers.d" /etc/sudoers && \
   ! grep -q "^@includedir /etc/sudoers.d" /etc/sudoers; then
    echo "#includedir /etc/sudoers.d" >> /etc/sudoers
fi

setup_swap

# --- 4. 安装桌面环境 ---
echo -e "${Green}>>> [4/5] Installing Desktop (LXDE) & Input Method...${Font}"

# 直接安装整个 lxde 组和 openbox
pacman -S --noconfirm xorg-server xorg-xinit lxde openbox \
    wqy-zenhei wqy-microhei adobe-source-han-sans-cn-fonts \
    fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-chinese-addons

timedatectl set-timezone Asia/Shanghai 2>/dev/null || \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 配置用户环境
cat <<EOF > /home/${userName}/.xprofile
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
fcitx5 -d &
EOF
chown $userName:$userName /home/${userName}/.xprofile

# --- 5. 配置 XRDP (通过 AUR) ---
echo -e "${Green}>>> [5/5] Installing XRDP from AUR...${Font}"

# 安装 yay (AUR helper)
if ! command -v yay &>/dev/null; then
    su - $userName -c "git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -si --noconfirm"
    rm -rf /tmp/yay-bin
fi

su - $userName -c "yay -S --noconfirm xrdp xorgxrdp"

# 【修复黑屏关键】：使用 dbus-launch 包装启动
su - $userName -c "echo 'exec dbus-launch --exit-with-session startlxde' > ~/.xinitrc"
su - $userName -c "chmod +x ~/.xinitrc"
su - $userName -c "ln -sf ~/.xinitrc ~/.xsession"

# 全局兜底
mkdir -p /etc/X11/xinit/xinitrc.d/
echo "exec dbus-launch --exit-with-session startlxde" > /etc/X11/xinit/xinitrc.d/99-lxde.sh
chmod +x /etc/X11/xinit/xinitrc.d/99-lxde.sh

echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

systemctl enable xrdp --now
systemctl enable xrdp-sesman --now

# --- 6. 安装 Chromium ---
echo -e "${Green}>>> [6/6] Installing Chromium...${Font}"
pacman -S --noconfirm chromium

# --- 完成 (使用 common.sh) ---
public_ip=$(get_public_ip)
print_summary "$public_ip" "$userName" "$passWord" "LXDE" "Fcitx5"
