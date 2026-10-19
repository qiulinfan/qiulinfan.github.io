const amoris = {
	title: "Amoris Engine",
	image: "https://qiulinfan.github.io/amoris/media/scene-poster.jpg",
	href: "https://qiulinfan.github.io/amoris/",
	linkLabel: "Website",
	tags: ["Rust", "TypeScript", "wgpu", "WebGPU", "Agent-native"],
	description:
		"An agent-native 3D game engine: a Rust host with TypeScript gameplay, desktop and web editors, path tracing, voxels and shallow water, deterministic replay, and one command API for the editor, CLI, and MCP.",
	descriptionZh:
		"agent-native 3D 游戏引擎：Rust 宿主 + TypeScript 玩法，桌面与网页编辑器、路径追踪、体素与浅水模拟、确定性回放，编辑器、CLI 与 MCP 共用一套命令接口。",
};

const pocket2d = {
	title: "pocket2d",
	image: "/assets/projects/pocket-engine.gif",
	href: "https://qiulinfan.github.io/pocket2d/",
	linkLabel: "Website",
	tags: ["C++26", "SDL3", "Lua", "Box2D 3", "Agent-native"],
	description:
		"An agent-native 2D game engine: a C++26 / SDL3 runtime and editor with Lua gameplay, deterministic stepping and replay over an agent protocol, packaging for macOS, Windows, Linux and the web, and two-player rollback netplay.",
	descriptionZh:
		"agent-native 2D 游戏引擎：C++26 / SDL3 runtime 与编辑器，Lua 写玩法；agent 协议下确定性步进与回放，可打包 macOS、Windows、Linux 与网页，支持双人回滚联机。",
};

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
					amoris,
					pocket2d,
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
		description: "Two agent-native engines, the pipelines that make their game art, and the games made with them.",
		descriptionZh: "两个 agent-native 引擎、为它们生产游戏美术的管线，以及用它们做出来的游戏。",
		groups: [
			{
				title: "Agent-native Engines",
				titleZh: "Agent-native 引擎",
				projects: [pocket2d, amoris],
			},
			{
				title: "Game Art Pipelines",
				titleZh: "游戏美术管线",
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
						tags: ["3D Technical Art", "Blender", "Asset Audit"],
						description:
							"An evidence-driven technical-art pipeline, centred on Blender-side 3D work: from asset requirements to licensed or generated, audited deliveries.",
						descriptionZh:
							"证据驱动的技术美术管线，以 Blender 端 3D 制作为核心：从美术需求到许可明确或生成式、经过审计的资产交付。",
					},
				],
			},
			{
				title: "Games on Our Engines",
				titleZh: "引擎上的游戏",
				projects: [
					{
						title: "死神VS火影 Pocket",
						video: { src: "/assets/projects/bvn-pocket.mp4", poster: "/assets/projects/bvn-pocket.jpg" },
						href: "https://bluesamoyed77.itch.io/bleach-vs-naruto-pocket2d-remaster",
						linkLabel: "Play",
						tags: ["pocket2d", "Fighting", "Rollback Netplay", "Fan Remake"],
						description:
							"A pocket2d remake of 5DPLAY Game Studio's Bleach vs Naruto, with the original roster, assists, stages and music from their open repositories, and online versus over rollback netcode. A non-commercial fan tribute; the characters belong to their rights holders.",
						descriptionZh:
							"在 pocket2d 上复刻 5DPLAY Game Studio 的《死神VS火影》：角色、援助、场景与音乐来自原作开源仓库，支持回滚联机对战。非商业同人致敬作品，角色版权归原权利人所有。",
					},
					{
						title: "Village Rim",
						video: { src: "/assets/projects/village-rim-pocket2d.mp4", poster: "/assets/projects/village-rim-pocket2d.jpg" },
						href: "https://bluesamoyed77.itch.io/village-rim",
						linkLabel: "Play",
						tags: ["pocket2d", "Unity Migration", "Adventure"],
						description:
							"Our four-person Unity adventure, migrated onto pocket2d: its tilemaps and sprites imported, the gameplay rewritten in Lua, and the whole route played end to end by agent playtests. The itch.io page has the original Unity build.",
						descriptionZh:
							"我们四人合作的 Unity 冒险游戏迁移到 pocket2d：导入地图与精灵，玩法用 Lua 重写，整条流程由 agent 自动试玩从头打到尾。itch.io 页面提供的是 Unity 原版。",
					},
					{
						title: "Blockcraft",
						wide: true,
						images: [
							{ src: "/assets/projects/blockcraft-v8-walk.webp", alt: "Blockcraft island shore at walking height" },
							{ src: "/assets/projects/blockcraft-w5-over.webp", alt: "The whole Blockcraft island from above" },
							{ src: "/assets/projects/blockcraft-w3-flow.webp", alt: "Water poured from placed blocks" },
						],
						href: "https://bluesamoyed77.itch.io/blockcraft",
						linkLabel: "Play",
						tags: ["Amoris", "Voxels", "Shallow Water"],
						description:
							"A voxel sandbox island on Amoris: break and build blocks while the engine's shallow water floods broken banks, pours from placed blocks and drains into holes. Original pixel-art textures.",
						descriptionZh:
							"Amoris 上的体素沙盒小岛：挖方块、搭方块，引擎的浅水会从挖开的岸边涌出、从放下的水块流开、灌进挖出的坑。贴图为原创像素画。",
					},
					{
						title: "PocketTerraria",
						video: { src: "/assets/projects/pocket-terraria.mp4", poster: "/assets/projects/pocket-terraria.jpg" },
						href: "/assets/projects/pocket-terraria.mp4",
						linkLabel: "Watch",
						tags: ["pocket2d", "Sandbox", "Bosses"],
						description:
							"A Terraria-style sandbox built to test pocket2d, through the whole progression to the Moon Lord. Shown as a video only; it is not released.",
						descriptionZh:
							"为检验 pocket2d 做的泰拉瑞亚式沙盒，完整流程一直打到月亮领主。只展示视频，不发布。",
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
