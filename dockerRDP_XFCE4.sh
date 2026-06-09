#!/bin/bash

# 开启遇到错误即刻退出的模式 (Fail-fast)
set -e

trap 'stty echo 2>/dev/null; exit 1' INT TERM

# ==========================================
# 1. 配置区域
# ==========================================
REMOTE_HOST="104.194.83.44"
REMOTE_PORT="10022"
REMOTE_USER="root"
RDP_USER="admin"
RDP_PASS="admin123"

echo "=================================================="
echo " 🚀 Phantom-Node 部署 (Debian-Slim 图形优化版)"
echo "=================================================="

# 获取密码
SSH_PASS=""
while [ -z "$SSH_PASS" ]; do
    read -s -p "🔑 请输入远程服务器 ($REMOTE_HOST) 的 SSH 密码: " SSH_PASS < /dev/tty
    echo ""
done

SHARE_DIR="$PWD/share_box"
mkdir -p "$SHARE_DIR"
chmod 777 "$SHARE_DIR"

# ==========================================
# [阶段一] 编译主容器
# ==========================================
echo "=> 正在生成轻量级 Debian Dockerfile..."
cat << EOF > Dockerfile
# 使用 debian 的 slim 极简版底包，大幅缩减体积
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# 1. 安装基础组件与 XFCE4 (抛弃 LXDE，剪切板完美)
RUN apt-get update && \\
    apt-get install -y --no-install-recommends \\
    xfce4 xfce4-terminal xrdp xorgxrdp dbus-x11 sudo python3 \\
    curl wget xz-utils ssh fuse ca-certificates locales \\
    fonts-wqy-zenhei firefox-esr sshpass \\
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \\
    && locale-gen \\
    && sed -i 's/#user_allow_other/user_allow_other/g' /etc/fuse.conf \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*

# 2. 创建桌面用户
RUN adduser --disabled-password --gecos "" $RDP_USER && \\
    usermod -aG sudo,ssl-cert $RDP_USER && \\
    echo "$RDP_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$RDP_USER

# 3. 桌面环境与 XRDP 权限配置
RUN echo "startxfce4" > /home/$RDP_USER/.xsession && \\
    chown $RDP_USER:$RDP_USER /home/$RDP_USER/.xsession && \\
    echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# 4. 智能重试隧道脚本 (循环监听密钥注入)
RUN { \\
    echo '#!/bin/bash'; \\
    echo 'while true; do'; \\
    echo '    if [ -f /root/.ssh/id_rsa ]; then'; \\
    echo '        echo "[Tunnel] 密钥就绪，尝试建立反向 RDP 隧道..."'; \\
    echo '        ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -p $REMOTE_PORT -CNR 3389:localhost:3389 $REMOTE_USER@$REMOTE_HOST'; \\
    echo '    fi'; \\
    echo '    sleep 10'; \\
    echo 'done'; \\
} > /usr/local/bin/auto-tunnel && chmod +x /usr/local/bin/auto-tunnel

# 5. 轻量化 Entrypoint
RUN { \\
    echo '#!/bin/bash'; \\
    echo 'mkdir -p /run/dbus'; \\
    echo 'dbus-uuidgen > /var/lib/dbus/machine-id'; \\
    echo 'ln -sf /var/lib/dbus/machine-id /etc/machine-id'; \\
    echo 'dbus-daemon --system'; \\
    echo ''; \\
    echo 'echo "$RDP_USER:$RDP_PASS" | chpasswd'; \\
    echo 'chown -R $RDP_USER:$RDP_USER /home/$RDP_USER'; \\
    echo 'rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp/xrdp-sesman.pid'; \\
    echo ''; \\
    echo '# 启动 XRDP'; \\
    echo '/etc/init.d/xrdp start'; \\
    echo ''; \\
    echo '# 后台挂载隧道'; \\
    echo '/usr/local/bin/auto-tunnel &'; \\
    echo ''; \\
    echo 'tail -f /dev/null'; \\
} > /entrypoint.sh && chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
EOF

echo "=> 开始构建 phantom-node 镜像 (请耐心等待)..."
docker rm -f phantom-node 2>/dev/null || true 
docker build -t phantom-node .
rm -f Dockerfile

echo "=> 正在启动常驻容器..."
CONTAINER_ID=$(docker run -d \
  --name phantom-node \
  --restart always \
  --shm-size 5g \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  --security-opt apparmor:unconfined \
  -v "$SHARE_DIR:/home/$RDP_USER/Desktop/share_box" \
  phantom-node)

# ==========================================
# [阶段二] 动态注入：在容器内部生成密钥并授权
# ==========================================
echo "=> 正在向容器内部下发免密指令 (全程内存操作)..."

docker exec -i phantom-node bash -c '
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    [ ! -f /root/.ssh/id_rsa ] && ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N "" -q
    read -r secret_pass
    echo "$secret_pass" > /tmp/p
    sshpass -f /tmp/p ssh-copy-id -o StrictHostKeyChecking=no -p '"$REMOTE_PORT"' '"$REMOTE_USER"'@'"$REMOTE_HOST"' >/dev/null 2>&1
    rm -f /tmp/p
' <<< "$SSH_PASS"

unset SSH_PASS

# ==========================================
# [阶段三] 生成便捷维护命令 (rekey.sh)
# ==========================================
REKEY_SCRIPT="$PWD/rekey.sh"
cat << EOF > "$REKEY_SCRIPT"
#!/bin/bash
echo "=================================================="
echo " 🔄 正在刷新 Phantom-Node 的远程 SSH 指纹"
echo "=================================================="
echo "=> 指令下发至 Docker 容器内清理指纹..."

docker exec phantom-node rm -f /root/.ssh/known_hosts /root/.ssh/known_hosts.old
docker restart phantom-node

echo "=> ✅ 刷新完成！"
EOF
chmod +x "$REKEY_SCRIPT"

echo "=================================================="
echo " 🎉 部署圆满完成！(Tor 浏览器兼容版)"
echo "=================================================="
echo " RDP 账户: $RDP_USER"
echo " RDP 密码: $RDP_PASS"
echo " 运行优势: 使用 Debian-Slim 底包，完美支持预编译商业软件"
echo "=================================================="
