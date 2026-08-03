<script lang="ts">
	import { onMount, tick } from "svelte";

	export let dataUrl: string;

	type NodeType = "discipline" | "field" | "topic" | "knowledge";

	type Properties = Record<string, unknown>;

	interface GraphNode {
		id: string;
		type: NodeType;
		label: string;
		text: string;
		properties?: Properties;
		provenance?: {
			authority?: string;
			line?: number;
			anchor?: string;
			web?: string;
			active?: boolean;
		};
	}

	interface GraphEdge {
		source: string;
		relation: string;
		target: string;
		origin?: string;
		confidence?: string;
		evidence?: string;
	}

	interface GraphReference {
		id: string;
		target: string;
		label: string;
		authority: string;
		line: number;
		web?: string;
		context?: string;
	}

	interface Diagnostic {
		code: string;
		message: string;
		source?: string;
		node?: string;
	}

	interface GraphPayload {
		manifest: {
			graph_sha256: string;
			counts: { nodes: number; edges: number; references: number };
			node_types: Record<string, number>;
			relations: Record<string, number>;
		};
		diagnostics: {
			warnings: Diagnostic[];
			errors: Diagnostic[];
		};
		nodes: GraphNode[];
		edges: GraphEdge[];
		references: GraphReference[];
	}

	interface Neighbor {
		node: GraphNode;
		edge: GraphEdge;
		direction: "incoming" | "outgoing";
	}

	interface PositionedNode {
		id: string;
		x: number;
		y: number;
		radius: number;
		ring: number;
	}

	const typeOrder: NodeType[] = ["discipline", "field", "topic", "knowledge"];

	const typeLabels: Record<NodeType, string> = {
		discipline: "学科",
		field: "领域",
		topic: "主题",
		knowledge: "知识",
	};

	const relationLabels: Record<string, string> = {
		contains: "包含",
		"prerequisite-for": "前置于",
		implies: "蕴含",
		generalizes: "推广",
		"contrasts-with": "对照",
		"derived-from": "导出自",
	};

	let payload: GraphPayload | null = null;
	let loading = true;
	let loadError = "";
	let query = "";
	let selectedType: NodeType | "all" = "all";
	let selectedId = "";
	let selectedNode: GraphNode | null = null;
	let results: GraphNode[] = [];
	let neighbors: Neighbor[] = [];
	let backlinks: GraphReference[] = [];
	let nodeIndex = new Map<string, GraphNode>();
	let activePanel: "detail" | "diagnostics" = "detail";
	let copied = false;
	let canvas: HTMLCanvasElement;
	let canvasHost: HTMLDivElement;
	let hitNodes: PositionedNode[] = [];
	let hoveredId = "";
	let tooltipX = 0;
	let tooltipY = 0;
	let resizeObserver: ResizeObserver | null = null;

	function normalize(value: string) {
		return value.toLocaleLowerCase().normalize("NFKC");
	}

	function stringList(node: GraphNode, key: string): string[] {
		const value = node.properties?.[key];
		if (Array.isArray(value)) {
			return value.map(String).filter(Boolean);
		}
		return value ? [String(value)] : [];
	}

	function propertyText(node: GraphNode, key: string): string {
		const value = node.properties?.[key];
		return value === undefined || value === null ? "" : String(value);
	}

	function escapeHtml(value: string): string {
		return value
			.replaceAll("&", "&amp;")
			.replaceAll("<", "&lt;")
			.replaceAll(">", "&gt;")
			.replaceAll('"', "&quot;")
			.replaceAll("'", "&#39;");
	}

	function nodeLabelHtml(node: GraphNode): string {
		return propertyText(node, "label_html") || escapeHtml(node.label);
	}

	function searchableText(node: GraphNode) {
		return normalize(
			[
				node.label,
				node.id,
				node.text,
				...stringList(node, "aliases"),
				propertyText(node, "course"),
				propertyText(node, "topic"),
			].join(" "),
		);
	}

	function searchScore(node: GraphNode, terms: string[]) {
		if (terms.length === 0) {
			const evidence = Number(node.properties?.evidence_count ?? 0);
			const typeBias = node.type === "knowledge" ? 80 : node.type === "topic" ? 40 : 0;
			return typeBias + Math.min(evidence, 20);
		}

		const label = normalize(node.label);
		const aliases = normalize(stringList(node, "aliases").join(" "));
		const id = normalize(node.id);
		const haystack = searchableText(node);
		if (!terms.every((term) => haystack.includes(term))) return -1;

		let score = 0;
		for (const term of terms) {
			if (label === term) score += 160;
			else if (label.startsWith(term)) score += 100;
			else if (label.includes(term)) score += 70;
			if (aliases.includes(term)) score += 55;
			if (id.includes(term)) score += 25;
		}
		if (node.type === "knowledge") score += 14;
		if (node.type === "topic") score += 8;
		return score;
	}

	function updateResults() {
		if (!payload) {
			results = [];
			return;
		}
		const terms = normalize(query).split(/\s+/).filter(Boolean);
		results = payload.nodes
			.filter((node) => selectedType === "all" || node.type === selectedType)
			.map((node) => ({ node, score: searchScore(node, terms) }))
			.filter((item) => item.score >= 0)
			.sort((left, right) => right.score - left.score || left.node.label.localeCompare(right.node.label))
			.slice(0, 80)
			.map((item) => item.node);
	}

	function updateSelection() {
		selectedNode = selectedId ? nodeIndex.get(selectedId) ?? null : null;
		if (!selectedNode || !payload) {
			neighbors = [];
			backlinks = [];
			return;
		}
		backlinks = payload.references
			.filter((reference) => reference.target === selectedId)
			.sort((left, right) => left.authority.localeCompare(right.authority) || left.line - right.line);
		neighbors = payload.edges
			.flatMap((edge): Neighbor[] => {
				if (edge.source === selectedId) {
					const node = nodeIndex.get(edge.target);
					return node ? [{ node, edge, direction: "outgoing" }] : [];
				}
				if (edge.target === selectedId) {
					const node = nodeIndex.get(edge.source);
					return node ? [{ node, edge, direction: "incoming" }] : [];
				}
				return [];
			})
			.sort(
				(left, right) =>
					left.edge.relation.localeCompare(right.edge.relation) ||
					left.node.label.localeCompare(right.node.label),
			);
	}

	function selectNode(id: string, updateHash = true) {
		if (!nodeIndex.has(id)) return;
		selectedId = id;
		activePanel = "detail";
		copied = false;
		if (updateHash && typeof window !== "undefined") {
			const hash = new URLSearchParams({ node: id }).toString();
			window.history.replaceState(null, "", `#${hash}`);
		}
		void tick().then(drawGraph);
	}

	function selectFromHash() {
		const id = new URLSearchParams(window.location.hash.slice(1)).get("node");
		if (id && nodeIndex.has(id)) selectNode(id, false);
	}

	function typeCount(type: NodeType) {
		return payload?.manifest.node_types[type] ?? 0;
	}

	function typeLabel(type: NodeType) {
		return typeLabels[type] ?? type;
	}

	function relationLabel(relation: string) {
		return relationLabels[relation] ?? relation;
	}

	function nodeColor(type: NodeType, alpha = 1) {
		const colors: Record<NodeType, string> = {
			discipline: `oklch(0.60 0.16 270 / ${alpha})`,
			field: `oklch(0.65 0.17 230 / ${alpha})`,
			topic: `oklch(0.72 0.14 150 / ${alpha})`,
			knowledge: `oklch(0.69 0.16 45 / ${alpha})`,
		};
		return colors[type];
	}

	function relationColor(relation: string) {
		if (relation === "prerequisite-for") {
			return "oklch(0.7 0.17 25 / 0.58)";
		}
		if (relation !== "contains") return "oklch(0.68 0.17 218 / 0.54)";
		return "oklch(0.58 0.03 250 / 0.28)";
	}

	function buildGraphSlice() {
		if (!payload || !selectedNode) return { nodes: [] as GraphNode[], edges: [] as GraphEdge[], ring: new Map<string, number>() };

		const ring = new Map<string, number>([[selectedNode.id, 0]]);
		const adjacentEdges = payload.edges.filter(
			(edge) => edge.source === selectedNode?.id || edge.target === selectedNode?.id,
		);
		const firstIds = Array.from(
			new Set(
				adjacentEdges.map((edge) =>
					edge.source === selectedNode?.id ? edge.target : edge.source,
				),
			),
		).slice(0, 24);
		for (const id of firstIds) ring.set(id, 1);

		const secondIds: string[] = [];
		for (const firstId of firstIds) {
			for (const edge of payload.edges) {
				if (secondIds.length >= 28) break;
				if (edge.source !== firstId && edge.target !== firstId) continue;
				const other = edge.source === firstId ? edge.target : edge.source;
				if (!ring.has(other)) {
					ring.set(other, 2);
					secondIds.push(other);
				}
			}
			if (secondIds.length >= 28) break;
		}

		const ids = new Set([selectedNode.id, ...firstIds, ...secondIds]);
		const nodes = Array.from(ids)
			.map((id) => nodeIndex.get(id))
			.filter((node): node is GraphNode => Boolean(node));
		const edges = payload.edges.filter(
			(edge) => ids.has(edge.source) && ids.has(edge.target),
		);
		return { nodes, edges, ring };
	}

	function truncate(value: string, length: number) {
		return value.length <= length ? value : `${value.slice(0, length - 1)}…`;
	}

	function drawGraph() {
		if (!canvas || !canvasHost || !payload || !selectedNode) return;
		const width = Math.max(canvasHost.clientWidth, 320);
		const height = Math.max(canvasHost.clientHeight, 360);
		const ratio = window.devicePixelRatio || 1;
		canvas.width = Math.floor(width * ratio);
		canvas.height = Math.floor(height * ratio);
		canvas.style.width = `${width}px`;
		canvas.style.height = `${height}px`;
		const context = canvas.getContext("2d");
		if (!context) return;
		context.scale(ratio, ratio);
		context.clearRect(0, 0, width, height);

		const { nodes, edges, ring } = buildGraphSlice();
		const centerX = width / 2;
		const centerY = height / 2;
		const shortest = Math.min(width, height);
		const ringOneRadius = Math.max(92, shortest * 0.26);
		const ringTwoRadius = Math.max(155, shortest * 0.43);
		const rings = {
			1: nodes.filter((node) => ring.get(node.id) === 1),
			2: nodes.filter((node) => ring.get(node.id) === 2),
		};
		const positions = new Map<string, PositionedNode>();
		positions.set(selectedNode.id, {
			id: selectedNode.id,
			x: centerX,
			y: centerY,
			radius: 13,
			ring: 0,
		});

		for (const ringNumber of [1, 2] as const) {
			const group = rings[ringNumber];
			const radius = ringNumber === 1 ? ringOneRadius : ringTwoRadius;
			group.forEach((node, index) => {
				const angle = -Math.PI / 2 + (Math.PI * 2 * index) / Math.max(group.length, 1);
				positions.set(node.id, {
					id: node.id,
					x: centerX + Math.cos(angle) * radius,
					y: centerY + Math.sin(angle) * radius,
					radius: ringNumber === 1 ? 9 : 5.5,
					ring: ringNumber,
				});
			});
		}

		for (const edge of edges) {
			const from = positions.get(edge.source);
			const to = positions.get(edge.target);
			if (!from || !to) continue;
			const angle = Math.atan2(to.y - from.y, to.x - from.x);
			const startX = from.x + Math.cos(angle) * (from.radius + 2);
			const startY = from.y + Math.sin(angle) * (from.radius + 2);
			const endX = to.x - Math.cos(angle) * (to.radius + 4);
			const endY = to.y - Math.sin(angle) * (to.radius + 4);
			const color = relationColor(edge.relation);
			context.beginPath();
			context.moveTo(startX, startY);
			context.lineTo(endX, endY);
			context.strokeStyle = color;
			context.lineWidth = edge.relation === "contains" ? 0.8 : 1.35;
			context.stroke();
			context.beginPath();
			context.moveTo(endX, endY);
			context.lineTo(
				endX - Math.cos(angle - Math.PI / 6) * 6,
				endY - Math.sin(angle - Math.PI / 6) * 6,
			);
			context.lineTo(
				endX - Math.cos(angle + Math.PI / 6) * 6,
				endY - Math.sin(angle + Math.PI / 6) * 6,
			);
			context.closePath();
			context.fillStyle = color;
			context.fill();
		}

		const styles = getComputedStyle(document.documentElement);
		const haloColor = styles.getPropertyValue("--card-bg").trim() || "white";

		for (const node of nodes.sort((left, right) => (ring.get(right.id) ?? 0) - (ring.get(left.id) ?? 0))) {
			const position = positions.get(node.id);
			if (!position) continue;
			context.beginPath();
			context.arc(position.x, position.y, position.radius + 3, 0, Math.PI * 2);
			context.fillStyle = haloColor;
			context.fill();
			context.beginPath();
			context.arc(position.x, position.y, position.radius, 0, Math.PI * 2);
			context.fillStyle = nodeColor(node.type, position.ring === 2 ? 0.72 : 1);
			context.fill();
			if (node.id === hoveredId) {
				context.strokeStyle = nodeColor(node.type, 1);
				context.lineWidth = 2;
				context.stroke();
			}
		}
		hitNodes = Array.from(positions.values());
	}

	function canvasPoint(event: MouseEvent) {
		const bounds = canvas.getBoundingClientRect();
		return { x: event.clientX - bounds.left, y: event.clientY - bounds.top };
	}

	function hitTest(event: MouseEvent) {
		const point = canvasPoint(event);
		return [...hitNodes]
			.reverse()
			.find((node) => Math.hypot(node.x - point.x, node.y - point.y) <= node.radius + 7);
	}

	function handleCanvasMove(event: MouseEvent) {
		const hit = hitTest(event);
		hoveredId = hit?.id ?? "";
		if (hit) {
			const bounds = canvas.getBoundingClientRect();
			tooltipX = event.clientX - bounds.left + 12;
			tooltipY = event.clientY - bounds.top + 12;
		}
		canvas.style.cursor = hit ? "pointer" : "default";
		drawGraph();
	}

	function handleCanvasClick(event: MouseEvent) {
		const hit = hitTest(event);
		if (hit) selectNode(hit.id);
	}

	async function copyNodeReference() {
		if (!selectedNode) return;
		const source = selectedNode.provenance?.authority;
		const value = source ? `${selectedNode.id}\n${source}` : selectedNode.id;
		await navigator.clipboard.writeText(value);
		copied = true;
		window.setTimeout(() => (copied = false), 1600);
	}

	function sourceUrl(node: GraphNode) {
		return node.provenance?.web ?? "";
	}

	function sourceCodeUrl(node: GraphNode) {
		const path = node.provenance?.authority;
		return path ? `https://github.com/qiulinfan/qlblog/blob/main/${path}` : "";
	}

	$: {
		query;
		selectedType;
		payload;
		updateResults();
	}
	$: {
		selectedId;
		payload;
		updateSelection();
	}
	$: {
		selectedId;
		payload;
		void tick().then(drawGraph);
	}

	onMount(() => {
		let cancelled = false;
		async function load() {
			try {
				const response = await fetch(dataUrl);
				if (!response.ok) throw new Error(`HTTP ${response.status}`);
				const graph = (await response.json()) as GraphPayload;
				if (cancelled) return;
				payload = graph;
				nodeIndex = new Map(graph.nodes.map((node) => [node.id, node]));
				const fromHash = new URLSearchParams(window.location.hash.slice(1)).get("node");
				const initial =
					(fromHash && nodeIndex.has(fromHash) && fromHash) ||
					(nodeIndex.has("conditional-expectation") && "conditional-expectation") ||
					graph.nodes.find((node) => node.type === "knowledge")?.id ||
					graph.nodes[0]?.id ||
					"";
				loading = false;
				if (initial) selectNode(initial, false);
				await tick();
				resizeObserver = new ResizeObserver(drawGraph);
				if (canvasHost) resizeObserver.observe(canvasHost);
			} catch (error) {
				if (cancelled) return;
				loading = false;
				loadError = error instanceof Error ? error.message : "Unknown error";
			}
		}

		void load();
		window.addEventListener("hashchange", selectFromHash);
		return () => {
			cancelled = true;
			resizeObserver?.disconnect();
			window.removeEventListener("hashchange", selectFromHash);
		};
	});
</script>

<section class="knowledge-shell" aria-labelledby="knowledge-title">
	<header class="hero-card">
		<div class="hero-copy">
			<div class="eyebrow"><span></span> PERSONAL KNOWLEDGE GRAPH</div>
			<h1 id="knowledge-title">找回你已经学过的东西。</h1>
			<p>从权威笔记生成的分层有向图。搜索知识节点，沿直接依赖与主题层级追踪，再回到唯一的原定义。</p>
		</div>
		{#if payload}
			<div class="stat-grid" aria-label="Graph summary">
				<div><strong>{payload.manifest.node_types.knowledge ?? 0}</strong><span>知识节点</span></div>
				<div><strong>{(payload.manifest.node_types.topic ?? 0) + (payload.manifest.node_types.field ?? 0) + (payload.manifest.node_types.discipline ?? 0)}</strong><span>层级节点</span></div>
				<div><strong>{payload.manifest.counts.edges}</strong><span>关系</span></div>
				<div class:warning={payload.diagnostics.warnings.length > 0}>
					<strong>{payload.diagnostics.warnings.length}</strong><span>待整理</span>
				</div>
			</div>
		{:else}
			<div class="stat-grid skeleton" aria-hidden="true"><div></div><div></div><div></div><div></div></div>
		{/if}
	</header>

	{#if loading}
		<div class="state-card"><span class="loader"></span><p>正在装载知识图谱…</p></div>
	{:else if loadError}
		<div class="state-card error-state"><strong>图谱暂时无法打开</strong><p>{loadError}</p></div>
	{:else if payload}
		<div class="toolbar-card">
			<label class="search-field">
				<span class="search-icon" aria-hidden="true"></span>
				<span class="sr-only">搜索知识图谱</span>
				<input bind:value={query} type="search" placeholder="搜索概念、别名、定理或正文…" autocomplete="off" />
				{#if query}<button type="button" aria-label="清除搜索" on:click={() => (query = "")}>×</button>{/if}
			</label>
			<div class="type-filters" aria-label="Node type filter">
				<button type="button" class:active={selectedType === "all"} on:click={() => (selectedType = "all")}>全部 <span>{payload.manifest.counts.nodes}</span></button>
				{#each typeOrder as type}
					<button type="button" class:active={selectedType === type} on:click={() => (selectedType = type)}>{typeLabel(type)} <span>{typeCount(type)}</span></button>
				{/each}
			</div>
		</div>

		<div class="workspace">
			<aside class="panel results-panel" aria-label="Search results">
				<div class="panel-heading">
					<div><span class="kicker">RECALL</span><h2>{query ? "检索结果" : "知识入口"}</h2></div>
					<span class="result-count">{results.length}{results.length === 80 ? "+" : ""}</span>
				</div>
				<div class="result-list">
					{#each results as node}
						<button type="button" class="result-item" class:selected={node.id === selectedId} on:click={() => selectNode(node.id)}>
							<span class="node-dot" style={`--node-color:${nodeColor(node.type)}`}></span>
							<span class="result-copy"><strong class="math-label">{@html nodeLabelHtml(node)}</strong><small>{typeLabel(node.type)} · {truncate(node.id, 48)}</small></span>
						</button>
					{:else}
						<div class="empty-list"><strong>没有匹配项</strong><span>换一个名称、别名或正文关键词试试。</span></div>
					{/each}
				</div>
			</aside>

			<section class="panel graph-panel" aria-label="Knowledge graph neighborhood">
				<div class="panel-heading graph-heading">
					<div><span class="kicker">LOCAL GRAPH</span><h2>两跳关系</h2></div>
					<div class="graph-legend">
						<span><i class="about"></i>语义</span><span><i class="structure"></i>结构</span>
					</div>
				</div>
				<div class="canvas-host" bind:this={canvasHost}>
					<canvas bind:this={canvas} aria-label="Selected node and its two-hop neighborhood" on:mousemove={handleCanvasMove} on:mouseleave={() => { hoveredId = ""; drawGraph(); }} on:click={handleCanvasClick}></canvas>
					{#each hitNodes.filter((position) => position.ring <= 1) as position (position.id)}
						{@const graphNode = nodeIndex.get(position.id)}
						{#if graphNode}
							<button
								type="button"
								class="graph-node-label math-label"
								class:selected={position.ring === 0}
								style={`left:${position.x}px;top:${position.y + position.radius + 7}px`}
								aria-label={graphNode.label}
								on:mouseenter={() => { hoveredId = position.id; tooltipX = position.x + 12; tooltipY = position.y + 12; drawGraph(); }}
								on:mouseleave={() => { hoveredId = ""; drawGraph(); }}
								on:click={() => selectNode(position.id)}
							>{@html nodeLabelHtml(graphNode)}</button>
						{/if}
					{/each}
					{#if hoveredId}
						{@const hoveredNode = nodeIndex.get(hoveredId)}
						<div class="graph-tooltip" style={`left:${tooltipX}px;top:${tooltipY}px`}>
							{#if hoveredNode}<strong class="math-label">{@html nodeLabelHtml(hoveredNode)}</strong><span>{typeLabel(hoveredNode.type)}</span>{/if}
						</div>
					{/if}
					<div class="canvas-note">点击节点继续追踪 · 外圈为第二跳</div>
				</div>
			</section>

			<aside class="panel detail-panel" aria-label="Node detail">
				<div class="panel-tabs" role="tablist" aria-label="Detail panels">
					<button type="button" role="tab" aria-selected={activePanel === "detail"} class:active={activePanel === "detail"} on:click={() => (activePanel = "detail")}>节点</button>
					<button type="button" role="tab" aria-selected={activePanel === "diagnostics"} class:active={activePanel === "diagnostics"} on:click={() => (activePanel = "diagnostics")}>诊断 <span>{payload.diagnostics.warnings.length}</span></button>
				</div>

				{#if activePanel === "detail" && selectedNode}
					<div class="detail-scroll">
						<div class="node-heading">
							<span class="type-pill" style={`--node-color:${nodeColor(selectedNode.type)}`}>{typeLabel(selectedNode.type)}</span>
							<h2 class="math-label">{@html nodeLabelHtml(selectedNode)}</h2>
							<code>{selectedNode.id}</code>
						</div>

						{#if propertyText(selectedNode, "kind")}
							<div class="attribute-row"><span>类别</span><strong>{propertyText(selectedNode, "kind")}</strong></div>
						{/if}
						{#if stringList(selectedNode, "aliases").length}
							<div class="detail-block"><h3>别名</h3><div class="chip-list">{#each stringList(selectedNode, "aliases") as alias}<span>{alias}</span>{/each}</div></div>
						{/if}
						{#if propertyText(selectedNode, "source_status")}
							<div class="attribute-row"><span>来源状态</span><strong>{propertyText(selectedNode, "source_status")}</strong></div>
						{/if}
						{#if propertyText(selectedNode, "course")}
							<div class="attribute-row"><span>课程</span><strong>{propertyText(selectedNode, "course")}</strong></div>
						{/if}

						{#if selectedNode.text}
							<div class="detail-block"><h3>词条</h3><div class="evidence-text">{selectedNode.text}</div></div>
						{/if}

						{#if neighbors.length}
							<div class="detail-block"><h3>关系 <span>{neighbors.length}</span></h3><div class="neighbor-list">
								{#each neighbors.slice(0, 48) as neighbor}
									<button type="button" on:click={() => selectNode(neighbor.node.id)}>
										<span class="relation-arrow">{neighbor.direction === "outgoing" ? "→" : "←"}</span>
										<span><small>{relationLabel(neighbor.edge.relation)}</small><strong class="math-label">{@html nodeLabelHtml(neighbor.node)}</strong></span>
									</button>
								{/each}
							</div></div>
						{/if}

						{#if backlinks.length}
							<div class="detail-block"><h3>反向引用 <span>{backlinks.length}</span></h3><div class="neighbor-list">
								{#each backlinks as backlink}
									<a class="backlink-item" href={backlink.web || `https://github.com/qiulinfan/qlblog/blob/main/${backlink.authority}#L${backlink.line}`} target="_blank" rel="noreferrer">
										<span class="relation-arrow">↩</span><span><small>{backlink.label}</small><strong>{backlink.authority}:{backlink.line}</strong></span>
									</a>
								{/each}
							</div></div>
						{/if}

						<div class="source-actions">
							<button type="button" on:click={copyNodeReference}>{copied ? "已复制" : "复制引用"}</button>
							{#if sourceUrl(selectedNode)}<a href={sourceUrl(selectedNode)} target="_blank" rel="noreferrer">打开原定义 ↗</a>{/if}
							{#if sourceCodeUrl(selectedNode)}<a href={sourceCodeUrl(selectedNode)} target="_blank" rel="noreferrer">查看 Typst 源码 ↗</a>{/if}
						</div>
						{#if selectedNode.provenance?.authority}<p class="source-path">{selectedNode.provenance.authority}</p>{/if}
					</div>
				{:else if activePanel === "diagnostics"}
					<div class="detail-scroll diagnostic-scroll">
						<div class="diagnostic-summary"><strong>{payload.diagnostics.warnings.length}</strong><span>个非阻塞质量提示</span><p>这里会明确显示孤立节点和未解析引用，但不会静默删除已沉淀的知识。</p></div>
						{#each payload.diagnostics.warnings as warning}
							<button type="button" class="diagnostic-item" disabled={!warning.node || !nodeIndex.has(warning.node)} on:click={() => warning.node && selectNode(warning.node)}>
								<span>{warning.code}</span><strong>{warning.message}</strong>{#if warning.source}<small>{warning.source}</small>{/if}
							</button>
						{/each}
					</div>
				{/if}
			</aside>
		</div>

		<footer class="graph-meta">
			<span><i></i> Typst authority · qlkg-v2</span>
			<code>{payload.manifest.graph_sha256.slice(0, 12)}</code>
		</footer>
	{/if}
</section>

<style>
	:global(body) { background: var(--page-bg); }
	.knowledge-shell { --panel-border: color-mix(in oklch, var(--line-divider) 78%, transparent); display: flex; flex-direction: column; gap: 1rem; color: color-mix(in oklch, currentColor 82%, transparent); }
	.hero-card, .toolbar-card, .panel, .state-card { background: var(--card-bg); border: 1px solid var(--panel-border); box-shadow: 0 18px 55px rgba(25, 35, 55, .055); }
	.hero-card { min-height: 11rem; border-radius: 1.25rem; padding: 2rem 2.25rem; display: flex; align-items: flex-end; justify-content: space-between; gap: 2rem; overflow: hidden; position: relative; }
	.hero-card::before { content: ""; position: absolute; width: 26rem; height: 26rem; right: -10rem; top: -17rem; border: 1px solid color-mix(in oklch, var(--primary) 22%, transparent); border-radius: 50%; box-shadow: 0 0 0 3.5rem color-mix(in oklch, var(--primary) 3%, transparent), 0 0 0 7rem color-mix(in oklch, var(--primary) 2%, transparent); pointer-events: none; }
	.hero-copy { position: relative; z-index: 1; max-width: 46rem; }
	.eyebrow, .kicker { font: 700 .68rem/1.2 "JetBrains Mono Variable", monospace; letter-spacing: .15em; color: var(--primary); }
	.eyebrow { display: flex; align-items: center; gap: .55rem; margin-bottom: .75rem; }
	.eyebrow span { width: 1.25rem; height: 2px; background: var(--primary); }
	h1 { margin: 0; font-size: clamp(1.8rem, 3.6vw, 3.25rem); line-height: 1.08; letter-spacing: -.045em; color: color-mix(in oklch, currentColor 92%, transparent); }
	.hero-copy p { max-width: 42rem; margin: .8rem 0 0; line-height: 1.65; color: color-mix(in oklch, currentColor 54%, transparent); }
	.stat-grid { position: relative; z-index: 1; display: grid; grid-template-columns: repeat(4, minmax(4.4rem, 1fr)); gap: .55rem; min-width: 22rem; }
	.stat-grid div { min-height: 4.5rem; border-radius: .85rem; padding: .8rem .9rem; display: flex; flex-direction: column; justify-content: center; background: color-mix(in oklch, var(--page-bg) 58%, transparent); border: 1px solid var(--panel-border); }
	.stat-grid strong { font: 650 1.25rem/1 "JetBrains Mono Variable", monospace; color: color-mix(in oklch, currentColor 86%, transparent); }
	.stat-grid span { margin-top: .4rem; font-size: .72rem; color: color-mix(in oklch, currentColor 42%, transparent); }
	.stat-grid .warning strong { color: oklch(.69 .15 60); }
	.stat-grid.skeleton div { animation: pulse 1.4s infinite alternate; }
	.toolbar-card { border-radius: 1rem; padding: .75rem; display: flex; align-items: center; gap: .75rem; }
	.search-field { flex: 1 1 25rem; height: 3rem; position: relative; display: flex; align-items: center; border-radius: .75rem; background: color-mix(in oklch, var(--page-bg) 62%, transparent); border: 1px solid transparent; transition: border-color .2s, background .2s; }
	.search-field:focus-within { border-color: color-mix(in oklch, var(--primary) 55%, transparent); background: var(--card-bg); }
	.search-icon { width: .82rem; height: .82rem; margin-left: 1rem; border: 2px solid color-mix(in oklch, currentColor 35%, transparent); border-radius: 50%; position: relative; }
	.search-icon::after { content: ""; position: absolute; width: .42rem; height: 2px; right: -.34rem; bottom: -.18rem; background: color-mix(in oklch, currentColor 35%, transparent); transform: rotate(45deg); border-radius: 1rem; }
	.search-field input { width: 100%; min-width: 0; height: 100%; padding: 0 2.5rem 0 .85rem; background: transparent; border: 0; outline: 0; color: inherit; font-size: .92rem; }
	.search-field > button { position: absolute; right: .65rem; width: 1.8rem; height: 1.8rem; border: 0; border-radius: .5rem; background: transparent; color: color-mix(in oklch, currentColor 45%, transparent); cursor: pointer; font-size: 1.25rem; }
	.type-filters { display: flex; gap: .35rem; overflow-x: auto; padding-bottom: 1px; scrollbar-width: none; }
	.type-filters::-webkit-scrollbar { display: none; }
	.type-filters button { flex: none; height: 2.4rem; padding: 0 .72rem; border-radius: .65rem; border: 1px solid transparent; background: transparent; color: color-mix(in oklch, currentColor 54%, transparent); font-size: .76rem; font-weight: 600; cursor: pointer; transition: .2s; }
	.type-filters button:hover { background: var(--btn-plain-bg-hover); }
	.type-filters button.active { color: var(--primary); background: color-mix(in oklch, var(--primary) 10%, transparent); border-color: color-mix(in oklch, var(--primary) 18%, transparent); }
	.type-filters span { margin-left: .25rem; opacity: .58; font-family: "JetBrains Mono Variable", monospace; font-size: .66rem; }
	.workspace { display: grid; grid-template-columns: minmax(15rem, .76fr) minmax(25rem, 1.42fr) minmax(18rem, .94fr); gap: 1rem; min-height: 42rem; height: calc(100vh - 21rem); max-height: 52rem; }
	.panel { border-radius: 1rem; min-width: 0; overflow: hidden; }
	.panel-heading { min-height: 4.6rem; padding: 1rem 1.1rem .85rem; display: flex; align-items: flex-end; justify-content: space-between; border-bottom: 1px solid var(--panel-border); }
	.panel-heading h2 { margin: .22rem 0 0; color: color-mix(in oklch, currentColor 84%, transparent); font-size: 1rem; letter-spacing: -.015em; }
	.result-count { min-width: 2rem; height: 1.6rem; padding: 0 .45rem; border-radius: 999px; display: grid; place-items: center; background: var(--btn-regular-bg); color: var(--btn-content); font: 600 .68rem/1 "JetBrains Mono Variable", monospace; }
	.result-list { height: calc(100% - 4.6rem); overflow-y: auto; padding: .45rem; }
	.result-item { width: 100%; min-height: 4.15rem; padding: .7rem .72rem; display: flex; align-items: flex-start; gap: .7rem; text-align: left; border: 1px solid transparent; border-radius: .72rem; background: transparent; color: inherit; cursor: pointer; transition: .16s; }
	.result-item:hover { background: var(--btn-plain-bg-hover); }
	.result-item.selected { background: color-mix(in oklch, var(--primary) 9%, transparent); border-color: color-mix(in oklch, var(--primary) 18%, transparent); }
	.node-dot { flex: none; width: .5rem; height: .5rem; margin-top: .3rem; border-radius: 50%; background: var(--node-color); box-shadow: 0 0 0 3px color-mix(in oklch, var(--node-color) 16%, transparent); }
	.result-copy { min-width: 0; display: flex; flex-direction: column; gap: .32rem; }
	.result-copy strong { font-size: .79rem; line-height: 1.35; color: color-mix(in oklch, currentColor 78%, transparent); overflow-wrap: anywhere; }
	.result-copy small { font: 500 .62rem/1.35 "JetBrains Mono Variable", monospace; color: color-mix(in oklch, currentColor 36%, transparent); overflow-wrap: anywhere; }
	.empty-list { min-height: 12rem; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: .35rem; padding: 1.5rem; text-align: center; color: color-mix(in oklch, currentColor 40%, transparent); }
	.empty-list strong { font-size: .85rem; }
	.empty-list span { font-size: .72rem; }
	.graph-panel { display: flex; flex-direction: column; }
	.graph-heading { flex: none; }
	.graph-legend { display: flex; gap: .75rem; font-size: .64rem; color: color-mix(in oklch, currentColor 38%, transparent); }
	.graph-legend span { display: flex; align-items: center; gap: .3rem; }
	.graph-legend i { width: 1.3rem; height: 2px; border-radius: 1rem; }
	.graph-legend .about { background: oklch(.68 .17 218 / .65); }
	.graph-legend .structure { background: oklch(.58 .03 250 / .35); }
	.canvas-host { flex: 1; min-height: 0; position: relative; overflow: hidden; background-image: radial-gradient(circle at center, color-mix(in oklch, var(--primary) 7%, transparent) 0, transparent 52%), radial-gradient(color-mix(in oklch, currentColor 9%, transparent) .7px, transparent .7px); background-size: auto, 18px 18px; }
	.canvas-host canvas { display: block; }
	.graph-node-label { position: absolute; z-index: 2; width: max-content; max-width: 8.5rem; padding: .1rem .25rem; transform: translateX(-50%); border: 0; border-radius: .3rem; background: color-mix(in oklch, var(--card-bg) 82%, transparent); color: color-mix(in oklch, currentColor 72%, transparent); font-size: .61rem; font-weight: 520; line-height: 1.25; text-align: center; cursor: pointer; backdrop-filter: blur(3px); }
	.graph-node-label.selected { z-index: 3; max-width: 12rem; color: color-mix(in oklch, currentColor 84%, transparent); font-size: .74rem; font-weight: 650; }
	.graph-node-label:hover { color: var(--primary); }
	.canvas-note { position: absolute; left: 50%; bottom: .8rem; transform: translateX(-50%); white-space: nowrap; padding: .4rem .65rem; border-radius: 999px; background: color-mix(in oklch, var(--card-bg) 86%, transparent); border: 1px solid var(--panel-border); backdrop-filter: blur(8px); color: color-mix(in oklch, currentColor 38%, transparent); font-size: .62rem; }
	.graph-tooltip { position: absolute; z-index: 5; max-width: 13rem; padding: .48rem .58rem; display: flex; flex-direction: column; gap: .15rem; pointer-events: none; border-radius: .55rem; background: color-mix(in oklch, var(--card-bg) 92%, transparent); border: 1px solid var(--panel-border); box-shadow: 0 8px 24px rgba(15, 25, 45, .12); backdrop-filter: blur(10px); }
	.graph-tooltip strong { font-size: .7rem; line-height: 1.3; }
	.graph-tooltip span { font-size: .58rem; color: color-mix(in oklch, currentColor 42%, transparent); }
	:global(.math-label math) { font-family: "KaTeX_Math", "STIX Two Math", "Cambria Math", serif; font-size: 1.04em; }
	:global(.math-label math[display="block"]) { display: inline math; }
	.detail-panel { display: flex; flex-direction: column; }
	.panel-tabs { flex: none; height: 3.25rem; padding: .4rem; display: grid; grid-template-columns: 1fr 1fr; gap: .35rem; border-bottom: 1px solid var(--panel-border); }
	.panel-tabs button { border: 0; border-radius: .58rem; background: transparent; color: color-mix(in oklch, currentColor 48%, transparent); font-size: .75rem; font-weight: 650; cursor: pointer; }
	.panel-tabs button.active { background: var(--btn-regular-bg); color: var(--btn-content); }
	.panel-tabs span { margin-left: .25rem; opacity: .55; }
	.detail-scroll { height: calc(100% - 3.25rem); overflow-y: auto; padding: 1.1rem; }
	.node-heading { padding-bottom: 1.05rem; border-bottom: 1px solid var(--panel-border); }
	.type-pill { display: inline-flex; align-items: center; height: 1.5rem; padding: 0 .5rem 0 1.05rem; border-radius: 999px; position: relative; background: color-mix(in oklch, var(--node-color) 12%, transparent); color: var(--node-color); font-size: .64rem; font-weight: 700; }
	.type-pill::before { content: ""; position: absolute; left: .48rem; width: .35rem; height: .35rem; border-radius: 50%; background: var(--node-color); }
	.node-heading h2 { margin: .72rem 0 .55rem; font-size: 1.15rem; line-height: 1.32; color: color-mix(in oklch, currentColor 86%, transparent); overflow-wrap: anywhere; }
	.node-heading code, .source-path { font: 500 .61rem/1.45 "JetBrains Mono Variable", monospace; color: color-mix(in oklch, currentColor 34%, transparent); overflow-wrap: anywhere; }
	.attribute-row { min-height: 2.8rem; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid var(--panel-border); font-size: .72rem; }
	.attribute-row span { color: color-mix(in oklch, currentColor 42%, transparent); }
	.attribute-row strong { color: color-mix(in oklch, currentColor 72%, transparent); }
	.detail-block { padding: 1rem 0; border-bottom: 1px solid var(--panel-border); }
	.detail-block h3 { margin: 0 0 .7rem; font-size: .68rem; letter-spacing: .05em; text-transform: uppercase; color: color-mix(in oklch, currentColor 42%, transparent); }
	.detail-block h3 span { margin-left: .25rem; font-family: "JetBrains Mono Variable", monospace; color: var(--primary); }
	.chip-list { display: flex; flex-wrap: wrap; gap: .35rem; }
	.chip-list span, .chip-list button { min-height: 1.7rem; padding: .25rem .5rem; border: 1px solid var(--panel-border); border-radius: .45rem; background: color-mix(in oklch, var(--page-bg) 52%, transparent); color: color-mix(in oklch, currentColor 64%, transparent); font-size: .65rem; line-height: 1.2; }
	.chip-list button { cursor: pointer; }
	.chip-list button:hover { border-color: color-mix(in oklch, var(--primary) 40%, transparent); color: var(--primary); }
	.chip-list.dependencies button { border-color: oklch(.7 .17 25 / .2); background: oklch(.7 .17 25 / .07); }
	.evidence-text { max-height: 16rem; overflow-y: auto; padding: .72rem; border-radius: .65rem; white-space: pre-wrap; overflow-wrap: anywhere; background: color-mix(in oklch, var(--page-bg) 58%, transparent); font-size: .73rem; line-height: 1.62; color: color-mix(in oklch, currentColor 64%, transparent); }
	.neighbor-list { display: flex; flex-direction: column; gap: .3rem; }
	.neighbor-list button, .neighbor-list .backlink-item { width: 100%; padding: .52rem; display: grid; grid-template-columns: 1.5rem 1fr; gap: .25rem; align-items: center; text-align: left; border: 0; border-radius: .55rem; background: transparent; color: inherit; cursor: pointer; text-decoration: none; }
	.neighbor-list button:hover, .neighbor-list .backlink-item:hover { background: var(--btn-plain-bg-hover); }
	.neighbor-list button > span:last-child, .neighbor-list .backlink-item > span:last-child { min-width: 0; display: flex; flex-direction: column; gap: .18rem; }
	.neighbor-list small { color: var(--primary); font-size: .57rem; }
	.neighbor-list strong { font-size: .68rem; line-height: 1.3; color: color-mix(in oklch, currentColor 68%, transparent); overflow-wrap: anywhere; }
	.relation-arrow { color: color-mix(in oklch, currentColor 28%, transparent); font-family: "JetBrains Mono Variable", monospace; }
	.source-actions { display: flex; flex-wrap: wrap; gap: .45rem; padding-top: 1rem; }
	.source-actions button, .source-actions a { min-height: 2.15rem; padding: 0 .72rem; display: inline-flex; align-items: center; border-radius: .6rem; border: 1px solid var(--panel-border); background: var(--btn-regular-bg); color: var(--btn-content); font-size: .67rem; font-weight: 650; cursor: pointer; text-decoration: none; }
	.source-actions a { background: transparent; color: color-mix(in oklch, currentColor 58%, transparent); }
	.source-path { margin: .65rem 0 0; }
	.diagnostic-scroll { display: flex; flex-direction: column; gap: .45rem; }
	.diagnostic-summary { margin-bottom: .5rem; padding: 1rem; border-radius: .75rem; background: oklch(.72 .14 70 / .09); border: 1px solid oklch(.72 .14 70 / .2); }
	.diagnostic-summary strong { display: block; font: 650 1.7rem/1 "JetBrains Mono Variable", monospace; color: oklch(.69 .15 60); }
	.diagnostic-summary span { display: block; margin-top: .35rem; font-size: .74rem; font-weight: 650; }
	.diagnostic-summary p { margin: .55rem 0 0; font-size: .68rem; line-height: 1.5; color: color-mix(in oklch, currentColor 46%, transparent); }
	.diagnostic-item { width: 100%; padding: .72rem; display: flex; flex-direction: column; gap: .28rem; text-align: left; border: 1px solid var(--panel-border); border-radius: .65rem; background: transparent; color: inherit; }
	.diagnostic-item:not(:disabled) { cursor: pointer; }
	.diagnostic-item:not(:disabled):hover { background: var(--btn-plain-bg-hover); }
	.diagnostic-item span { font: 600 .57rem/1.2 "JetBrains Mono Variable", monospace; color: oklch(.69 .15 60); }
	.diagnostic-item strong { font-size: .68rem; line-height: 1.4; color: color-mix(in oklch, currentColor 66%, transparent); }
	.diagnostic-item small { font-size: .58rem; color: color-mix(in oklch, currentColor 34%, transparent); }
	.graph-meta { height: 2.25rem; padding: 0 .25rem; display: flex; align-items: center; justify-content: space-between; color: color-mix(in oklch, currentColor 34%, transparent); font-size: .64rem; }
	.graph-meta span { display: flex; align-items: center; gap: .42rem; }
	.graph-meta i { width: .4rem; height: .4rem; border-radius: 50%; background: oklch(.72 .16 150); box-shadow: 0 0 0 3px oklch(.72 .16 150 / .12); }
	.graph-meta code { font-family: "JetBrains Mono Variable", monospace; }
	.state-card { min-height: 28rem; border-radius: 1rem; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: .75rem; color: color-mix(in oklch, currentColor 48%, transparent); }
	.state-card p { margin: 0; font-size: .82rem; }
	.loader { width: 1.5rem; height: 1.5rem; border: 2px solid color-mix(in oklch, var(--primary) 18%, transparent); border-top-color: var(--primary); border-radius: 50%; animation: spin .8s linear infinite; }
	.error-state strong { color: oklch(.65 .18 25); }
	.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0,0,0,0); white-space: nowrap; border: 0; }
	@keyframes spin { to { transform: rotate(360deg); } }
	@keyframes pulse { from { opacity: .42; } to { opacity: .78; } }
	@media (max-width: 1180px) {
		.workspace { grid-template-columns: minmax(15rem, .72fr) minmax(24rem, 1.35fr); height: auto; max-height: none; }
		.results-panel, .graph-panel { height: 42rem; }
		.detail-panel { grid-column: 1 / -1; min-height: 32rem; max-height: 44rem; }
		.detail-scroll { max-height: 40rem; }
	}
	@media (max-width: 840px) {
		.hero-card { padding: 1.5rem; flex-direction: column; align-items: stretch; }
		.stat-grid { min-width: 0; }
		.toolbar-card { align-items: stretch; flex-direction: column; }
		.search-field { flex-basis: 3rem; width: 100%; }
		.type-filters { width: 100%; }
		.workspace { grid-template-columns: 1fr; }
		.results-panel, .graph-panel { height: 34rem; }
		.detail-panel { grid-column: auto; }
	}
	@media (max-width: 520px) {
		.hero-card { border-radius: 0; border-left: 0; border-right: 0; }
		.hero-card, .toolbar-card { padding-left: 1rem; padding-right: 1rem; }
		.stat-grid { grid-template-columns: repeat(2, 1fr); }
		.workspace { gap: .75rem; }
		.panel, .toolbar-card { border-radius: .85rem; }
	}
</style>
