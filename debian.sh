#!/bin/bash
#
# Configure And Start RDP FOR Debian/Ubuntu.
# Optimized: English Environment + Chinese Support (Fonts & Input)
#

# 引入公共函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" 2>/dev/null && pwd)"
if [ -f "${SCRIPT_DIR}/common.sh" ]; then
    source "${SCRIPT_DIR}/common.sh"
else
    # 如果找不到本地文件，尝试从远程加载 (支持 curl 管道运行)
    source <(curl -sL https://raw.githubusercontent.com/vsyour/onekeyrdp/main/common.sh)
fi

# --- 1. 基础检查与准备 ---
check_root

export DEBIAN_FRONTEND=noninteractive

echo -e "${Green}>>> [1/5] Updating system and installing base tools...${Font}"
apt-get update -y
apt-get install -y sudo wget curl vim locales net-tools xauth dbus-x11

# --- 2. 语言环境配置 ---
echo -e "${Green}>>> [2/5] Configuring Locale...${Font}"
if [ ! -f /etc/locale.gen ]; then
    apt-get install -y locales
fi
sed -i 's/^# *zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# --- 3. 用户与 Swap 设置 (使用 common.sh) ---
echo -e "${Green}>>> [3/5] Setting up User and Swap...${Font}"
userName=${1:-"debian"}
# 调用 common.sh 中的 create_user 函数，并捕获输出的密码
passWord=$(create_user "$userName")

# 调用 common.sh 中的 setup_swap 函数
setup_swap

# --- 4. 安装桌面环境 ---
echo -e "${Green}>>> [4/5] Installing Desktop (LXDE) & Input Method...${Font}"

# 安装 LXDE
apt-get install -y lxde-core lxterminal mousepad

# 安装中文字体
apt-get install -y fonts-wqy-zenhei fonts-wqy-microhei fonts-noto-cjk 2>/dev/null || \
    apt-get install -y ttf-wqy-zenhei ttf-wqy-microhei fonts-noto-cjk 2>/dev/null || true

# 安装 Fcitx
apt-get install -y fcitx fcitx-googlepinyin fcitx-table-wbpy fcitx-ui-classic fcitx-config-gtk 2>/dev/null || \
    apt-get install -y fcitx5 fcitx5-chinese-addons fcitx5-frontend-gtk3 fcitx5-frontend-qt5 2>/dev/null || true

# 设置时区
timedatectl set-timezone Asia/Shanghai 2>/dev/null || \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 配置用户输入法环境
cat <<EOF > /home/${userName}/.xsessionrc
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
if command -v fcitx5 &>/dev/null; then
    fcitx5 -d &
elif command -v fcitx &>/dev/null; then
    fcitx -d &
fi
EOF
chown $userName:$userName /home/${userName}/.xsessionrc

# --- 5. 配置 XRDP ---
echo -e "${Green}>>> [5/5] Configuring XRDP...${Font}"
apt-get install -y xrdp

# 修复 Polkit (使用 common.sh)
fix_polkit_legacy

# 配置 Session
su - $userName -c "echo 'startlxde' > ~/.xsession"

systemctl restart xrdp
systemctl enable xrdp

# --- 6. 安装 Chrome ---
if ! command -v google-chrome &> /dev/null; then
    wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt-get install -y /tmp/google-chrome.deb || true
    rm -f /tmp/google-chrome.deb
fi

# --- 完成 (使用 common.sh) ---
public_ip=$(get_public_ip)
print_summary "$public_ip" "$userName" "$passWord" "LXDE" "Fcitx"
