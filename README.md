# OneKeyRdp: Linux VPS 一键桌面环境 (RDP)

**OneKeyRdp** 是一个专为 Linux VPS 设计的轻量级一键安装脚本，旨在快速部署图形化桌面环境并通过 Windows 自带的远程桌面连接（RDP）进行访问。

## 支持系统 (Supported OS)

| 发行版 | 版本 | 桌面环境 | 浏览器 | 包管理器 |
|--------|------|----------|--------|----------|
| **Debian** | 9+ | LXDE | Chrome | apt |
| **Ubuntu** | 18.04 - 22.04 | LXDE | Chrome | apt |
| **Ubuntu** | 20.04+ | LXDE | Chrome | apt |
| **CentOS** | 7 / 8 / Stream | XFCE | Chrome | yum / dnf |
| **RHEL / Rocky / AlmaLinux** | 8+ | XFCE | Chrome | dnf |
| **Fedora** | 36+ | XFCE | Chrome | dnf |
| **Arch Linux** / Manjaro | Rolling | LXDE | Chromium | pacman + yay |
| **openSUSE** | Leap / Tumbleweed | XFCE | Chromium | zypper |

## 核心功能 (Core Features)

*   **原生 RDP 体验**: 使用 XRDP 协议，直接使用 Windows 远程桌面连接，无需额外客户端。
*   **轻量级桌面**: LXDE / XFCE，资源占用极低，适合小内存 VPS (推荐 512MB+)。
*   **智能系统识别**: 基于 `/etc/os-release` 标准文件自动识别发行版，带有 `ID_LIKE` 和传统文件检测兜底。
*   **中文支持优化**:
    *   系统保持英文环境 (避免乱码)。
    *   预装中文字体（解决方块字问题）。
    *   预装中文输入法（Debian/Ubuntu: Fcitx, RHEL/Fedora/openSUSE: IBus）。
*   **开箱即用**:
    *   预装浏览器（Chrome 或 Chromium）。
    *   预装基础工具 (vim, git, wget, curl, net-tools)。
    *   自动配置 **2GB Swap**（防止内存不足导致崩溃）。
    *   自动设置时区为 **Asia/Shanghai**。
*   **安全增强**:
    *   创建非 root 的 sudo 用户用于远程登录。
    *   使用 `/etc/sudoers.d/` 安全管理权限。
    *   修复 Polkit 权限弹窗（兼容新旧 Polkit 格式）。
*   **凭据保存**: 用户名和密码自动保存到 `oneKeyRdp.log`，不怕漏看。

---

## 快速开始 (Quick Start)

### 方式一：一键安装 (推荐)

在您的 VPS 终端中执行以下命令（需要 root 权限）：

```bash
source <(curl -sL https://git.io/Jqfs7)
```

脚本将会：
1. 自动识别您的 Linux 发行版。
2. 更新系统软件包。
3. 创建一个新的 sudo 用户（随机密码）。
4. 安装桌面环境和浏览器。
5. 配置 XRDP 远程服务。
6. 安装完成后重启 VPS。

### 方式二：手动安装

```bash
git clone https://github.com/vsyour/onekeyrdp.git
cd onekeyrdp
bash linuxOneKeyRdp.sh
```

---

## 常见问题 (FAQ)

### Q1: 安装完成后如何连接？
1. 打开 Windows "远程桌面连接" (`mstsc`)。
2. 输入 VPS 的 **IP 地址**。
3. 输入脚本生成的用户名和密码（安装结束时显示，也保存在 `oneKeyRdp.log`）。

### Q2: 剪贴板无法复制粘贴？
```bash
sudo apt-get install clipit    # Debian/Ubuntu
```

### Q3: 如何切换中文输入？
- **Debian/Ubuntu**: `Ctrl + Space`
- **CentOS/Fedora/openSUSE**: `Super + Space` 或 IBus 托盘图标

### Q4: 如何修改 SSH 端口？
```bash
sed -i 's/#Port 22/Port 9922/g' /etc/ssh/sshd_config
systemctl restart sshd
```

### Q5: vim 鼠标无法复制？
```bash
sed -i 's/mouse=a/mouse-=a/g' /usr/share/vim/vim8*/defaults.vim
```

---

## 项目结构

```
onekeyrdp/
├── linuxOneKeyRdp.sh        # 入口脚本 (OS 检测 + 分发)
├── common.sh                # 公共函数库 (用户管理, Swap, Polkit修复等)
├── debian.sh                # Debian / Ubuntu < 20
├── ubuntu2.sh               # Ubuntu 20.04+
├── centos.sh                # CentOS / RHEL / Rocky / AlmaLinux
├── fedora.sh                # Fedora
├── arch.sh                  # Arch Linux / Manjaro
├── opensuse.sh              # openSUSE Leap / Tumbleweed
└── README.md                # 本文件
```

## 截图预览

![OneKeyRdp Desktop](https://i.imgur.com/h8c1j8p.png)

## 说明
本项目由 vksec 维护。QQ群：397745473

**免责声明**: 本工具仅供学习和合法的系统管理使用，请勿用于非法用途。
