## 0. 装个中文的输入法

最重要,,

我选择的是 google 拼音, 配合 Fcitx 框架.

```shell
sudo apt update
sudo apt install fcitx fcitx-googlepinyin fcitx-config-gtk
im-config -n fcitx
```

然后重启.

重启完之后启动配置工具

```shell
fcitx-config-gtk3
```

1. 点击左下角的 “+”
2. 搜索 “Google Pinyin”
3. 选中后添加

然后就可以用了. 切换 英文源和 Google Pinyin 是 Ctrl + Space, 在 Google pinyin 内切换英文是 shift.
### 切换为全部使用 half punc, 以及根据 frequency 来选 candidate

我的习惯: 更改为全部都用 half punc 而不是全标点.

方法:

打开 google pinyin 配置文件:
```shell
nano ~/.config/fcitx/conf/googlepinyin.conf
```

然后加上

```ini
[Punctuation]
FullWidthPunc=False
```

就好了.



然后: google 拼音是支持根据历史输入 frequency 来选词的. 我们 enable 它:

```shell
nano ~/.config/fcitx/conf/googlepinyin.conf
```

输入:

```ini
[General]
UseUserDict=True
AdjustOrder=True
SaveUserDictImmediately=True
```



### shift 切换中英文

```shell
fcitx-config-gtk3
```

在 **“全局配置 (Global Config)”** 找到一行叫：

```
Trigger Input Method
```

点击右边的快捷键栏, 然后按下 **Shift** 键即可.





## 1. 配置 ssh 来 clone github repo, 以及安装 github desktop linux 版

```sh
ssh-keygen -t ed25519 -C "rynnefan@gmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

得到 pub. 放进 github 配置

然后就可以 clone 自己的 git repos 了.



然后, 我的习惯是装一个 Github Desktop. 比起 GitKraken 它最大的优点就是可以操作 private 仓库 (GitKraken 居然操作个 private 仓库要付钱,,, 这已经是不可用了)

不过, 没有官方版本, 而是别人开源移植的.

在这里: https://github.com/shiftkey/desktop/releases/tag/release-3.4.13-linux1



(差点忘了, 得装个 git. `sudo apt install git`)



## 2. 安装 fish (shell) 和 kitty (terminal)

### fish

反正我不喜欢用 bash 和原生的 gnome terminal.

必要的配置都装上

fish:

```sh
sudo apt install fish
which fish
```

输出肯定是 `/usr/bin/fish`.

我们装好之后查看它在不在可用列表:

```shell
cat /etc/shells
```

不在的话加上:

```shell
which fish | sudo tee -a /etc/shells
```

然后设为默认:

```shell
chsh -s $(which fish)
```



### kitty

#### 下载

最主要的原因是原生的 gnome terminal 不支持选中文字时 ctrl c 不 kill process 而是复制, 以及 ctrl v. (可能可以自己配置, 我没了解过, 但是我知道 kitty 很好)

```shell
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
kitty --version
```



验证:

```shell
which kitty
kitty --version
```

输出: /home/qiulin/.local/kitty.app/bin/kitty

kitty 0.43.1 created by Kovid Goyal.



因为 `~/.local/kitty.app` 不是默认 PATH 中的系统目录，所以你需要在 `/usr/local/bin` 或 `/usr/bin` 创建链接。

推荐：

```shell
sudo ln -s ~/.local/kitty.app/bin/kitty /usr/local/bin/kitty
sudo ln -s ~/.local/kitty.app/bin/kitten /usr/local/bin/kitten
```

> `/usr/local/bin` 是给用户级程序用的安全目录, 不会被系统覆盖

这样在终端直接输入

```
kitty
```

就能启动新版本的 kitty



#### pin to dock

这里教一下怎么把它放进侧边:

首先创建一个 desktop 文件:

```shell
mkdir -p ~/.local/share/applications
cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
```

然后编辑它

```
nano ~/.local/share/applications/kitty.desktop
```

把里面的这两行改成你的实际路径:

```
Exec=/home/qiulin/.local/kitty.app/bin/kitty
Icon=/home/qiulin/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png
```

同时确认这几行存在（有时旧版本没有）：

```
Categories=System;TerminalEmulator;
StartupNotify=true
StartupWMClass=kitty
```

保存后退出

最后更新 desktop 数据库:

```
update-desktop-database ~/.local/share/applications
```

然后就可以在应用菜单找到它, pin 它了.



#### 设置为默认 temrinal

Ubuntu 用 **`update-alternatives`** 管理默认终端程序:

```shell
sudo update-alternatives --config x-terminal-emulator
```

你会看到类似：

```
[sudo] password for qiulin:
There are 2 choices for the alternative x-terminal-emulator (providing /usr/bin/x-terminal-emulator).

  Selection    Path                                     Priority   Status
------------------------------------------------------------
  0            /home/qiulin/.local/kitty.app/bin/kitty   100       auto mode
  1            /home/qiulin/.local/kitty.app/bin/kitty   100       manual mode
* 2            /usr/bin/gnome-terminal.wrapper           40        manual mode

Press <enter> to keep the current choice[*], or type selection number: 1
update-alternatives: using /home/qiulin/.local/kitty.app/bin/kitty to provide /usr/bin/x-terminal-emulator (x-terminal-emulator) in manual mode
```

输入 `2` (Kitty 对应编号) enter 就可以选择默认终端.
或者 pin 一下它.

#### 额外注意

在 linux 的 terminal 里, ctrl C 并不复制选中文本. 我们要复制的话是 Ctrl Shift C.

#### 配置外观

我们可以配置它的外观:

```shell
code ~/.config/kitty/kitty.conf
```

config 方法在: https://sw.kovidgoyal.net/kitty/conf/

我的:

```config
# kitty.conf

font_family JetBrains Mono
font_size 12.5

cursor_text_color #111111
cursor_shape block

background_image ~/Documents/Github/qiulinfan.github.io/install/tool-configs/wallpapers/02_6.jpg

# 图片布局 (常用 tiled, scaled, cover, contain)
background_image_layout tiled
background_image_linear yes
background_opacity 1.0
background #000000
foreground #eeeeee
background_tint 0.75
background_tint_gaps 1.0


selection_foreground #000000
selection_background #fffacd

enable_audio_bell no

# 主题
include themes/nord.conf
```







## 4. VSCode, typora, sublime text 等

code:

```shell
sudo apt update
sudo apt install wget gpg
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
sudo sh -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt install apt-transport-https
sudo apt update
sudo apt install code
```

typora 和 sublime text 直接找官网 .deb 就行

装上 VSCode 之后传一下 config file.



## 5. 调整快捷键

由于笔记本会缺少 printscreen 键

我会把  F6 映射到 interactive 截图.

在 setting -> keyboards -> View and Customize Shortcuts 处改.











## 6. 调整 GRUB 启动菜单

这个菜单的字实在太小了..

我们可以定制它:

**文件路径:** `/etc/default/grub`

1. 打开配置文件：

   ```
   sudo nano /etc/default/grub
   ```

2. 主要选项：

   ```
   GRUB_TIMEOUT=5             # 菜单停留秒数 (0表示直接进入系统)
   GRUB_DEFAULT=0             # 默认启动项 (0是第一个)
   GRUB_BACKGROUND="/boot/grub/mybg.png"  # 自定义背景图
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"  # “quiet splash”控制显示信息与动画
   ```



#### 自定义字体和大小

默认的字体会非常小.

我们下载:

```shell
sudo grub-mkfont -s 32 -o /boot/grub/fonts/DejaVuSansMono32.pf2 /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf
```

然后打开 /etc/default/grub 放入:

```
GRUB_FONT=/boot/grub/fonts/DejaVuSansMono32.pf2
```





#### 自定义背景图片

甚至可以自己加背景. 这个真的赞

比如我 download 一个 miku.jpg

然后

```shell
sudo apt install imagemagick -y
convert ~/Downloads/miku.jpg ~/Downloads/miku.png
```

变为 png

然后

```shell
sudo cp ~/Downloads/miku.png /boot/grub/mybg.png
```

顺利把它移动到 /boot/grub 下面.

然后放进 /etc/default/grub 就可.

```
GRUB_BACKGROUND="/boot/grub/mybg.png"
```



#### 更新配置

可能有的朋友 (我自己) 会担心: 这个 reboot 的界面要是不对那不是炸了吗

但是其实它有充分的安全保护.

首先有一个指令可以验证你的内容对不对. 我们验证一下语法没问题:

```shell
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

其次, 我们即便写的有问题, 在 GRUB 里也可以按 c 打开 command line 再当场改. 所以不用担心.

最后输入:

```shell
sudo update-grub
```

然后重启, 便会生效.





## 7. 美化登录界面 `gdm` (GNOME Display Manager)

#### 改 GDM 登录界面壁纸

这一步风险低、效果立竿见影

比如刚才那张 `miku.png`:

```
sudo cp ~/Downloads/miku.png /usr/share/backgrounds/
```

```
sudo mkdir -p /etc/dconf/db/gdm.d
sudo nano /etc/dconf/db/gdm.d/01-background
```

写入以下内容：

```
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/miku.png'
```

然后应用更改:

```shell
sudo dconf update
sudo systemctl restart gdm
```


## 其他环境

### python

```shell
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
```

```shell
bash ~/Miniconda3-latest-Linux-x86_64.sh
# Miniconda3 will now be installed into this location: /home/username/miniconda3
```

在 config 文件里:

```shell
set -gx PATH /home/(username)/miniconda3/bin $PATH
```

然后 source 一下. note 如果用的是我的 dotfiles 的话这个已经写在 fish_config 里了.
