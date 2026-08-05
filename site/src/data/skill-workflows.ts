import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { parse } from "yaml";

export type WorkflowStepKind = "input" | "skill" | "output";
export type WorkflowDecisionTone = "reuse" | "author" | "review";

export interface WorkflowStep {
	kind: WorkflowStepKind;
	label: string;
	title: string;
	description: string;
	skillId?: string;
}

export interface WorkflowDecision {
	status: string;
	title: string;
	description: string;
	tone: WorkflowDecisionTone;
}

export interface KnowledgeWorkflow {
	id: string;
	index: string;
	kicker: string;
	title: string;
	summary: string;
	steps: WorkflowStep[];
	decisions: WorkflowDecision[];
	result: {
		label: string;
		title: string;
		description: string;
	};
	optionalImport?: {
		label: string;
		skillId: string;
		description: string;
	};
	mutatesPersonalGraphByDefault: boolean;
}

// Keep this as an explicit build-time data read instead of bundling editable YAML
// into the client or publishing it as a static asset.
const workflowFilename = ["skill-workflows", "yaml"].join(".");
const workflowSource = resolve(process.cwd(), "src", "data", workflowFilename);

function object(value: unknown, path: string): Record<string, unknown> {
	if (!value || typeof value !== "object" || Array.isArray(value)) {
		throw new Error(`${path} must be a YAML mapping.`);
	}
	return value as Record<string, unknown>;
}

function array(value: unknown, path: string): unknown[] {
	if (!Array.isArray(value)) throw new Error(`${path} must be a YAML list.`);
	return value;
}

function text(value: unknown, path: string): string {
	if (typeof value !== "string" || !value.trim()) {
		throw new Error(`${path} must be a non-empty string.`);
	}
	return value.trim();
}

function flag(value: unknown, path: string): boolean {
	if (typeof value !== "boolean")
		throw new Error(`${path} must be true or false.`);
	return value;
}

function choice<T extends string>(
	value: unknown,
	path: string,
	choices: readonly T[],
): T {
	const selected = text(value, path) as T;
	if (!choices.includes(selected)) {
		throw new Error(`${path} must be one of: ${choices.join(", ")}.`);
	}
	return selected;
}

function loadKnowledgeWorkflows(): KnowledgeWorkflow[] {
	const root = object(
		parse(readFileSync(workflowSource, "utf8")),
		"skill-workflows.yaml",
	);
	const workflows = array(root.workflows, "workflows").map(
		(value, workflowIndex) => {
			const path = `workflows[${workflowIndex}]`;
			const workflow = object(value, path);
			const steps = array(workflow.steps, `${path}.steps`).map(
				(stepValue, stepIndex) => {
					const stepPath = `${path}.steps[${stepIndex}]`;
					const step = object(stepValue, stepPath);
					const skillId = step.skillId;
					return {
						kind: choice(step.kind, `${stepPath}.kind`, [
							"input",
							"skill",
							"output",
						]),
						label: text(step.label, `${stepPath}.label`),
						title: text(step.title, `${stepPath}.title`),
						description: text(step.description, `${stepPath}.description`),
						...(skillId === undefined
							? {}
							: { skillId: text(skillId, `${stepPath}.skillId`) }),
					};
				},
			);
			const decisions = array(workflow.decisions, `${path}.decisions`).map(
				(decisionValue, decisionIndex) => {
					const decisionPath = `${path}.decisions[${decisionIndex}]`;
					const decision = object(decisionValue, decisionPath);
					return {
						status: text(decision.status, `${decisionPath}.status`),
						title: text(decision.title, `${decisionPath}.title`),
						description: text(
							decision.description,
							`${decisionPath}.description`,
						),
						tone: choice(decision.tone, `${decisionPath}.tone`, [
							"reuse",
							"author",
							"review",
						]),
					};
				},
			);
			const result = object(workflow.result, `${path}.result`);
			const optionalImport =
				workflow.optionalImport === undefined
					? undefined
					: object(workflow.optionalImport, `${path}.optionalImport`);

			return {
				id: text(workflow.id, `${path}.id`),
				index: text(workflow.index, `${path}.index`),
				kicker: text(workflow.kicker, `${path}.kicker`),
				title: text(workflow.title, `${path}.title`),
				summary: text(workflow.summary, `${path}.summary`),
				steps,
				decisions,
				result: {
					label: text(result.label, `${path}.result.label`),
					title: text(result.title, `${path}.result.title`),
					description: text(result.description, `${path}.result.description`),
				},
				...(optionalImport
					? {
							optionalImport: {
								label: text(
									optionalImport.label,
									`${path}.optionalImport.label`,
								),
								skillId: text(
									optionalImport.skillId,
									`${path}.optionalImport.skillId`,
								),
								description: text(
									optionalImport.description,
									`${path}.optionalImport.description`,
								),
							},
						}
					: {}),
				mutatesPersonalGraphByDefault: flag(
					workflow.mutatesPersonalGraphByDefault,
					`${path}.mutatesPersonalGraphByDefault`,
				),
			};
		},
	);

	const ids = workflows.map((workflow) => workflow.id);
	if (new Set(ids).size !== ids.length) {
		throw new Error(
			"Every workflow in skill-workflows.yaml must have a unique id.",
		);
	}
	return workflows;
}

export const knowledgeWorkflows = loadKnowledgeWorkflows();
export const knowledgeWorkflowSource = workflowSource;
