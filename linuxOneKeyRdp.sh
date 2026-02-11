#!/bin/bash
#
# OneKeyRdp — One-click RDP Desktop for Linux VPS
# Supports: Debian, Ubuntu, CentOS, RHEL, Rocky, AlmaLinux, Fedora, Arch, openSUSE
#
# Copyright © 2015-2099 vksec <QQ Group: 397745473>
# https://www.vksec.com
#

set -e

Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Font="\033[0m"

# GitHub raw base URL for remote execution
REMOTE_BASE="https://raw.githubusercontent.com/vsyour/onekeyrdp/main"

# --- Detect if running locally (cloned repo) or via curl ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" 2>/dev/null && pwd)"
if [ -f "${SCRIPT_DIR}/debian.sh" ]; then
    RUN_MODE="local"
else
    RUN_MODE="remote"
fi

# --- Helper: load a distro script ---
run_script() {
    local script_name="$1"
    local arg="$2"
    if [ "$RUN_MODE" = "local" ]; then
        echo -e "${Green}[*] Running local script: ${script_name}${Font}"
        source "${SCRIPT_DIR}/${script_name}" "$arg"
    else
        echo -e "${Green}[*] Downloading and running: ${script_name}${Font}"
        source <(curl -sL "${REMOTE_BASE}/${script_name}") "$arg"
    fi
}

# --- OS Detection using /etc/os-release (standard on all modern distros) ---
checkSystem() {
    release=""
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian)
                release="debian"
                ;;
            ubuntu)
                # Ubuntu 20+ uses a different script
                major_ver="${VERSION_ID%%.*}"
                if [ -n "$major_ver" ] && [ "$major_ver" -ge 20 ] 2>/dev/null; then
                    release="ubuntu2"
                else
                    release="debian"  # Ubuntu < 20 uses the debian path
                fi
                ;;
            centos|rhel|rocky|almalinux)
                release="centos"
                ;;
            fedora)
                release="fedora"
                ;;
            arch|manjaro|endeavouros)
                release="arch"
                ;;
            opensuse-leap|opensuse-tumbleweed|sles)
                release="opensuse"
                ;;
            *)
                # Try ID_LIKE as fallback
                case "$ID_LIKE" in
                    *debian*|*ubuntu*)
                        release="debian"
                        ;;
                    *rhel*|*centos*|*fedora*)
                        release="centos"
                        ;;
                    *arch*)
                        release="arch"
                        ;;
                    *suse*)
                        release="opensuse"
                        ;;
                esac
                ;;
        esac
    fi

    # Legacy fallbacks for very old systems without /etc/os-release
    if [ -z "$release" ]; then
        if [ -f /etc/redhat-release ]; then
            release="centos"
        elif [ -f /etc/debian_version ]; then
            release="debian"
        elif [ -f /etc/arch-release ]; then
            release="arch"
        elif [ -f /etc/SuSE-release ]; then
            release="opensuse"
        fi
    fi
}

# --- Main ---
echo ""
echo -e "${Green}+----------------------------------------------------------------------${Font}"
echo -e "${Green}| OneKeyRdp — One-click RDP Desktop Environment for Linux VPS${Font}"
echo -e "${Green}| Supported: Debian / Ubuntu / CentOS / RHEL / Rocky / Alma / Fedora / Arch / openSUSE${Font}"
echo -e "${Green}| Project: https://github.com/vsyour/onekeyrdp${Font}"
echo -e "${Green}+----------------------------------------------------------------------${Font}"
echo ""

checkSystem

if [ -z "$release" ]; then
    echo -e "${Red}[ERROR] Unable to detect your Linux distribution.${Font}"
    echo -e "${Red}        Supported: Debian, Ubuntu, CentOS, RHEL, Rocky, AlmaLinux, Fedora, Arch, openSUSE${Font}"
    echo -e "${Red}        If you believe this is an error, please report to QQ Group: 397745473${Font}"
    exit 1
fi

echo -e "${Green}[*] Detected OS: ${release}${Font}"
echo ""

case "$release" in
    debian)
        run_script "debian.sh" "debian"
        ;;
    ubuntu2)
        run_script "ubuntu2.sh" "ubuntu"
        ;;
    centos)
        run_script "centos.sh" "centos"
        ;;
    fedora)
        run_script "fedora.sh" "fedora"
        ;;
    arch)
        run_script "arch.sh" "arch"
        ;;
    opensuse)
        run_script "opensuse.sh" "opensuse"
        ;;
    *)
        echo -e "${Red}[ERROR] Unsupported distribution: ${release}${Font}"
        exit 1
        ;;
esac
