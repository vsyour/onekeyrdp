#!/bin/bash
#
# Common functions for OneKeyRdp
# Shared logic for user management, swap configuration, and logging.
#

Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Font="\033[0m"

logPath='./oneKeyRdp.log'

# --- 权限检查 ---
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${Red}Error: You must be root to run this script.${Font}"
        echo -e "${Red}Please run: sudo $0${Font}"
        exit 1
    fi
}

# --- 创建用户 ---
# Usage: create_user "username"
create_user() {
    local userName=${1:-"user"}
    # 生成随机密码 (12位)
    local passWord=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12;echo)

    echo -e "${Green}>>> Creating User: ${userName}...${Font}"
    date "+【%Y-%m-%d %H:%M:%S】 Creating User..." >> "$logPath"

    if id "$userName" &>/dev/null; then
        echo "User ${userName} already exists. Updating password."
    else
        useradd -s /bin/bash -m "$userName"
    fi

    # 设置密码
    echo "${userName}:${passWord}" | chpasswd

    # 设置 sudo 权限
    echo "${userName} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${userName}"
    chmod 0440 "/etc/sudoers.d/${userName}"

    # 返回密码供后续使用
    echo "$passWord"
}

# --- 设置 Swap ---
setup_swap() {
    echo -e "${Green}>>> Configuring Swap...${Font}"
    local swap_size=$(free -m | grep Swap | awk '{print $2}')
    if [ "$swap_size" -eq 0 ]; then
        echo "Creating 2GB swap file..."
        fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        if ! grep -q "/swapfile" /etc/fstab; then
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
        fi
        echo "Swap created successfully."
    else
        echo "Swap already exists, skipping."
    fi
}

# --- 修复 Polkit (旧版 .pkla) ---
fix_polkit_legacy() {
    echo -e "${Green}>>> Fixing Polkit rules (Legacy)...${Font}"
    mkdir -p /etc/polkit-1/localauthority/50-local.d/
    cat <<EOF > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF
}

# --- 修复 Polkit (新版 .rules JavaScript) ---
fix_polkit_new() {
    echo -e "${Green}>>> Fixing Polkit rules (New JS format)...${Font}"
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
}

# --- 获取公网 IP ---
get_public_ip() {
    local ip=$(curl -s --max-time 5 ifconfig.me)
    if [ -z "$ip" ]; then
        echo "Your_Server_IP"
    else
        echo "$ip"
    fi
}

# --- 打印结束信息 ---
print_summary() {
    local public_ip="$1"
    local userName="$2"
    local passWord="$3"
    local desktop="$4"
    local input_method="$5"

    date "+【%Y-%m-%d %H:%M:%S】 Setup Completed." >> "$logPath"
    echo "Username: ${userName}  Password: ${passWord}" >> "$logPath"

    echo ""
    echo -e "${Green}+-------------------------------------------------------+${Font}"
    echo -e "${Green}|  Installation Completed!                              |${Font}"
    echo -e "${Green}+-------------------------------------------------------+${Font}"
    echo -e "  Desktop     : ${desktop}"
    echo -e "  System Lang : English (en_US.UTF-8)"
    echo -e "  Input       : ${input_method}"
    echo ""
    echo -e "  Address  : ${Green}${public_ip}${Font}"
    echo -e "  Username : ${Green}${userName}${Font}"
    echo -e "  Password : ${Green}${passWord}${Font}"
    echo -e "${Green}+-------------------------------------------------------+${Font}"
    echo -e "${Yellow}IMPORTANT: Please save your password now!${Font}"
    echo -e "Press any key to ${Red}REBOOT${Font} system..."

    read -n 1 -s -r -p ""
    reboot
}
