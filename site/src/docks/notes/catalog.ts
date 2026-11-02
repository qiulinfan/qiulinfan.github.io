export const noteSubjectLabels = {
	math: "Math",
	cs: "EECS",
} as const;

export type NoteSubject = keyof typeof noteSubjectLabels;

// One node per subject on the notes page. `source` names a listed course in the
// notes registry (courses.json); a node without one is still being written.
// `col` and `row` place the node on the prerequisite tree, which reads left to right.
export interface NoteTreeNode {
	id: string;
	label: string;
	subject: NoteSubject;
	col: number;
	row: number;
	source?: string;
	prerequisites: string[];
}

export const noteTree: NoteTreeNode[] = [
	{ id: "linear-algebra", label: "Linear Algebra", subject: "math", col: 0, row: 1, source: "math:everything-about-linear-algebra", prerequisites: [] },
	{ id: "analysis", label: "Analysis", subject: "math", col: 0, row: 3, source: "math:single-and-multivariate-mathematical-analysis", prerequisites: [] },
	{ id: "cpp", label: "C++ Programming", subject: "cs", col: 0, row: 5, source: "cs:cpp-programming", prerequisites: [] },
	{ id: "abstract-algebra", label: "Abstract Algebra", subject: "math", col: 1, row: 0, source: "math:a-bit-of-abstract-algebra", prerequisites: ["linear-algebra"] },
	{ id: "topology", label: "Point-Set Topology", subject: "math", col: 1, row: 2, prerequisites: ["analysis"] },
	{ id: "measure-theory", label: "Measure Theory", subject: "math", col: 1, row: 3, source: "math:measure-theory", prerequisites: ["analysis"] },
	{ id: "dsa", label: "Data Structures & Algorithms", subject: "cs", col: 1, row: 5, source: "cs:data-structures-algorithms", prerequisites: ["cpp"] },
	{ id: "computer-organization", label: "Computer Organization", subject: "cs", col: 1, row: 6, prerequisites: ["cpp"] },
	{ id: "optimization", label: "Optimization (SIPML)", subject: "cs", col: 2, row: 1, prerequisites: ["linear-algebra", "analysis"] },
	{ id: "probability", label: "Probability Theory", subject: "math", col: 2, row: 3, source: "math:probability", prerequisites: ["measure-theory"] },
	{ id: "graphics", label: "Computer Graphics", subject: "cs", col: 2, row: 4, prerequisites: ["linear-algebra", "cpp"] },
	{ id: "operating-systems", label: "Operating Systems", subject: "cs", col: 2, row: 6, prerequisites: ["computer-organization", "dsa"] },
	{ id: "machine-learning", label: "Machine Learning", subject: "cs", col: 3, row: 2, prerequisites: ["optimization", "probability"] },
	{ id: "computer-networks", label: "Computer Networks", subject: "cs", col: 3, row: 6, prerequisites: ["operating-systems"] },
	{ id: "computer-vision", label: "Computer Vision", subject: "cs", col: 4, row: 2, prerequisites: ["machine-learning", "graphics"] },
	{ id: "nlp", label: "Natural Language Processing", subject: "cs", col: 4, row: 3, prerequisites: ["machine-learning"] },
];
