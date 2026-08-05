type MermaidApi = (typeof import("mermaid"))["default"];

type SkillsWindow = Window & {
	__skillsMermaidObserver?: MutationObserver;
	__skillsMermaidTheme?: string;
};

const skillsWindow = window as SkillsWindow;
let mermaidPromise: Promise<MermaidApi> | undefined;
let renderQueue = Promise.resolve();

function loadMermaid(): Promise<MermaidApi> {
	mermaidPromise ??= import("mermaid").then(({ default: mermaid }) => mermaid);
	return mermaidPromise;
}

function prepareDiagrams(): HTMLElement[] {
	document
		.querySelectorAll<HTMLElement>(
			".workflow-body pre > code.language-mermaid",
		)
		.forEach((code) => {
			const source = code.textContent?.trim();
			const pre = code.parentElement;
			if (!source || !pre) return;
			const diagram = document.createElement("div");
			diagram.className = "mermaid mermaid-diagram";
			diagram.dataset.source = source;
			diagram.textContent = source;
			pre.replaceWith(diagram);
		});

	return Array.from(
		document.querySelectorAll<HTMLElement>(
			".workflow-body .mermaid-diagram",
		),
	);
}

async function renderDiagrams() {
	const diagrams = prepareDiagrams();
	if (diagrams.length === 0) return;

	const dark = document.documentElement.classList.contains("dark");
	const theme = dark ? "dark" : "light";
	if (
		skillsWindow.__skillsMermaidTheme === theme &&
		diagrams.every((diagram) => diagram.dataset.processed === "true")
	) {
		return;
	}

	for (const diagram of diagrams) {
		diagram.removeAttribute("data-processed");
		diagram.classList.remove("has-error");
		diagram.textContent = diagram.dataset.source ?? "";
	}

	const mermaid = await loadMermaid();
	const connectedDiagrams = diagrams.filter((diagram) => diagram.isConnected);
	if (connectedDiagrams.length === 0) return;

	const rootStyle = getComputedStyle(document.documentElement);
	const color = (name: string) => rootStyle.getPropertyValue(name).trim();
	mermaid.initialize({
		startOnLoad: false,
		securityLevel: "strict",
		theme: "base",
		flowchart: { curve: "basis", htmlLabels: true },
		themeVariables: {
			background: color("--page-bg"),
			primaryColor: color("--card-bg"),
			primaryTextColor: color("--text-strong"),
			primaryBorderColor: color("--primary"),
			lineColor: color("--text-muted"),
			secondaryColor: color("--surface-hover"),
			tertiaryColor: color("--surface-deep"),
			edgeLabelBackground: color("--page-bg"),
		},
	});

	try {
		await mermaid.run({ nodes: connectedDiagrams });
		skillsWindow.__skillsMermaidTheme = theme;
	} catch (error) {
		console.error("Unable to render a workflow diagram.", error);
		for (const diagram of connectedDiagrams) {
			if (diagram.dataset.processed === "true") continue;
			diagram.classList.add("has-error");
			diagram.textContent = diagram.dataset.source ?? "";
		}
	}
}

function queueDiagramRendering() {
	renderQueue = renderQueue.then(renderDiagrams).catch((error) => {
		console.error("Unable to initialize workflow diagrams.", error);
	});
}

export function startSkillsMermaid() {
	queueDiagramRendering();
	skillsWindow.__skillsMermaidObserver?.disconnect();
	skillsWindow.__skillsMermaidObserver = new MutationObserver(
		queueDiagramRendering,
	);
	skillsWindow.__skillsMermaidObserver.observe(document.documentElement, {
		attributes: true,
		attributeFilter: ["class"],
	});
}
