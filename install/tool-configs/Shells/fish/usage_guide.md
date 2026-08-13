# 使用指南

## install

mac:

```shell
brew install fish # sudo apt install fish
```

下完查一下:

```shell
which fish
```

显示出

```shell
/opt/homebrew/bin/fish   # for Apple Silicon. /usr/bin/bash for linux
```

linux:

```bash
sudo apt install fish
chsh -s /usr/bin/fish
```



## 加入 shells 列表并调为默认

用 editor 打开 `/etc/shells` 文件:

```shell
sudo vim /etc/shells
```

(不会用: 按 `i` 进入编辑模式 -> 写完按 `esc`  -> 输入 `:wq` 保存)

然后我们在这个文件末尾加上刚刚 which 到的 fish 的路径

```shell
/opt/homebrew/bin/fish   # for mac
/usr/bin/fish  # for linux
```

就把 fish 加入了系统认可的 shells 中

然后我们使用这个指令, 把 fish 调为默认 shell

```shell
chsh -s /opt/homebrew/bin/fish
```



## 配置 fish

可以直接

```bash
cd ~
git clone git@github.com:qiulinfan/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash initial.sh
```

一键迁移我的配置

如果要手动配置的话:

### 第一种方法: fish 的官方 config gui

我们输入

```shell
fish_config
```

会直接在我们的默认浏览器弹出一个 config 选择方案. 里面可以调颜色字体函数以及 key binding 等等

但我感觉可定制性还是太小. 而且比较慢. 所以我们当然是选择自己写 config 文件 (智将)

### 第二种方法: `code ~/.config/fish/config.fish`

我们用 editor 编辑 config 文件.

注意我们 VSCode 的指令 `code`, 它很可能现在是不知道的. 所以我们要先

```shell
set -gx PATH /opt/homebrew/bin /usr/local/bin $PATH
```

linux:

```shell
set -gx PATH /usr/bin /usr/local/bin $PATH
```

然后才能使用 `code`. 但是注意到这是临时的, 结束掉这个 terminal 就又没了. 所以我们要在 `~/.config/fish/config.fish` 里面也加上这一行 `set -gx PATH /opt/homebrew/bin /usr/local/bin $PATH`, 这样就永久识别了.

不要忘记 config 完要 source:

```shell
source ~/.config/fish/config.fish
```

我附上了我自己的 config 文件.
