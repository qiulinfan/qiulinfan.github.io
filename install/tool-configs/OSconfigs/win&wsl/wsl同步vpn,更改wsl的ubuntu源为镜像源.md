分享一个回到国内, 更新 wsl2 的时候出现的一点问题，，发现



## 同步 windows 里开的 vpn

注意到一件事情是:  windows 开了 vpn 之后 wsl 不会自动跟随.

所以我们得手动跟随



### 找到 wsl2 的可达 ip

注意, 并不是找到本机的 ip (真实 ip), 而是要找到 wsl2 的可达 ip .

wsl2 是通过一个虚拟网桥连接 Windows 主机的，内部有一套虚拟的 `vEthernet` 网卡（比如 `vEthernet (WSL)`）这张虚拟网卡通常只有 WSL 能看到)，

要在 wins 里用 powershell.

在 powershell 中输入

```shell
ipconfig
```

找到这一类网卡:

```shell
vEthernet (WSL)
```

记住它的 IP 地址:

```
以太网适配器 vEthernet (WSL (Hyper-V firewall)):

   连接特定的 DNS 后缀 . . . . . . . :
   本地链接 IPv6 地址. . . . . . . . : <LINK_LOCAL_IPV6>
   IPv4 地址 . . . . . . . . . . . . : windows-host.example
   子网掩码  . . . . . . . . . . . . : <SUBNET_MASK>
   默认网关. . . . . . . . . . . . . :
PS C:\Users\Rynne>
```

这里是 `windows-host.example`. 所以对于 **WSL2 内部来说，Windows 主机的真实可达 IP 是 `windows-host.example`**！



### 代理配置

我们需要做两件事, 一个是找到 vpn 的代理端口 (我这里的 clash verge, 代理端口 7890),

然后我们在 wsl 的 shell rc (我的是 `fish_config`) 设置 wsl2 ip : 端口, 作为 http 和 https 的 proxy.

```shell
set -x http_proxy http://windows-host.example:7890
set -x https_proxy http://windows-host.example:7890
```

此外, 我们需要在 clash 的配置中允许局域网, 确保确保监听局域网 IP!

找到 clash 配置的这一行, false 则改为 true.

```shell
allow-lan: true
```

### 测试是否成功

我们两重测试.

首先, 看看 google 是否能连接:

```shell
curl -x http://windows-host.example:7890 https://www.google.com
```

成功输出网页代码则成功



其次, 我们关闭代理时, 在 powershell 中得到的自己的 IP 应该是真实 ip, 开启时则是代理 ip；而在 wsl 的 shell 中. 得到的 ip 始终是代理 ip.

```shell
ipconfig
```



如果以后 Windows 的 WSL 网桥 IP 改了，也可以用命令动态获取：

```shell
set winip (ip route | grep default | awk '{print $3}')
```



## 更改 ubuntu source 为国内镜像

```shell
sudo apt update
```

用不了, 很多包不能 retrieve.

查看了一下 pin:

```shell
ping -c 3 archive.ubuntu.com
ping6 -c 3 archive.ubuntu.com
```

发现掉包率是 100%. 开了 VPN 之后也没用. 所以是被墙了.

遂检索发现: 对 ubuntu 系统相关的 retrieve 路径被 specify 在:

```shell
/etc/apt/sources.list
```

这个文件里. 我们只要把这个文件里所有的 `http://archive.ubuntu.com/ubuntu/` 和 `http://security.ubuntu.com/ubuntu/` 替换为国内的镜像源就可以了.

我使用的是 thu 的镜像



### 确认 ubuntu 版本

| 版本代号 | Ubuntu版本 |
| -------- | ---------- |
| `jammy`  | 22.04      |
| `noble`  | 24.04      |

我们这样确认一下:

```shell
lsb_release -a
```

我这里是 jammy. 因而全部换成 jammy 的镜像源.

直接 `sudo nano` 把这个文件内容改成:

```list
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
```

然后就可以正常使用 `sudo apt`.





### 额外: Launchpad 镜像

我这里为了安装 g++13 首先需要 launchpad.

这个也有 thu 镜像:

```shell
sudo sed -i 's|http://ppa.launchpad.net|https://launchpad.proxy.ustclug.org|g' /etc/apt/sources.list.d/ubuntu-toolchain.list

# 更新并安装 g++
sudo apt update
sudo apt install g++-13
```



强制使用 IPv4 (因为有些网络环境对 ipv6 支持不好)

```shell
echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
```
