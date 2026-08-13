# Win-Ubuntu 双系统安装, 从 0 开始, with a single disk

其实并非简单的一件事. 要考虑的事情还蛮多的

尤其针对我们..只有一个 M2 硬盘slot 的电脑

最典型的一件就是: 即便是刚刚买的机器, OS(C) 也是不可 shrink 的. (我900多个G 只能 shrink 出 10几个 G)

因为对于 win 系统而言, 如果只有一个硬盘, 那么它会被完全变成系统盘, 有一堆不可移动文件, 布满整个盘.

就是非常离谱



所以不是要重置电脑, 而是要直接重新安装系统, 在一开始就空余出一片未分配区域.



**当然, 如果有一个多余的硬盘槽, 请忽略下面的重新安装 win 11.**



## 重新安装 win 11, 定制

记得备份一下本地文件, if you like

### 制作启动盘

1. **下载 win 11 iso **

   - 用微软官方工具制作安装盘

   - 下载地址: https://www.microsoft.com/en-us/software-download/windows11

     Download Windows 11 Disk Image (ISO) for x64 devices

2. **下载 rufus**

   - 下载 [Rufus](https://rufus.ie/). 这是个专门用来制作 os 启动硬盘的工具

   - 插入一个 ≥ 8GB 的 U 盘 (会被格式化, 不要选择有内容硬盘.)

   - 打开 rufus, 选择：

     - **Device**: 你的 U 盘
     - **Boot selection**: 选刚刚下载的 Windows 11 ISO
     - **Partition scheme**: GPT
     - **Target system**: UEFI (non CSM)

     然后点击 **Start**, 等它写完.



### 重启进入 bios 安装

开机按 `F2`/`Del`/`Esc`/`F12` 进入 bios 后:

- 进入 boot menu, 选择 UEFI: USB DISK 3.0…. (刚才安装好的盘)
- 进入 Windows 安装界面
- **选择语言和键盘布局 → 下一步 → 安装**
- **选择安装类型 → 自定义安装 (Custom: Install Windows only)**
  - 不要选“升级 (Upgrade)”，那会保留旧系统

- 好的, 下面是最关键的部分: select location to install win11. 在这里我们将重新分配 disk.

  我们会看到一堆 partitions. 其中 disk0 是我们本来的系统, disk 1 是 U 盘.

  然后..

  - 我们把 disk 0 的所有 partitions 全部删掉, 它会全部**并进一个大的 unallocated space**

    ```
    Disk 0 Unallocated Space 			953 GB	...
    ```

  - 我们 create partition, 把它一分为二, 我决定分 512 GB 给 win, 剩下来给 Ubuntu

    create 完之后他会自动生成四个 partitions

    ```
    Disk 0 Partition 1	...		System
    Disk 0 Partition 2	...		MSR (Reserved)
    Disk 0 Partition 3 	...		Primary	#给 win 当系统盘
    Disk 0 Partition 4	...		Unallocated Space #以后留给
    ```

    其中, Partition 1 (EFI) 和 Partition 2 (MSR) 是 Windows 自动创建的
     👉 EFI 里放 Windows Boot Manager, 引导 Windows
     👉 MSR 是 Windows 内部用的隐藏分区

  - 在安装界面里，**选中 Partition 3 (Primary 512 GB)** → 点击 **Next**
     👉 Windows 就会安装在这个 512GB 的分区上

    至于 Partition 4 (Unallocated Space ≈ 454 GB) → 不用管, 留着空着
     👉 之后启动 Ubuntu 安装器时，选择 **Something else (手动分区)**, 在这里新建 Ubuntu 的分区

    - EFI (Ubuntu 专用, 300–500 MB, FAT32, `/boot/efi`)
    - 根 `/` (50 GB, ext4)
    - 家目录 `/home` (剩余空间 ext4)
    - (可选) swap (8–16 GB)

  - 来到 ready to install 界面, 直接点击 install

  - 然后就直接安装好系统, 进入初始化页面了. 和正常的新机开机没啥区别. 唯一的区别是有 0 个驱动. 我们先跳过, 之后再安装



### 完成 win11 安装 (最后安装一下各个驱动)

打开新电脑, 总之就是很干净的一个界面.

然后就可以打开 (1)win_new_computer_init 这个文件来 rewind 一下怎么搞了. 不过在这之前, 我们得安装一些驱动. 最重要的是 wifi 驱动 (还有显卡驱动什么的).

为了安装这个. 我们还得随便找个另一个机器来下载. 可以复用之前的装win11系统的 u 盘, 去另一个机器上下载一下各种驱动.

如何找到驱动: **Shift + F10** → cmd, 输入：

```
wmic csproduct get name
```

它会直接打印出你电脑的型号. 我是 ROG Zephyrus G14 GA403UM

然后就可以找到电脑厂商官网下载一下各种驱动.

我的是: https://rog.asus.com/us/laptops/rog-zephyrus/rog-zephyrus-g14-2025/helpdesk_download/



装上之后就可以联网了. 然后我们就可以在本地安装其他的驱动.

- 官方支持的显卡驱动
- 声卡驱动
- 精准 touchpad 驱动
- 各种等等, 有就装, 不坏事

>  ps: 如果你也是 rog 的话, 作为 rog 老学长我强烈建议不要安装 MyAsus, 推荐广告有点离谱
>
> 但是 armoury crate 还是有很多用处的, 可以装一下 (这个不是驱动是普通app): https://www.asus.com/supportonly/armoury%20crate/helpdesk_download/







## 在未分配区域上安装 Ubuntu

### 制作启动盘

一样.

- 下载 Ubuntu ISO ([Ubuntu 官方网站](https://ubuntu.com/download/desktop)).

- 用 **Rufus** 或 **Ventoy** 制作启动盘。

  - 选择 ISO 文件

  - 分区类型: GPT

    目标系统: UEFI

  - 文件系统: FAT32 (和 win 不同)



### 重启进入 bios 安装

#### 关 BitLocker

在重启前记得: 一定要把 windows 的 BitLocker 加密关掉. 当 Windows 的系统盘 (通常是 `C:`) 或 EFI 分区 被 BitLocker 加密时, Ubuntu 安装器无法安全修改分区表或引导设置

1. 打开控制面板 → “系统和安全” → “BitLocker 驱动器加密”

2. 在 “操作系统驱动器 (C:)” 一栏中，你会看到：

   ```
   BitLocker 状态: 已开启
   ```

   点击关闭 BitLocker, 确认 → 系统开始解密
    这一步可能需要 5–20 分钟 (取决于 SSD 容量)

你会看到 “正在解密驱动器...”，解密完成后会显示：

```
BitLocker 已关闭
```



然后可以开始安装了

#### 配置 bios

重启 f2 进入 bios

注意这里我们要小心一点了. 现在我们的硬盘里已经有一个系统了, 要是搞错了之前就白搞了

检查以下设置.

- ✅ `SVM` (AMD-V) 或 `Intel VT-x` **Enabled**
- `Secure Boot` **Disabled**
- `Fast Boot` 也 **Disabled**
- ✅ `Boot Mode` 设置为 **UEFI**

然后 Save & Exit 离开 bios.



接下来, 马上连续按启动菜单键. ROG 是 **`F12`** 或 **`Esc`**.

在 please select boot device 中选择 UEFI: Memore x USB….

然后可以启动菜单：

```
Try or Install Ubuntu
Ubuntu (safe graphics)
Boot from next volume
UEFI Firmware Settings
```

1. 用方向键选 **Try or Install Ubuntu**, Enter
2. 之后会显示 Ubuntu 的 logo加载几秒



ps: 这里图形显示有可能出问题, 就是屏幕上只剩一个鼠标, 没进入 Ubuntu 的紫色桌面. 这种情况长按重启就好了





#### 安装 Ubuntu

然后开始安装 Ubuntu. 这里我们知道: 必须安装在未分配区域别和 windows 冲突了. 这个等一会儿会选

先看到 Ubuntu 安装的引导界面, 选择 language, keyboard layout, network 等等

然后关键一步:  disk setup

一定选择:

- Install Ubuntu alongside Windows Boot Manager

而不是 erase disk.



选择之后, 就会进入创建 account.

注意: Ubuntu 的安装器 (`Ubiquity` 或 24.04 之后的 `Subiquity`) 会根据磁盘状态自动判断：

- 如果它检测到一块**连续的未分配空间 (unallocated space)**, 并且空间足够大 (≥ 35 GB), 就会**自动选择把 Ubuntu 安装到那块未分配区**, 而不再询问你要分多少.

就是说我们不用担心. Ubuntu 是装在了我们之前分割出来的未分配区域上了. 它自己会在未分配空间中新建 2–3 个分区：

- `ext4` (挂载点 `/`)
- 可能的 `swap`
- 可选的 `/home`



共享 Windows 的 EFI 引导分区 (不会破坏原内容, 只是增加一条 “ubuntu” 启动项)

所以 Windows 的文件, 分区, 系统启动都不会受到影响









## Further 说明:

我们安装完 Ubuntu 之后, Ubuntu 的 boot priority 会高于 windows boot manager.

之后每次我们开机, 都会进入 Ubuntu 的启动管理器 **GRUB (GNU GRand Unified Bootloader)**.

```
GNU GRUB version 2.12

Ubuntu
Advanced options for Ubuntu
Windows Boot Manager (on /dev/nvme0n1p1)
```

这个菜单默认在启动时出现 5–10 秒, 让你选择进入：

- **Ubuntu** (默认选项)
- **Windows Boot Manager** (回到 Windows)

这个菜单比较卡也很正常, 因为在 UEFI 阶段会初始化大量 PCIe 设备、NVMe、独显、键盘背光等等
 GRUB 菜单显示在这个阶段之上, 所以:

> 键盘事件和画面刷新需要等待固件响应，导致输入延迟 1~2 秒
