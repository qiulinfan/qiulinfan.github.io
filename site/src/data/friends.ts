export interface FriendLink {
	name: string;
	href: string;
	description: string;
	descriptionZh: string;
	avatar?: string;
}

export const friendLinks: FriendLink[] = [
	{
		name: "Hyacehila",
		href: "https://hyacehila.github.io/",
		description: "AI Agent Researcher",
		descriptionZh: "AI Agent 研究者",
	},
	{
		name: "ChunyeYang.github.io",
		href: "https://github.com/ChunyeYang/ChunyeYang.github.io",
		description: "Mathematician",
		descriptionZh: "数学研究者",
	},
	{
		name: "Hideonb8sh.github.io",
		href: "https://github.com/Hideonb8sh/Hideonb8sh.github.io",
		description: "DL Theory Researcher",
		descriptionZh: "深度学习理论研究者",
	},
	{
		name: "yijiangt.github.io",
		href: "https://yijiangt.github.io",
		description: "Distributed Systems & ML Systems Engineer",
		descriptionZh: "分布式系统与机器学习系统工程师",
	},
];
