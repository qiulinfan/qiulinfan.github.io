---
author:
- Qiulin Fan
authority: typst
bibliography:
- reference.bib
course: QLNotes Template Preview
date: 2026
description: A Typst-first mathematics note rendered as both PDF and HTML.
keywords:
- mathematics
- measure theory
- Typst
- QLNotes
lang: zh-CN
qlnotes-schema: qlnotes-v1
semantic-node-count: 3
source: demo.typ
subtitle: A bilingual prototype for durable mathematical notes
title: Measure Theory / 测度论
---

# Foundations / 基础结构 {#foundations}

本原型保持现有 LaTeX 笔记的辨识度，但把样式从正文中移到模板。 章节、定理、定义、证明、公式和引用都使用语义组件；同一份源文件可以 生成分页 PDF 与响应式网页。

## Sigma-algebras

::: {#def-sigma-algebra .definition depends="set, complement, countable-union" aliases="σ-algebra, 西格玛代数" concepts="sigma-algebra, measurable-space"}
**Definition: Sigma-algebra / σ-代数**

Let $X$ be a set. A family $\mathcal{F} \subseteq 2^{X}$ is a **sigma-algebra** if:

1.  $X \in \mathcal{F}$;
2.  $E \in \mathcal{F}$ implies $E^{c} \in \mathcal{F}$;
3.  for every sequence $\left( E_{n} \right)_{n \geq 1}$ in $\mathcal{F}$, $\cup_{n = 1}^{\infty}E_{n} \in \mathcal{F}$.

The pair $\left( {X,\mathcal{F}} \right)$ is called a measurable space.
:::

这里的组件不仅控制视觉样式，也保留了稳定 ID。以后 Markdown 知识图谱 可以直接把 `sigma-algebra` 识别为概念节点，并记录其前置依赖。

::: note
**Note: Authoring principle / 写作原则**

正文只表达语义，不直接指定颜色、边框或网页标签。PDF 和 HTML 的差异 完全由模板中的 `target()` 分支处理。
:::

## Measures and continuity

::: {#def-measure .definition depends="sigma-algebra, countable-additivity" aliases="测度" concepts="measure"}
**Definition: Measure / 测度**

A measure on the measurable space from [Definition 1.1](#def-sigma-algebra) is a map $\mu:\mathcal{F}\Rightarrow\left\lbrack {0,\infty} \right\rbrack$ such that $\mu(\varnothing) = 0$ and

$$\mu\left( {\cup_{n = 1}^{\infty}E_{n}} \right) = \sum\limits_{n = 1}^{\infty}\mu\left( E_{n} \right)$$

whenever the sets $E_{1},E_{2},\ldots$ are pairwise disjoint.
:::

::: {#thm-continuity-below .theorem depends="measure, monotone-sequence-of-sets" aliases="下连续性" concepts="continuity-from-below"}
**Theorem: Continuity from below / 下连续性**

If $E_{1} \subseteq E_{2} \subseteq \ldots$ and $E = \cup_{n = 1}^{\infty}E_{n}$, then

$$\mu(E) = \lim\limits_{n\rightarrow\infty}\mu\left( E_{n} \right).$$
:::

::: proof
**Proof**

Set $A_{1} = E_{1}$ and $A_{n} = E_{n} \smallsetminus E_{n - 1}$ for $n \geq 2$. The sets $A_{n}$ are pairwise disjoint and $E_{n} = \cup_{k = 1}^{n}A_{k}$. Countable additivity gives

$$\mu(E) = \sum\limits_{k = 1}^{\infty}\mu\left( A_{k} \right) = \lim\limits_{n\rightarrow\infty}\sum\limits_{k = 1}^{n}\mu\left( A_{k} \right) = \lim\limits_{n\rightarrow\infty}\mu\left( E_{n} \right).$$
:::

::: example
**Example: A concrete exhaustion**

On $\left( {{\mathbb{R}},\mathcal{B}({\mathbb{R}}),\lambda} \right)$, take $E_{n} = \left\lbrack {- n,n} \right\rbrack$. Then $E_{n} \uparrow {\mathbb{R}}$ and $\lambda\left( E_{n} \right) = 2n\rightarrow\infty = \lambda({\mathbb{R}})$.
:::

# Sustainable components / 可持续组件

## Shared semantic vocabulary

下表展示当前原型覆盖的第一批可移植结构。它们将在后续转换器中成为 LaTeX、Typst 和 Markdown 的共同契约。

  **Component**   **Typst authoring**   **Future portable meaning**
  --------------- --------------------- -----------------------------
  Definition      `#definition[...]`    Typed concept node
  Theorem         `#theorem[...]`       Claim with stable ID
  Proof           `#proof[...]`         Evidence linked to a claim
  Note            `#note[...]`          Non-normative annotation
  Reference       `@stable-id`          Directed graph edge

  : The initial QLNotes semantic component set.

## References and bibliography

Stable bibliography keys remain shared with the LaTeX baseline. For example, the presentation here follows the standard development in [@folland1999]. Typst reads the existing BibLaTeX format directly, so the bibliography database does not need to fork.
