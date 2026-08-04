export const homepageLinks = {
	pocketEngine: "https://qiulinfan.github.io/pocketEngine/",
	pocketEngineRepository: "https://github.com/qiulinfan/pocketEngine",
} as const;

export const projects = [
	{
		id: "village-rim",
		title: "Village Rim",
		image: "/assets/village-rim.webp",
		href: "https://bluesamoyed.itch.io/village-rim",
		tags: ["Unity", "Combat AI", "Level Design"],
		description:
			"A compact 2D adventure built with a four-person team. I owned combat, enemy behavior, animation integration, spawning, and level design.",
		descriptionZh:
			"四人合作完成的 2D 冒险游戏；我负责战斗、敌人行为、动画集成、生成系统与关卡设计。",
	},
	{
		id: "zelda-1986",
		title: "Zelda 1986 · Level 1",
		image: "/assets/zelda-1986.webp",
		href: "https://bluesamoyed.itch.io/zelda1986-level1",
		tags: ["Gameplay Systems", "Enemy AI", "Tools"],
		description:
			"A recreation of the original dungeon with enemy AI, room control, weapons, health systems, custom shadows, and animation work.",
		descriptionZh:
			"对初代地牢的重制；包含敌人 AI、房间控制、武器、生命系统、自定义阴影与动画。",
	},
] as const;
