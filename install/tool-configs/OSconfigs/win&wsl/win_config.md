# What to do with a new computer (win)

今天买了新电脑，配置它的时候不禁想整理一下这个问题.

(以下文字全是个人意见.)

BTW 不止买电脑. 我感觉也可以作为一个配置备忘录以防忘记自己配了些啥

下面一直到底, 实测, 一整套操作 1.5 小时就可以全部配置完 (除了如果要装 latex 的话要等一会)

## 输入法, 浏览器

### language pack downloading

第一步绝对是下载一下自己需要的 language pack. 首先打字爽了再说. 中英日都配一个比较好. 切换方便

注意在右下角右键 setting -> general -> use English punctuations when in Chinese input mode

不过我现在都用微信输入法(

### chrome

我觉得最主要的还是先下载个浏览器. 下载其他东西通常都需要经过浏览器访问官网. 但是 edge 看着真的很花里胡哨且累眼, 一秒都不想用. 所以我会选择下一个 chrome, 然后 sync 一下我的账号. (账号的 setting 一同步就开始习惯起来了)



### logi GHub

下了 chrome 之后第一件事情是去 logi 官网下一个 GHub 调一下鼠标的灵敏度.

这真太重要了. 鼠标灵敏度不习惯跟吃使一样难受



## 外观

很 personal. 我的第三件事情是下 steam 然后下 wallpaper engine. 不用自己常用的壁纸真的很难使用这个电脑.

btw 启动覆盖 Lock screen + 允许 sleep 时运行还可以解锁覆盖屏保小连招. 不过刚开机的时候有时候偶尔不会启动 (可能是 synchronization 问题)，最好自己也设一个文件夹 slide.



cursor 外观我用的是:

https://www.rw-designer.com/cursor-set/hollow-knight

注意这些可以免费的贴图文件的网站很多都一堆广告. 千万别点广告里面以假乱真的 download 点了就是流氓软件.

(所以我偷到这个 repoi 里了)



## dev

### 编辑器: VSCode, typora, sublime..

个人习惯:

- VSCode for development
- Typora for notetaking
- sublime text 查看和随手编辑各种文本文件 (我感觉 sublime 在 windows 的生态位类似 vim 在 linux

[VSCode 配置](../../Editors)



### github desktop

喜欢用这个 GUI. 不喜勿喷(



### 更改一下 file explorer 的文件布局

我的习惯是:

- tiles 布局;
- group by type;
- show filename extension 和 hidden items

个人认为这样查看的信息最多并且最 organized

点击上面三个点 -> options -> view -> 把当前的布局应用到全部文件夹可以应用到同类型的布局



### 下个新版 powershell

老版的太不智能了. powershell 7 还挺不错的

https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5

````powershell
winget install --id Microsoft.PowerShell --source winget
````

可以自己配置 config.

```
code  C:\Users\<用户名>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

我的 config:

```shell
Import-Module PSReadLine

# 启用预测补全
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView

# Tab → 切换下一个预测
Set-PSReadLineKeyHandler -Key Tab -Function NextSuggestion
```

目前用的是 listview 模式的



### windows 的包管理器 (我用 chocolatey)

不下载包管理器的话 windows 安装什么软件都要上网找然后手动添加环境变量

所以搞一个 (装这个要用 admin 权限开 terminal)

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

搞完之后就可以 unix-like 地下载一些软件了

```powershell
choco install make
make --version
choco install git
git --version
choco install wget
```

(注意下载完之后 `git --version` 不一定直接反应. 可能需要关掉新开一个 terminal 才能识别.)



## wsl

最重要的就是先把 wsl 下了.

先在 turn windows features on or off -> 开启 WSL , Virtual Machine Platform

(不要开 hyperv)

```shell
wsl --install
wsl --install -d Ubuntu-26.04
```

看看装好没:

```powershell
wsl -l -v
```

这个时候关闭 teminal 再打开就能看到新建窗口的 list 里面有 ubuntu 了.





### 代理

哦对了

如果你开了 vpn 代理 (possibly 你需要)

那么你安装完一打开 ubuntu 会看到

```
wsl: A localhost proxy configuration was detected but not mirrored into WSL. WSL in NAT mode does not support localhost proxies.
```

因为 WSL 运行在 NAT 下, 不能直接使用 Windows 的 localhost.

解决方法也很简单

编辑

```
C:\Users\<用户名>\.wslconfig
```

加入：

```
[wsl2]
networkingMode=mirrored
```

然后在 powershell 端:

```
wsl --shutdown
```

重新打开 WSL 就行了. (这个问题以前老麻烦了. 我记得就在这个 repo 还记录过以前的解决方法. 不过现在 wsl 2.2+ 之后出了这个(早该出了..)快捷的支持就方便了)



### 装库

现在 wsl 才算装好.

可以切 bash 下载一些常用的必要软件.

(直接见 [linux 配置](../linux/linux_config.md), 但是比起 ubuntu desktop 还是丐很多. 没那么多好配置的所以这里随便配配也差求不多

```shell
sudo apt update
sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
sudo apt install g++-13 make rsync wget git ssh gdb tree unzip
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100
sudo update-alternatives --config g++
sudo apt install fish
sudo apt install vim
```

(这里没装 nvim 但是我一般都用 nvim. 安装稍微要麻烦一点, 见 [nvim 安装流程](C:../../Editors/vim&nvim\nvim\nvim.md))

配置一下 github 需要用到的 ssh key

```shell
sudo apt install openssh-client
ssh-keygen -t ed25519 -C "rynnefan@umich.edu"
cat ~/.ssh/id_ed25519.pub
```

结果复制到 github 的 ssh

### configs (用 dotfile)

各种.. 比如 fish config, vimrc, gitconfig 等等. 不一一说了我的就放在 https://github.com/qiulinfan/dotfiles

(如果真的有人在用我的配置的话,, 记得有些是不一样的, 比如 git 的邮箱和名字肯定不一样,,)



## 其他环境

### python

scripting language 还是非常必要的

我这里在 windows 和 wsl 都下一个 miniconda 的包管理器



Windows:

这个不要用 choco 装.

```powershell
Invoke-WebRequest -Uri "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe" -OutFile ".\Miniconda3-latest-Windows-x86_64.exe"
```

然后搜索栏里搜索 mini.. 找到刚下好的 graphic installer, 一路点 next, 在 advanced 选项里 Add Miniconda3 to my PATH environment variable, register miniconda3 as default python 3.13, 以及 clear the packager cache upon completion

如果不小心没选 add miniconda3 to my PATH environment variable 或者选了它没用(其实有可能的) 的话

这个东西位置 (默认) 安装在

```
C:\Users\<username>\miniconda3
```

那就只能手动把这三个东西加进去了:

```
C:\Users\<username>\miniconda3
C:\Users\<username>\miniconda3\Scripts
C:\Users\<username>\miniconda3\Library\bin
```

(记得改 username)

我的:

```
[Environment]::SetEnvironmentVariable(
  "Path",
  [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\Users\rynne\miniconda3;C:\Users\rynne\miniconda3\Scripts;C:\Users\rynne\miniconda3\Library\bin",
  [EnvironmentVariableTarget]::User
)
```

wsl: 见[这里](../linux/linux_config.md)



然后可以创建环境

```shell
conda create -n myenv python=3.13
```

查看:

```shell
conda env list
```

而 windows 的直接用 anaconda powershell 就行.

还可以下载额外 GUI:

```shell
conda install jupyterlab
conda install anaconda-navigator
```



### powertoy: keyremap 和 dock

由于小键盘没有 printscreen, win+shift+s 组合键又烦 (

我的话会一个 powertoy, 重新映射一下键, 把 f6 映射到 printscreen

(14 寸笔记本我一般都加这个)

https://learn.microsoft.com/en-us/windows/powertoys/install?tabs=gh%2Cextract-094

也可以 powershell 安装:
```powershell
winget install --id Microsoft.PowerToys --source winget
```

然后把 powertoys 加入开机自启动:

Win+R -> 输入 shell:startup 打开 Startup 文件夹 -> 把 powertoys 放进去

安装好了之后:

- 开启 keyboard manager

- 打开 Powertoy -> input and output -> keyboard manager (先 enable) -> remap a shortcut

我会把

- F6 -> Print Screen
- F5 -> Ctrl + Alt + M (for mathpix)



powertoy 另外一个好用的功能是 dock 可以实时监测内存, cpu, gpu 占用率和网络传输速率以及布置一些快速 commands.

- 点开 system tools -> command palette -> settings
- dock -> enable dock



### memory management: ramMap

内存管理. 主要有些厂商开机占有率太高了. 大概率是一些服务 start up 的原因; 再加上 16 GB 的 ram, 雪上加霜了属于.

首先少开点 app 上的 startup, 其次对系统的 startup processes 可以用 RamMap 清一下

我会:下载一个 RamMap 管理内存: https://learn.microsoft.com/en-us/sysinternals/downloads/rammap

这样开机跑一下内存占用率就从 60% 降低到了 25%.



### latex

请参见 https://github.com/qiulinfan/localLatexenv

顺便我会下一个 mathpix: https://mathpix.com

快速公式转 latex/md 的工具.




### extra: nvdia app 下载驱动

记得重新装一下. 根据机型找官网的驱动

不然多显示器可能出问题



### 一些免费软件

像素图绘制: Pixel Studio, steam 下载

音频剪辑: ocenaudio, 免费开源

pdf 页面编辑: pdfgear

压缩和解压缩器: 7-zip
