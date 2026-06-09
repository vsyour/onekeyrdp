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
echo " 🚀 Phantom-Node 全自动安全部署 (容器内存注入版)"
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
# [阶段一] 编译与启动主容器 (没有任何外部密钥挂载)
# ==========================================
echo "=> 正在生成轻量级 Dockerfile..."
cat << EOF > Dockerfile
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && \\
    apt-get install -y --no-install-recommends \\
    lxde xrdp xorgxrdp dbus-x11 sudo python3 curl wget xz-utils ssh \\
    fuse ca-certificates locales fonts-wqy-zenhei firefox-esr sshpass \\
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \\
    && locale-gen \\
    && sed -i 's/#user_allow_other/user_allow_other/g' /etc/fuse.conf \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --gecos "" $RDP_USER && \\
    usermod -aG sudo,ssl-cert $RDP_USER

RUN echo "startlxde" > /home/$RDP_USER/.xsession && \\
    chown $RDP_USER:$RDP_USER /home/$RDP_USER/.xsession && \\
    rm -f /etc/xdg/autostart/lxpolkit.desktop && \\
    rm -f /usr/bin/lxpolkit    

RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# 智能重试隧道脚本 (由于密钥是启动后注入的，它会不断循环等待密钥就绪)
RUN { \\
    echo '#!/bin/bash'; \\
    echo 'while true; do'; \\
    echo '    if [ -f /root/.ssh/id_rsa ]; then'; \\
    echo '        echo "[Tunnel] 密钥就绪，尝试建立反向 RDP 隧道..."'; \\
    echo '        # 注意这里去掉了 -f，让它保持在前台运行。如果隧道断开，会重新执行 while 循环重连'; \\
    echo '        ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -p $REMOTE_PORT -CNR 3389:localhost:3389 $REMOTE_USER@$REMOTE_HOST'; \\
    echo '    fi'; \\
    echo '    sleep 10'; \\
    echo 'done'; \\
} > /usr/local/bin/auto-tunnel && chmod +x /usr/local/bin/auto-tunnel

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
    echo 'service ssh start'; \\
    echo '/etc/init.d/xrdp start'; \\
    echo ''; \\
    echo '# 将隧道挂在后台循环监听'; \\
    echo '/usr/local/bin/auto-tunnel &'; \\
    echo ''; \\
    echo 'tail -f /dev/null'; \\
} > /entrypoint.sh && chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
EOF

echo "=> 开始构建 phantom-node 镜像..."
docker rm -f phantom-node 2>/dev/null || true 
docker build -t phantom-node .
rm -f Dockerfile

echo "=> 正在启动常驻容器..."
CONTAINER_ID=$(docker run -d \
  --name phantom-node \
  --restart always \
  --shm-size 2g \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  --security-opt apparmor:unconfined \
  -v "$SHARE_DIR:/home/$RDP_USER/Desktop/share_box" \
  phantom-node)

# ==========================================
# [阶段二] 动态注入：在容器内部生成密钥并授权
# ==========================================
echo "=> 正在向容器内部下发免密指令 (全程内存操作，不落宿主机磁盘)..."

docker exec -i phantom-node bash -c '
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    
    # 1. 在容器内部生成专属密钥
    [ ! -f /root/.ssh/id_rsa ] && ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N "" -q
    
    # 2. 读取从宿主机传来的流密码，推送到服务器
    read -r secret_pass
    echo "$secret_pass" > /tmp/p
    sshpass -f /tmp/p ssh-copy-id -o StrictHostKeyChecking=no -p '"$REMOTE_PORT"' '"$REMOTE_USER"'@'"$REMOTE_HOST"' >/dev/null 2>&1
    
    # 3. 销毁临时痕迹
    rm -f /tmp/p
' <<< "$SSH_PASS"

# 清空宿主机的内存密码
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
echo " 🎉 部署圆满完成！(云平台极致安全版)"
echo "=================================================="
echo " RDP 账户: $RDP_USER"
echo " RDP 密码: $RDP_PASS"
echo " 密钥存储: 仅限容器内部 (Ephemeral Layer)"
echo " 安全状态: 外部零挂载，如果容器被删除，密钥将永久销毁。"
echo " 运行状态: 只要容器存在，哪怕工作区重启也能自动连通。"
echo "=================================================="
