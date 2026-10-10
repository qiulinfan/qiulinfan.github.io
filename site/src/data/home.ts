export const showcases = {
	works: {
		title: "Works",
		titleZh: "作品",
		description: "Qiulin's engineering and research work.",
		descriptionZh: "Qiulin 的工程与研究作品。",
		groups: [
			{
				title: "Engineering",
				titleZh: "工程",
				projects: [
					{
						title: "Amoris Engine",
						image: "https://qiulinfan.github.io/amoris/media/scene-poster.jpg",
						href: "https://qiulinfan.github.io/amoris/",
						linkLabel: "Website",
						tags: ["Rust", "TypeScript", "wgpu", "WebGPU", "Agent-native"],
						description:
							"An agent-native 3D game engine with a Rust host, TypeScript gameplay, and shared editor, CLI, and MCP commands.",
						descriptionZh:
							"Rust + TypeScript 的 agent-native 3D 游戏引擎，编辑器、CLI 与 MCP 共用一套命令接口。",
					},
					{
						title: "pocket2d",
						image: "/assets/projects/pocket-engine.gif",
						href: "https://qiulinfan.github.io/pocket2d/",
						linkLabel: "Website",
						tags: ["C++17", "SDL2", "Lua", "Box2D", "ImGui"],
						description:
							"A lightweight, cross-platform 2D runtime and editor built with C++17 and Lua, with JSON scene assets.",
						descriptionZh:
							"轻量的 C++17 + Lua 跨平台 2D runtime 与编辑器，支持 JSON 场景资源。",
					},
					{
						title: "kgdistiller",
						image: "/assets/projects/kgdistiller-obsidian-graph.jpg",
						imageFit: "contain",
						href: "https://github.com/qiulinfan/kgdistiller",
						linkLabel: "GitHub",
						tags: ["Knowledge Base", "Obsidian", "SQLite", "Agent Skills"],
						description:
							"A local-first research knowledge base: source-backed records and role-bound relations in Obsidian vaults, indexed in one SQLite file.",
						descriptionZh:
							"本地优先的研究知识库：在 Obsidian 仓库中保存有原文出处的记录与按角色绑定的关系，并由单个 SQLite 文件建立索引。",
					},
				],
			},
		],
	},
	playground: {
		title: "Playground",
		titleZh: "游乐场",
		description: "Games, game-art experiments, and small tools built for fun.",
		descriptionZh: "做着玩的游戏、游戏美术实验和小工具。",
		groups: [
			{
				title: "Games",
				titleZh: "游戏",
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
				],
			},
			{
				title: "Game Art Automaking",
				titleZh: "游戏美术自动化",
				projects: [
					{
						title: "Discrete Sprite Lab",
						images: [
							{
								src: "/assets/projects/discrete-player-rotation.gif",
								alt: "Player eight-direction rotation",
							},
							{
								src: "/assets/projects/discrete-goblin-archer-rotation.gif",
								alt: "Goblin archer eight-direction rotation",
							},
							{
								src: "/assets/projects/discrete-player-walk.gif",
								alt: "Player south walk cycle",
							},
						],
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
						image: "/assets/projects/classroom-writing-loop.gif",
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
						image: "/assets/projects/obsidian-tinymist-demo.gif",
						href: "https://github.com/qiulinfan/obsidian-tinymist",
						linkLabel: "GitHub",
						tags: ["Obsidian", "Typst", "Tinymist", "YOLO Completion"],
						description:
							"Tinymist-grade Typst editing in Obsidian, including diagnostics, completion, hover, and live preview.",
						descriptionZh:
							"在 Obsidian 中提供 Tinymist 级 Typst 编辑，包括诊断、补全、悬浮文档和实时预览。",
					},
				],
			},
		],
	},
} as const;

export type ShowcaseId = keyof typeof showcases;
