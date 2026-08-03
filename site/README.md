# Personal Site

这里是基于 [Fuwari](https://github.com/saicaca/fuwari) 的 Astro 个人网站工程。主页、博客、笔记和知识图谱共用同一个布局系统与视觉契约。

日常写作请使用仓库根目录的 `blogs/posts/`，并通过根目录 `Makefile` 运行命令。只有在修改主题、导航、部署方式或网站功能时才需要进入本目录。

## 单一外观入口

全站颜色、文本层级、圆角、阴影和表面语义都只在 `src/styles/variables.styl` 中定义。页面组件只能消费这些 CSS variables，不应自行建立另一套 light/dark palette。

`src/components/GlobalStyles.astro` 是唯一的全局样式装配入口。若增加新的全局样式文件，只在这里引入。

常用配置位置：

- `src/config.ts`：站点名称、作者、导航和版权协议；
- `astro.config.mjs`：部署网址、基础路径和 Markdown 插件；
- `src/content/spec/about.md`：关于页面；
- `public/`：favicon 等原样发布的静态资源；
- `src/assets/`：由 Astro 处理的图片资源；
- `src/styles/variables.styl`：全站唯一的视觉 token 源；
- `src/components/home/`：个人主页与项目页面。

## 根域部署

权威仓库是 `qiulinfan/qiulinfan.github.io`，默认以 `/` 构建并发布到用户根站点。若需复现迁移前的项目站点路径，可显式运行：

```bash
QL_SITE_BASE=/qlblog/ corepack pnpm build
```

知识节点的 canonical `web` 地址以 `knowledge/sources.json` 为准。根域构建同时保留旧 `/qlblog/*` 兼容跳转。

Fuwari 的 MIT 许可证保存在 `FUWARI-LICENSE`。
