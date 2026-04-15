.PHONY: build serve deploy gh-deploy clean install

PYTHON ?= python3
VENV ?= .venv
VENV_BIN := $(VENV)/bin
PIP := $(VENV_BIN)/pip
MKDOCS := $(VENV_BIN)/mkdocs
DEPS_STAMP := $(VENV)/.deps-installed

$(DEPS_STAMP): requirements.txt
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt
	touch $(DEPS_STAMP)

install: $(DEPS_STAMP)

# 构建网站
build: $(DEPS_STAMP)
	$(MKDOCS) build

# 本地预览
serve: $(DEPS_STAMP)
	$(MKDOCS) serve

# 部署到 gh-pages 分支（主要部署方式）
# GitHub Pages 配置：Branch: gh-pages, Folder: / (root)
deploy: build
	@echo "正在部署到 gh-pages 分支..."
	$(MKDOCS) gh-deploy
	@echo "✅ 已部署到 gh-pages 分支！"
	@echo "网站将在几分钟内更新: https://qiulinfan.github.io"

# 部署到 gh-pages 分支（别名，与 deploy 相同）
gh-deploy: deploy

# 清理构建文件
clean:
	rm -rf site/
