My .vimrc settings and VSCode vim mode settings.

[TOC]

# Guide

我的配置的使用方法：

## vim

### normal mode

1. <Space> 表示切换 Insert mode
2. w 和 s 表示向上和向下移动一行

2. a 和 d 表示向左和向右移动一个单词

3. 数字 + w/s/a/d 表示 上下左右
4. l+l 表示删除一行（光标所在）
5. <Ctrl-b> 表示打开和关闭 Nerd tree

### insert mode

1. <Shift-x> + <Shift-c> 表示切换 normal mode
2. Tab 当有补全提示时表示自动补全，没有补全提示时表示空两格
3. <Ctrl-b> 打开和关闭 nerd tree
4. 输入 `:`

### Nerd tree

1. <Ctrl-b> 打开和关闭 nerd tree
2. w/s 上下移动
3. <Enter> 表示进入某个文件
4. m 打开菜单模式，之后按 a 可以输入文件名，创建新文件

### Command Mode

1. normal mode 下 `:` 打开 command mode，可以正常运行 terminal 上所有 command.

## VSCode-vim

其他都相同

### mode shift

1. normal mode 下 <Shift-v> 切换 Visual mode
2. normal mode 下 <Space> 切换 Insert mode
3. Visual mode 下 <Shift-x> + <Shift-c> 表示切换 normal mode
4. Visual mode 下 <Space> 表示切换 insert mode
5. insert mode 下 <Shift-x> + <Shift-c> 表示切换 normal mode

## vim 配置文件注意事项

如果要 copy 我的配置文件的话，在复制粘贴好之后需要跑一些 commands:

1. 下载 vim plug in

   Unix, Mac, Linux:

   ```shell
   curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
   ```

   Win Powershell:

   ```shell
   https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim |`
       ni $HOME/vimfiles/autoload/plug.vim -Force
   ```

2. 下载 node.js 18.x

   mac:

   ```shell
   brew install node@18
   brew link node@18 --force --overwrite
   ```

   linux

   ```shell
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

3. ```shell
   sudo npm i -g yarn
   ```

4. ```
   cd .vim/plugged/coc.nvim/
   ```

   ```shell
   yarn install
   ```

5. 打开 `.vimrc`，进入命令模式，输入：

   ```shell
   CocInstall coc-clangd
   ```

6. 随便在哪里用 vim 建立一个 `test.cpp`，进入其中

   ```shell
   vim test.cpp
   ```

   然后打开命令模式

   ```cmd
   CocCommand clangd.install
   ```

   然后 `:w` 写入，`so%` source 一下，然后进入命令行模式

   ```cmd
   PlugInstall
   ```
