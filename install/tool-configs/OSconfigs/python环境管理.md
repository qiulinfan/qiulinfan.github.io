速战速决地配置一下 python 环境

# Win

### install miniconda

直接下载

https://www.anaconda.com/download/success

### 把 conda 加入环境变量

加入这两行就好了

```
C:\Users\<用户名>\miniconda3
C:\Users\<用户名>\miniconda3\Scripts
```

然后重新打开 powershell

### conda init, create environment

比如

```shell
conda init
conda create -n gpurun python=3.12
```

创建一个叫 gpurun 的环境. 记得要 3.12 版本, 因为再往后还没找到 torch 的支持

### 装库

然后 activate 它就可以装一些 libraries

```shell
conda activate gpurun
```

```shell
 conda install numpy matplotlib pandas
 conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia #gpu 版本的 torch
```

(同一个环境里不要同时装一个 library 的 gpu 和 cpu 版本)





# WSL / Linux

### install miniconda, 配置环境变量

linux 系统下更加方便

```shell
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash ~/Miniconda3-latest-Linux-x86_64.sh #这样就装好了 miniconda
```

然后我这里是 fish shell. 打开 config 文件加入:

```shell
set -gx PATH /home/qiulin/miniconda3/bin $PATH
set -Ux CONDA_EXE /home/qiulin/miniconda3/bin/conda
set -Ux _CONDA_ROOT /home/qiulin/miniconda3
# 添加 conda 初始化脚本到 config.fish
source /home/qiulin/miniconda3/etc/fish/conf.d/conda.fish
eval (/home/qiulin/miniconda3/bin/conda shell.fish hook)
```

就配置好了环境变量



### conda init, create 以及装库等

和 win 里一样.

比如

```shell
conda init
conda create -n gpurun python=3.12
```

创建一个叫 gpurun 的环境. 记得要 3.12 版本, 因为再往后还没找到 torch 的支持



然后 activate 它就可以装一些 libraries

```shell
conda activate gpurun
```

```shell
 conda install numpy matplotlib pandas
 conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia #gpu 版本的 torch
```

(同一个环境里不要同时装一个 library 的 gpu 和 cpu 版本)





# 调用环境

windows 我习惯 VSCode 编辑, Pycharm 跑.

wsl 里至少 community 版本的 pycharm 没提供直接连接 wsl 的方法. 所以我只用过 VSCode



VSCode 主要只有一个问题, 就是 jupyter 支持默认会给你下载一个 2023 的版本. 但是现在用不了了, 所以会发现选择不了 kernel.

处理方法也很简单. 在 jupter 这个 extension 中选择 uninstall, 然后重新 install 一个 2025 版本就好了
