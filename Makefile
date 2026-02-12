.PHONY: build serve deploy gh-deploy clean

# 构建网站
build:
	mkdocs build

# 本地预览
serve:
	mkdocs serve

# 部署到 gh-pages 分支（主要部署方式）
# GitHub Pages 配置：Branch: gh-pages, Folder: / (root)
deploy: build
	@echo "正在部署到 gh-pages 分支..."
	mkdocs gh-deploy
	@echo "✅ 已部署到 gh-pages 分支！"
	@echo "网站将在几分钟内更新：https://qiulinfan.github.io"

# 部署到 gh-pages 分支（别名，与 deploy 相同）
gh-deploy: deploy

# 清理构建文件
clean:
	rm -rf site/
