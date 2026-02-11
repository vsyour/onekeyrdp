#!/bin/bash
#
# Configure And Start RDP FOR Arch Linux.
# Optimized: English Environment + Chinese Support + AUR Support + Fix Black Screen
#

# --- 0. 权限检查 ---
if [ "$(id -u)" != "0" ]; then
    echo "Error: You must be root to run this script."
    exit 1
fi

# --- 1. 环境准备 ---
echo ">>> [1/7] Updating system and installing base tools..."
pacman -Syu --noconfirm
pacman -S --noconfirm sudo wget curl vim base-devel net-tools xorg-xauth dbus git

# --- 2. 语言环境配置 ---
echo ">>> [2/7] Configuring Locale..."
sed -i 's/^# *zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# --- 3. 创建用户 ---
logPath='./oneKeyRdp.log'
userName=${1:-"arch"}
passWord=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12;echo)

echo ">>> [3/7] Creating User: $userName..."
date "+【%Y-%m-%d %H:%M:%S】 Creating User..." >> $logPath

if id "$userName" &>/dev/null; then
    echo "User ${userName} already exists."
else
    useradd -m -g users -G wheel -s /bin/bash "$userName"
fi
echo "${userName}:${passWord}" | chpasswd

# 使用 sudoers.d (安全方式，不直接修改 /etc/sudoers)
echo "${userName} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${userName}"
chmod 0440 "/etc/sudoers.d/${userName}"

# 确保 sudoers 包含 sudoers.d 目录
if ! grep -q "^#includedir /etc/sudoers.d" /etc/sudoers && \
   ! grep -q "^@includedir /etc/sudoers.d" /etc/sudoers; then
    echo "#includedir /etc/sudoers.d" >> /etc/sudoers
fi

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

# --- 5. 安装桌面、字体与输入法 (修复黑屏的关键点) ---
echo ">>> [5/7] Installing LXDE, Fonts & Fcitx5..."
# 直接安装整个 lxde 组和 openbox，防止组件缺失导致黑屏
pacman -S --noconfirm xorg-server xorg-xinit lxde openbox \
    wqy-zenhei wqy-microhei adobe-source-han-sans-cn-fonts \
    fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-chinese-addons

timedatectl set-timezone Asia/Shanghai 2>/dev/null || \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

cat <<EOF > /home/${userName}/.xprofile
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
fcitx5 -d &
EOF
chown $userName:users /home/${userName}/.xprofile

# --- 6. 安装与修复 XRDP (通过 AUR) ---
echo ">>> [6/7] Installing yay and XRDP from AUR..."

# 安装 yay (AUR helper)
if ! command -v yay &>/dev/null; then
    su - $userName -c "git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -si --noconfirm"
    rm -rf /tmp/yay-bin
fi

su - $userName -c "yay -S --noconfirm xrdp xorgxrdp"

# 【修复黑屏关键】：使用 dbus-launch 包装启动，并写入 .xsession
su - $userName -c "echo 'exec dbus-launch --exit-with-session startlxde' > ~/.xinitrc"
su - $userName -c "chmod +x ~/.xinitrc"
su - $userName -c "ln -sf ~/.xinitrc ~/.xsession"

# 全局兜底：确保所有的 X11 启动都会调起 LXDE
mkdir -p /etc/X11/xinit/xinitrc.d/
echo "exec dbus-launch --exit-with-session startlxde" > /etc/X11/xinit/xinitrc.d/99-lxde.sh
chmod +x /etc/X11/xinit/xinitrc.d/99-lxde.sh

echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

systemctl enable xrdp --now
systemctl enable xrdp-sesman --now

# --- 7. 安装 Chromium ---
echo ">>> [7/7] Installing Chromium..."
pacman -S --noconfirm chromium

# --- 完成 ---
date "+【%Y-%m-%d %H:%M:%S】 Setup Completed." >> $logPath
echo "Username: ${userName}  Password: ${passWord}" >> $logPath

public_ip=$(curl -s --max-time 5 ifconfig.me)
[ -z "$public_ip" ] && public_ip="Your_Server_IP"

echo "-------------------------------------------------------"
echo "  Arch Linux RDP Installation Completed!"
echo "  Browser   : Chromium"
echo "  Address   : ${public_ip}"
echo "  Username  : ${userName}"
echo "  Password  : ${passWord}"
echo "-------------------------------------------------------"
echo "Press any key to REBOOT..."
read -n 1 -s -r -p ""
reboot
