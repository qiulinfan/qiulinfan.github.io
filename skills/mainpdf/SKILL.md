---
name: pdf-editor
description: "全能PDF编辑器。Trigger on: PDF编辑、PDF转换、PDF提取、PDF OCR、扫描件识别、pdf to word、pdf to image、PDF合并、PDF拆分、PDF转图片、PDF转Word、提取PDF文字、提取PDF表格、PDF插入文字、PDF插入图片、PDF总结、pdf editor、pdf merge、pdf split。支持扫描件和普通PDF的文字/表格/图片提取、OCR识别、插入编辑、格式转换（Word/图片/HTML）、文档总结归纳。"
license: MIT
allowed-tools:
  - execute_command
  - deliver_attachments
  - read_file
  - write_to_file
  - Bash
  - Read
  - Write
---

# PDF EDITOR - 全能PDF编辑器

一个工具搞定PDF的读取、编辑、转换、识别、总结。

## 能做什么？

| 功能分类 | 具体能力 | 适用场景 |
|---------|---------|---------|
| **📖 内容提取** | 文字、表格、图片一键提取 | 需要复制PDF内容、整理数据 |
| **🔍 OCR识别** | 扫描件/图片PDF文字识别 | 纸质文档扫描后无法复制文字 |
| **✏️ 编辑修改** | 插入文字、插入图片、覆盖内容 | 在PDF上添加批注、替换二维码/印章 |
| **📄 页面操作** | 合并、拆分、删除、旋转 | 整理多份PDF、调整页面方向 |
| **🔄 格式转换** | 转Word、转图片、转HTML、图片转PDF | 需要编辑或分享PDF内容 |
| **📝 文档总结** | 自动归纳文档核心内容 | 快速了解长文档要点 |

## 核心特点

- ✅ **扫描件友好** — 自动判断PDF类型，扫描件自动 fallback 到 OCR
- ✅ **中文优化** — 默认支持中文识别和中文排版
- ✅ **零配置** — 首次使用自动检测并安装依赖，国内网络走清华镜像
- ✅ **纯本地运行** — 敏感文档不上传第三方
- ✅ **高精度** — 二维码/元素定位支持 4x 渲染，误差 < 0.3pt

---

## 使用方式

### 一、提取PDF内容

**提取文字：**
> 提取这个PDF的文字内容
> 提取第3-5页的文字

**提取表格：**
> 把PDF里的表格提取出来
> 提取这个PDF的表格保存为Excel

**提取图片：**
> 把PDF里的图片全部导出来

**扫描件识别（OCR）：**
> 这个扫描件PDF帮我识别一下文字
> OCR识别这个PDF的内容

### 二、编辑PDF

**插入文字：**
> 在第2页中间插入一段文字
> 给PDF每页加上页码

**插入/替换图片：**
> 把第一页的二维码换成新的
> 在PDF右上角加上公司Logo

**页面操作：**
> 把这几个PDF合并成一个
> 每5页拆成一个文件
> 删除第3页和第7页
> 把第2页旋转90度

### 三、格式转换

**转Word：**
> PDF转Word
> 把这个PDF转成可以编辑的Word文档

**转图片：**
> PDF转成图片
> 把PDF每一页都存成图片
> PDF拼成一张长图

**图片转PDF：**
> 把这些图片合并成PDF

**转HTML：**
> PDF转HTML网页格式

**转纯文本：**
> PDF转txt文本文件

### 四、文档分析

**文档总结：**
> 总结一下这个PDF的主要内容
> 这个文档讲了什么，列出要点

**PDF信息分析：**
> 分析一下这个PDF的基本信息
> 看看这个PDF有多少页、什么尺寸

---

## 技术实现

### 核心依赖

**首次使用会自动检测并安装依赖，无需手动操作。**

如果自动安装失败，可手动执行：

```bash
# 必需（自动适配 python/python3/pip/pip3，支持国内镜像回退）
python scripts/deps.py
# 或手动安装
python -m pip install PyMuPDF Pillow numpy pdfplumber python-docx

# OCR可选（扫描件识别需要）
python -m pip install pytesseract    # Tesseract OCR（需额外安装tesseract-ocr）
python -m pip install easyocr        # EasyOCR（纯Python，中文效果更好）
```

### 功能矩阵

| 功能 | 技术方案 | 扫描件支持 |
|------|---------|-----------|
| 文字提取 | PyMuPDF / pdfplumber | ✅ OCR fallback |
| 表格提取 | pdfplumber | ❌（需清晰PDF） |
| 图片提取 | PyMuPDF 原生提取 | ✅ |
| 插入文字 | PyMuPDF insert_textbox | ✅ |
| 插入图片 | PyMuPDF insert_image | ✅ |
| 元素定位 | 高分辨率渲染 + NumPy 像素分析 | ✅ |
| OCR识别 | pytesseract / easyocr | ✅ |
| 转Word | python-docx | ✅ |
| 转图片 | PyMuPDF get_pixmap | ✅ |
| 合并拆分 | PyMuPDF insert_pdf / delete_page | ✅ |

### 扫描件判断逻辑

```python
def is_scanned_pdf(pdf_path):
    doc = fitz.open(pdf_path)
    for page in doc[:3]:  # 采样前3页
        images = page.get_images()
        text = page.get_text().strip()
        if len(images) >= 1 and len(text) < 50:
            return True  # 有图但几乎无文字 = 扫描件
    return False
```

### 扫描件转Word的特殊处理

扫描件（纯图片PDF）转Word时，**不能直接提取文字**（`page.get_text()` 返回空），需要采用**图片嵌入模式**：

1. **渲染为高清图片**（200 DPI）
2. **Word页面设为零边距**，图片严格匹配 A4 尺寸
3. **段落格式清零**：`space_before=0`, `space_after=0`, `line_spacing=1.0`
4. **同时设置图片宽高**：`width=Cm(21.0), height=Cm(29.7)`
5. **不手动插入分页符**：图片占满整页自然分页

```python
# 正确做法
paragraph = word_doc.add_paragraph()
paragraph.paragraph_format.space_before = Pt(0)
paragraph.paragraph_format.space_after = Pt(0)
paragraph.paragraph_format.line_spacing = 1.0
run = paragraph.add_run()
run.add_picture(img_path, width=Cm(21.0), height=Cm(29.7))
# ❌ 不要 add_page_break()！
```

**常见错误**：只设置 `width` 不设 `height` 时，Word 会根据图片默认 DPI 自动计算高度，若 DPI 过低（如72），图片会被放得过大，超出页面导致空白页。

### OCR 引擎选择

| 引擎 | 优点 | 缺点 | 推荐场景 |
|------|------|------|---------|
| **Tesseract** | 轻量、速度快 | 中文效果一般、需单独安装系统包 | 清晰印刷体 |
| **EasyOCR** | 中文效果好、支持手写 | 体积大、初次加载慢、**Windows下torch可能报`pwd`模块错** | 中文文档、手写体 |

---

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 中文显示乱码 | 缺少中文字体 | 系统安装中文字体或使用PyMuPDF内置字体 |
| OCR识别不准 | 扫描件模糊/倾斜 | 提高DPI到300+，或使用EasyOCR |
| 表格提取格式错乱 | PDF表格无明确边框 | 使用pdfplumber的表格检测参数调优 |
| 转Word后格式丢失 | PDF和Word格式体系不同 | 复杂排版建议转图片或保留PDF |
| **转Word后有空白页** | 扫描件图片尺寸未锁定，超出页面 + 手动分页符 | 同时设置图片宽高=页面尺寸，段落间距清零，去掉手动分页符 |
| 扫描件转Word是空文档 | 扫描件无文字层，`get_text()`返回空 | 本工具已自动检测扫描件并切换为图片嵌入模式 |
| 插入文字位置偏移 | PDF坐标系原点在左下角 | 使用fitz.Rect(x0, y0, x1, y1)精确定位 |
| 文件保存失败 | 输出文件被占用 | 关闭PDF阅读器后重试，或更换输出文件名 |
| Windows下中文路径报错 | 系统编码问题 | 使用英文路径，或在Python文件头添加 `# -*- coding: utf-8 -*-` |
| **Windows下EasyOCR报错`No module named 'pwd'`** | torch在Windows下调用Unix专用模块 | 改用Tesseract，或用WSL运行EasyOCR |
| macOS/Linux找不到python命令 | 系统只装了python3 | 使用 `python3` 替代 `python` |
| 临时文件清理失败 | 权限问题 | 程序会自动处理，不影响功能 |

---

## 脚本命令行用法

**输出路径规则：**
- 默认输出到当前工作目录下的 **`output/`** 子目录
- 不指定 `-o` 时自动创建 `output` 目录并按规则命名
- **执行完成后会明确打印输出文件的绝对路径**

```bash
# PDF转Word（默认：当前目录/output/原文件名.docx）
python scripts/pdf_convert.py to-word input.pdf
# 或指定输出路径
python scripts/pdf_convert.py to-word input.pdf -o /path/to/output.docx

# PDF转图片（默认：当前目录/output/）
python scripts/pdf_convert.py to-images input.pdf
# 或指定输出目录
python scripts/pdf_convert.py to-images input.pdf -o ./images --dpi 300

# PDF拼接为长图（默认：当前目录/output/原文件名.png）
python scripts/pdf_convert.py to-single-image input.pdf

# 图片合并为PDF（默认：当前目录/output/merged.pdf）
python scripts/pdf_convert.py images-to-pdf a.png b.png c.png

# 分析PDF信息
python scripts/pdf_core.py analyze input.pdf

# 提取文字（默认：当前目录/output/原文件名.txt）
python scripts/pdf_core.py extract-text input.pdf

# 合并PDF
python scripts/pdf_core.py merge a.pdf b.pdf c.pdf -o merged.pdf

# OCR识别扫描件
python scripts/pdf_ocr.py input.pdf -o output.txt --lang chi_sim+eng
```

---

## 开发日志

- **v1.0.0** — 初始版本，涵盖提取、编辑、转换、OCR、总结五大模块
  - 自动依赖管理：运行时检测缺失包并自动安装（参考 douyin-downloader 设计）
  - 国内镜像回退：依赖安装失败自动回退到清华镜像
  - 修复跨平台兼容：临时目录使用 `tempfile.gettempdir()` 替代硬编码 `/tmp`
  - 修复Python命令兼容：支持 `python` / `python3` / `pip` / `pip3` 自动适配
  - 修复目录创建：统一使用 `os.makedirs(exist_ok=True)` 确保跨平台可用
  - 增强Word转中文：自动尝试设置中文字体（Microsoft YaHei）
