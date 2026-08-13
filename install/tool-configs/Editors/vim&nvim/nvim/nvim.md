## 安装 nvim

```bash
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
```

(注意 apt 安装的是老版本的. 所以我们用 curl 安装. 安装完之后把压缩包删了

```bash
rm -rf nvim-linux-x86_64.tar.gz
```

)

```bash
sudo apt update
tar xzf nvim-linux-x86_64.tar.gz
sudo mv nvim-linux-x86_64 /opt/nvim-linux-x86_64
sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
```

然后 验证. 版本应该是 0.11+

```bash
which nvim
nvim --version | head -n 1
nvim --headless --clean +'lua print(vim.env.VIMRUNTIME)' +qa
# /usr/local/bin/nvim
```



### 注意: runtime

注意:  Debian 包数据库里的版本 的仍是老版本 `neovim 0.6.1-3`

```bash
dpkg -l | grep -E '^ii\s+neovim|^ii\s+neovim-runtime'
# ii  neovim                                    0.6.1-3                                 amd64        heavily refactored vim fork
# ii  neovim-runtime                            0.6.1-3                                 all          heavily refactored vim fork (runtime files)
```

所以直接删掉:
```bash
sudo apt remove neovim neovim-runtime
```





## 配置为 global 编辑器

配置为 git 的 global 的编辑器:

```bash
git config --global core.editor "nvim"
git config --global core.editor
git config --global merge.tool vimdiff
git config --global mergetool.prompt false
```

如果希望所有的终端工具 (`crontab -e`, `visudo` 等) 都默认使用 `nvim`, 那么就在 config.fish 里:

```bash
export EDITOR=nvim
export VISUAL=nvim
```



## 下载主题

astrovim:

https://github.com/AstroNvim/AstroNvim



### 下载 dependencies

- [Nerd Fonts](https://www.nerdfonts.com/font-downloads) (*Optional with manual intervention:* See [Documentation on customizing icons](https://docs.astronvim.com/Recipes/icons)) [[1\]](https://github.com/AstroNvim/AstroNvim#1)
- [Neovim 0.10+ (*Not* including nightly)](https://github.com/neovim/neovim/releases/tag/stable)
- [Tree-sitter CLI](https://github.com/tree-sitter/tree-sitter/blob/master/cli/README.md) (*Note:* This is only necessary if you want to use `auto_install` feature with Treesitter)
- A clipboard tool is necessary for the integration with the system clipboard (see [`:help clipboard-tool`](https://neovim.io/doc/user/provider.html#clipboard-tool) for supported solutions)
- Terminal with true color support (for the default theme, otherwise it is dependent on the theme you are using) [[2\]](https://github.com/AstroNvim/AstroNvim#2)
- Optional Requirements:
	- [ripgrep](https://github.com/BurntSushi/ripgrep) - live grep picker search (`<leader>fw`)
	- [lazygit](https://github.com/jesseduffield/lazygit) - git ui toggle terminal (`<leader>tl` or `<leader>gg`)
	- [go DiskUsage()](https://github.com/dundee/gdu) - disk usage toggle terminal (`<leader>tu`)
	- [bottom](https://github.com/ClementTsang/bottom) - process viewer toggle terminal (`<leader>tt`)
	- [Python](https://www.python.org/) - python repl toggle terminal (`<leader>tp`)
	- [Node](https://nodejs.org/en/) - node repl toggle terminal (`<leader>tn`)



先用这个脚本看看缺哪些:

```bash
printf "OS: "; cat /etc/os-release | grep '^PRETTY_NAME=' | cut -d= -f2-
printf "\nPackage managers:\n"
for pm in apt dnf pacman zypper apk
  if command -v $pm >/dev/null 2>&1
    echo "- $pm"
  end
end

printf "\nCurrent versions (if installed):\n"
for cmd in nvim tree-sitter rg lazygit gdu btm python3 node xclip xsel wl-copy pbcopy
  if command -v $cmd >/dev/null 2>&1
    echo -n "$cmd: "
    switch $cmd
      case nvim
        $cmd --version | head -n 1
      case tree-sitter
        $cmd --version
      case rg
        $cmd --version | head -n 1
      case lazygit
        $cmd --version | head -n 1
      case gdu
        $cmd --version 2>/dev/null | head -n 1; or $cmd version 2>/dev/null | head -n 1; or echo "installed"
      case btm
        $cmd --version | head -n 1
      case python3
        $cmd --version
      case node
        $cmd --version
      case '*'
        $cmd --version 2>/dev/null | head -n 1; or echo "installed"
    end
  else
    echo "$cmd: missing"
  end
end
```

输出:
```
OS: "Ubuntu 22.04.5 LTS"

Package managers:
- apt

Current versions (if installed):
nvim: NVIM v0.11.6
tree-sitter: missing
rg: missing
lazygit: missing
gdu: missing
btm: missing
python3: Python 3.13.5
node: missing
xclip: missing
xsel: xsel version 1.2.0 by Conrad Parker <conrad@vergenet.net>
wl-copy: missing
pbcopy: missing
```



遂安装:

```bash
sudo apt-get update
```

```bash
sudo apt-get install -y ripgrep gdu python3 xclip xsel wl-clipboard
```

检查安装:

```bash
for c in xclip xsel wl-copy nvim rg python3 node; command -v $c >/dev/null 2>&1; and echo "$c: installed"; or echo "$c: missing"; end
# xclip: installed
# xsel: installed
# wl-copy: installed
```

我们还有四个没装:

- nodejs
- btm
- lazygit
- tree-sitter

tree-sitter 需要用 npm 安装. 而 Nodejs 直接 apt 安装会版本低. 我们 curl 安装

````bash
# 如果之前安装过的话
sudo apt-get remove -y libnode-dev libnode72 nodejs
````

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs
```

然后用 npm 来安装:

```bash
sudo npm install -g tree-sitter-cli@0.22.6
```

(ubuntu 22.04 一定要这个版本. 更高的就不兼容了. )

然后至于 lazygit 和 bottom. 我试过 npm 也装不了. 所以就直接 snap 安装:

```bash
sudo snap install lazygit && sudo snap install bottom
```

btm 这里可能还会出现问题. 这样:

```bash
command -v btm >/dev/null 2>&1 && btm --version || echo 'btm: missing'

# 删除可能存在的错误 btm 入口
sudo rm -f /usr/local/bin/btm

# 用包装脚本把 btm 映射到 snap 的 bottom
echo '#!/usr/bin/env sh' | sudo tee /usr/local/bin/btm >/dev/null
echo 'exec /snap/bin/bottom "$@"' | sudo tee -a /usr/local/bin/btm >/dev/null
sudo chmod +x /usr/local/bin/btm

# 验证
btm --version
```



最后下载 nerdfont:

```bash
mkdir -p ~/.local/share/fonts/JetBrainsMonoNerdFont && cd /tmp && curl -fL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip -o JetBrainsMono.zip && unzip -o JetBrainsMono.zip -d ~/.local/share/fonts/JetBrainsMonoNerdFont >/dev/null && fc-cache -f ~/.local/share/fonts/JetBrainsMonoNerdFont && find ~/.local/share/fonts/JetBrainsMonoNerdFont -type f \( -name '*.ttf' -o -name '*.otf' \) | wc -l
cd ~
```



### 下载主题 files

直接一键迁移我的配置:

```bash
cd ~
git clone git@github.com:yourname/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash initial.sh
```

此时能加载出完整配置



或者使用 astrovim 官方的文件: https://github.com/AstroNvim/AstroNvim





## 添加自定义

众所周知 nvim 和 vim 最好的配置方法就是抄完别人的然后自己再根据喜好修改

我在 polish.lua 中增加了:

```lua
vim.keymap.set("i", "<C-x><C-c>", "<Esc>", { desc = "Insert mode: Ctrl-X Ctrl-C to Normal mode" })
vim.keymap.set("n", "<Space>", "i", { desc = "Normal mode: Space to Insert mode" })

vim.cmd [[cnoreabbrev <expr> qa getcmdtype() == ':' && getcmdline() ==# 'qa' ? 'wq' : 'qa']]
```

- Ctrl X + Ctrl C 进入 normal mode
- normal mode 下空格键进入编辑模式
- :wq 取代 :qa 保存退出
