# onekeyrdp
linux 一键RDP
debian linux 一键开启RDP远程登陆
使用windows远程连接linux桌面环境


QQ群： 397745473

vultr OS: CentOS/Ubuntu/Debian 测试通过

vps推荐 https://www.vultr.com/?ref=8955885-8H (新用户充10$得110$)

执行命令:
```
source <(curl -sL https://git.io/Jqfs7)
```
```
常见问题:
1. 剪贴板无法使用可以尝试执行:
apt-get install clipit
更多参考: https://wiki.debian.org/LXDE/Discussion

2. 增加SWAP
source <(curl -sL https://raw.githubusercontent.com/vsyour/onekeyrdp/main/swap.sh)
或者
dd if=/dev/zero of=/var/swapfile bs=1M count=2048 && /sbin/mkswap /var/swapfile && /sbin/swapon /var/swapfile && chmod 0600 /var/swapfile && echo "/var/swapfile swap swap defaults 0 0" >>/etc/fstab

3. 渗透工具安装
source <(curl -sL https://git.io/pentools)

4. 修改SSH端口
sed -i 's/#Port 22/Port 9922/g'  /etc/ssh/sshd_config 

#允许root认证登录
sed -i 's/PermitRootLogin no/PermitRootLogin yes/g'  /etc/ssh/sshd_config 
#允许密码认证
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g'  /etc/ssh/sshd_config

# vim 模式修复
sed -i 's/mouse=a/mouse-=a/g' /usr/share/vim/vim82/defaults.vim

5. 关闭删除ufw防火墙
ufw disable && apt-get remove ufw -y

```


安装完成后可以直接使用windows远程登陆工具连接了

![安装完成](https://i.imgur.com/h8c1j8p.png)
