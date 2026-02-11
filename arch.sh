#!/bin/bash
#
# Configure And Start RDP FOR Arch Linux.
# Optimized: English Environment + Chinese Support (Fonts & Input) + AUR Support
#

# --- 0. 权限检查 ---
if [ "$(id -u)" != "0" ]; then
    echo "Error: You must be root to run this script."
    exit 1
fi

# --- 1. 环境准备 ---
echo ">>> [1/7] Updating system and installing base tools..."
pacman -Syu --noconfirm
# 新增了 git，用于后续克隆 AUR 仓库
pacman -S --noconfirm sudo wget curl vim base-devel net-tools xauth dbus git

# --- 2. 语言环境配置 ---
echo ">>> [2/7] Configuring Locale..."
sed -i 's/^# *zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# --- 3. 创建用户 (此用户将用于编译 AUR 包) ---
userName=${1:-"arch"}
passWord=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12;echo)

echo ">>> [3/7] Creating User: $userName..."
if id "$userName" &>/dev/null; then
    echo "User ${userName} already exists."
else
    useradd -m -g users -G wheel -s /bin/bash "$userName"
fi
echo "${userName}:${passWord}" | chpasswd
# 赋予免密 sudo 权限，这对后续 yay 自动安装依赖至关重要
echo "${userName} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${userName}"

# --- 4. 设置 Swap ---
echo ">>> [4/7] Configuring Swap..."
if [ $(free -m | grep Swap | awk '{print $2}') -eq 0 ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- 5. 安装桌面、字体与输入法 ---
echo ">>> [5/7] Installing LXDE, Fonts & Fcitx5..."
# 增加了 xorg-server 以确保底层 X11 服务就绪
pacman -S --noconfirm xorg-server lxde-common lxsession lxterminal \
    wqy-zenhei wqy-microhei adobe-source-han-sans-cn-fonts \
    fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-chinese-addons

timedatectl set-timezone Asia/Shanghai

# 配置用户环境
cat <<EOF > /home/${userName}/.xprofile
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
fcitx5 -d &
EOF
chown $userName:users /home/${userName}/.xprofile

# --- 6. 安装与修复 XRDP (通过 AUR) ---
echo ">>> [6/7] Installing yay and XRDP from AUR..."
echo "Note: Building AUR packages might take a few minutes..."

# 1. 切换到普通用户安装 yay-bin (预编译版，速度最快)
su - $userName -c "git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -si --noconfirm"

# 2. 清理临时文件
rm -rf /tmp/yay-bin

# 3. 使用 yay 安装 xrdp 和 xorgxrdp
su - $userName -c "yay -S --noconfirm xrdp xorgxrdp"

# 4. 允许桌面启动 (配置 xrdp 环境)
su - $userName -c "echo 'exec startlxde' > ~/.xinitrc"
su - $userName -c "chmod +x ~/.xinitrc"
# 兼容性处理：把 .xinitrc 链接到 .xsession
su - $userName -c "ln -sf ~/.xinitrc ~/.xsession"

echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# 启动服务
systemctl enable xrdp --now
systemctl enable xrdp-sesman --now

# --- 7. 安装 Chrome (Chromium) ---
echo ">>> [7/7] Installing Chromium..."
pacman -S --noconfirm chromium

# --- 完成 ---
public_ip=$(curl -s --max-time 5 ifconfig.me)
[ -z "$public_ip" ] && public_ip="Your_Server_IP"

echo "-------------------------------------------------------"
echo "  Arch Linux RDP Installation Completed!"
echo "  Browser   : Chromium (Installed via pacman)"
echo "  Address   : ${public_ip}"
echo "  Username  : ${userName}"
echo "  Password  : ${passWord}"
echo "-------------------------------------------------------"
echo "Press any key to REBOOT..."
read -n 1 -s -r -p ""
reboot
