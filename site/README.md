# Personal Site

这里是基于 [Fuwari](https://github.com/saicaca/fuwari) 的 Astro 个人网站工程。主页、博客和笔记共用同一个布局系统与视觉契约；知识图谱浏览已迁回 kgdistiller 自带的本地前端。

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
- `../skills/README.md`：Skills 页面顶部能力简介的权威来源；
- `../skills/published-skill-repositories.tsv`：Skills 页面展示的自有公开 repository 清单；
- `../skills/linked-skill-repositories.tsv`：仅供本机 linking、网站绝不读取的私有与第三方 repository 清单；
- `../skills/WORKFLOWS.md`：Skills 页面工具流与 Mermaid 图的可编辑内容源；
- `src/styles/variables.styl`：全站唯一的视觉 token 源；
- `src/components/home/`：个人主页，以及 Works 与 Playground 两个展示页；
- `src/data/home.ts`：Works（严肃工作与今后的 research）和 Playground（游戏与小工具）的条目。

第一次在新 checkout 构建包含外部公开 Skills 的页面前，先在仓库根目录运行
`make skills-published-bootstrap`。它只会浅克隆 `published-skill-repositories.tsv` 中登记的公开
仓库；私有和第三方 linked-only registry 不属于网站输入。

## 根域部署

权威仓库是 `qiulinfan/qiulinfan.github.io`，默认以 `/` 构建并发布到用户根站点。若需复现迁移前的项目站点路径，可显式运行：

```bash
QL_SITE_BASE=/qlblog/ corepack pnpm build
```

根域构建同时保留旧 `/qlblog/*` 兼容跳转。

## Docks

其他仓库的内容通过仓库根目录的 `docks.json` 挂载，`src/docks/<id>/` 是各自的 adapter，
`src/docks/integration.ts` 注入它们的路由并在构建前后运行 adapter 步骤。notes dock 的笔记与
知识节点 canonical `web` 地址以 notes 仓库的 `knowledge/sources.json` 为准；`/notes/` 与主页的
公开笔记入口也只读取这份 registry。每个 source 必须显式设置
`publish` 和 `listed`：前者控制网页是否产出，后者控制是否出现在公开目录；
`listed: true` 必须同时满足 `publish: true`。这些开关不影响本地知识图谱摄取。
站点不再发布知识图谱页面或 JSON endpoint；adopted bundle 中的 `graph.json`
只作为可验证的内部构建记录。Typst 等由 Astro 之外编译的页面通过 source 的 `web_artifacts` 声明部署产物；`astro build`
先调用 notes 仓库的 `make web` 编译它们，构建结束后只安装 `publish: true` 的产物。

Fuwari 的 MIT 许可证保存在 `FUWARI-LICENSE`。
