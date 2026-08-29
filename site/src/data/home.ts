export const projectGroups = [
	{
		title: "Games & In-house Engine",
		titleZh: "游戏与自研引擎",
		projects: [
			{
				title: "Village Rim",
				image: "/assets/village-rim.webp",
				href: "https://bluesamoyed.itch.io/village-rim",
				linkLabel: "Play",
				tags: ["Unity", "Combat AI", "Level Design"],
				description:
					"A four-person 2D adventure; I owned combat, enemy behavior, animation integration, spawning, and level design.",
				descriptionZh:
					"四人合作完成的 2D 冒险游戏；我负责战斗、敌人行为、动画集成、生成系统与关卡设计。",
			},
			{
				title: "PocketEngine",
				image: "/assets/projects/pocket-engine.gif",
				href: "https://github.com/qiulinfan/pocketEngine",
				linkLabel: "GitHub",
				tags: ["C++17", "SDL2", "Lua", "Box2D", "ImGui"],
				description:
					"A cross-platform 2D runtime and editor with Lua game scripting and JSON scene assets.",
				descriptionZh:
					"跨平台 2D runtime 与编辑器，支持 Lua 游戏逻辑和 JSON 场景资源。",
			},
		],
	},
	{
		title: "Game Art Automaking",
		titleZh: "游戏美术自动化",
		projects: [
			{
				title: "Discrete Sprite Lab",
				image: "/assets/projects/discrete-sprite-lab.png",
				href: "https://github.com/qiulinfan/discrete-sprite-lab",
				linkLabel: "GitHub",
				tags: ["Pixel Art", "Discrete Grid", "Agent Skills"],
				description:
					"AI-native pixel art rebuilt on a discrete grid, with a public art pack and reproducible production Skills.",
				descriptionZh:
					"在离散网格上重建 AI 原生像素画，包含公开 art pack 与可复现的生产 Skills。",
			},
			{
				title: "AutoTA",
				image: "/assets/projects/autota.png",
				href: "https://github.com/qiulinfan/autoTA",
				linkLabel: "GitHub",
				tags: ["Technical Art", "2D / 3D", "Asset Audit"],
				description:
					"An evidence-driven technical-art pipeline from asset requirements to licensed or generated, audited deliveries.",
				descriptionZh:
					"从美术需求到许可明确或生成式资产交付的证据驱动技术美术管线。",
			},
		],
	},
	{
		title: "Knowledge System",
		titleZh: "知识系统",
		projects: [
			{
				title: "kgdistiller",
				image: "https://opengraph.githubassets.com/qlblog-home/qiulinfan/kgdistiller",
				href: "https://github.com/qiulinfan/kgdistiller",
				linkLabel: "GitHub",
				tags: ["Knowledge Graph", "Markdown", "Typst", "LaTeX"],
				description:
					"A deterministic, source-backed knowledge graph compiled from registered Markdown, Typst, and LaTeX authorities.",
				descriptionZh:
					"从已登记的 Markdown、Typst 与 LaTeX 权威源生成确定性、可追溯的知识图谱。",
			},
		],
	},
	{
		title: "Tiny Tools",
		titleZh: "小工具",
		projects: [
			{
				title: "sessionmgr",
				image: "/assets/projects/sessionmgr.png",
				href: "https://github.com/qiulinfan/sessionmgr",
				linkLabel: "GitHub",
				tags: ["Go", "CLI", "Local UI"],
				description:
					"Export and move Codex, Claude Code, and DSH sessions between agents and machines.",
				descriptionZh:
					"在不同 Agent 与机器之间导出、迁移 Codex、Claude Code 和 DSH 会话。",
			},
			{
				title: "obsidian-tinymist",
				image: "https://opengraph.githubassets.com/qlblog-home/qiulinfan/obsidian-tinymist",
				href: "https://github.com/qiulinfan/obsidian-tinymist",
				linkLabel: "GitHub",
				tags: ["Obsidian", "Typst", "Tinymist"],
				description:
					"Tinymist-grade Typst editing in Obsidian, including diagnostics, completion, hover, and live preview.",
				descriptionZh:
					"在 Obsidian 中提供 Tinymist 级 Typst 编辑，包括诊断、补全、悬浮文档和实时预览。",
			},
		],
	},
] as const;
