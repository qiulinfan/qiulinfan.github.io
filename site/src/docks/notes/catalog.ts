export interface PendingNote {
	title: string;
}

export const noteSubjectLabels = {
	math: "Math",
	cs: "EECS",
} as const;

export const pendingNotes: Record<keyof typeof noteSubjectLabels, PendingNote[]> = {
	math: [
		{ title: "Point-Set Topology" },
	],
	cs: [
		{ title: "Computer Organization" },
		{ title: "Operating Systems" },
		{ title: "Machine Learning" },
		{ title: "Optimization Methods for SIPML" },
		{ title: "Computer Networks" },
		{ title: "Computer Vision" },
		{ title: "Natural Language Processing" },
		{ title: "Computer Graphics" },
	],
};
