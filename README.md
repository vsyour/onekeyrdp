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

2. 增加SWAP
bash https://raw.githubusercontent.com/vsyour/onekeyrdp/main/swap.sh

更多参考: https://wiki.debian.org/LXDE/Discussion
```


安装完成后可以直接使用windows远程登陆工具连接了

![安装完成](https://i.imgur.com/h8c1j8p.png)



问题(待解决)：
2021年03月05日 测试 Ubuntu 20.10 x64 失败,提示: Oh no! Something has gone wrong
