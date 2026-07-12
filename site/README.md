# Blog Site

这里是基于 [Fuwari](https://github.com/saicaca/fuwari) 的 Astro 网站工程。

日常写作请使用仓库根目录的 `blogs/posts/`，并通过根目录 `Makefile` 运行命令。只有在修改主题、导航、部署方式或网站功能时才需要进入本目录。

常用配置位置：

- `src/config.ts`：站点名称、作者、导航、主题颜色和版权协议；
- `astro.config.mjs`：部署网址、基础路径和 Markdown 插件；
- `src/content/spec/about.md`：关于页面；
- `public/`：favicon 等原样发布的静态资源；
- `src/assets/`：由 Astro 处理的图片资源；
- `src/styles/`：Fuwari 样式。

Fuwari 的 MIT 许可证保存在 `FUWARI-LICENSE`。
