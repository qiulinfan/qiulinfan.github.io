#import "qlnotes.typ": *

#show: qlnotes.with(
  title: "Measure Theory / 测度论",
  subtitle: "A bilingual prototype for durable mathematical notes",
  course: "QLNotes Template Preview",
  author: "Qiulin Fan",
  date: "2026",
  cover: "assets/M.jpg",
  description: "A Typst-first mathematics note rendered as both PDF and HTML.",
  keywords: ("mathematics", "measure theory", "Typst", "QLNotes"),
)

= Foundations / 基础结构 <foundations>

本原型保持现有 LaTeX 笔记的辨识度，但把样式从正文中移到模板。
章节、定理、定义、证明、公式和引用都使用语义组件；同一份源文件可以
生成分页 PDF 与响应式网页。

== Sigma-algebras

#definition(
  title: [Sigma-algebra / σ-代数],
  id: "def-sigma-algebra",
  concepts: ("sigma-algebra", "measurable-space"),
  depends: ("set", "complement", "countable-union"),
  aliases: ("σ-algebra", "西格玛代数"),
)[
  Let $X$ be a set. A family $cal(F) subset.eq 2^X$ is a
  *sigma-algebra* if:

  + $X in cal(F)$;
  + $E in cal(F)$ implies $E^c in cal(F)$;
  + for every sequence $(E_n)_(n >= 1)$ in $cal(F)$,
    $union_(n=1)^oo E_n in cal(F)$.

  The pair $(X, cal(F))$ is called a measurable space.
]

这里的组件不仅控制视觉样式，也保留了稳定 ID。以后 Markdown 知识图谱
可以直接把 `sigma-algebra` 识别为概念节点，并记录其前置依赖。

#note(title: [Authoring principle / 写作原则])[
  正文只表达语义，不直接指定颜色、边框或网页标签。PDF 和 HTML 的差异
  完全由模板中的 `target()` 分支处理。
]

== Measures and continuity

#definition(
  title: [Measure / 测度],
  id: "def-measure",
  concepts: ("measure",),
  depends: ("sigma-algebra", "countable-additivity"),
  aliases: ("测度",),
)[
  A measure on the measurable space from @def-sigma-algebra is a map
  $mu: cal(F) arrow.r.double [0, oo]$ such that $mu(emptyset) = 0$ and

  $ mu(union_(n=1)^oo E_n) = sum_(n=1)^oo mu(E_n) $

  whenever the sets $E_1, E_2, dots$ are pairwise disjoint.
]

#theorem(
  title: [Continuity from below / 下连续性],
  id: "thm-continuity-below",
  concepts: ("continuity-from-below",),
  depends: ("measure", "monotone-sequence-of-sets"),
  aliases: ("下连续性",),
)[
  If $E_1 subset.eq E_2 subset.eq dots$ and
  $E = union_(n=1)^oo E_n$, then

  $ mu(E) = lim_(n arrow oo) mu(E_n). $
]

#proof[
  Set $A_1 = E_1$ and $A_n = E_n without E_(n-1)$ for $n >= 2$.
  The sets $A_n$ are pairwise disjoint and
  $E_n = union_(k=1)^n A_k$. Countable additivity gives

  $ mu(E) = sum_(k=1)^oo mu(A_k)
    = lim_(n arrow oo) sum_(k=1)^n mu(A_k)
    = lim_(n arrow oo) mu(E_n). $
]

#example(title: [A concrete exhaustion])[
  On $(RR, cal(B)(RR), lambda)$, take $E_n = [-n, n]$.
  Then $E_n arrow.t RR$ and
  $lambda(E_n) = 2n arrow oo = lambda(RR)$.
]

= Sustainable components / 可持续组件

== Shared semantic vocabulary

下表展示当前原型覆盖的第一批可移植结构。它们将在后续转换器中成为
LaTeX、Typst 和 Markdown 的共同契约。

#figure(
  table(
    columns: (1.1fr, 1.4fr, 1.5fr),
    inset: 7pt,
    align: (left, left, left),
    table.header(
      [*Component*],
      [*Typst authoring*],
      [*Future portable meaning*],
    ),
    [Definition], [`#definition[...]`], [Typed concept node],
    [Theorem], [`#theorem[...]`], [Claim with stable ID],
    [Proof], [`#proof[...]`], [Evidence linked to a claim],
    [Note], [`#note[...]`], [Non-normative annotation],
    [Reference], [`@stable-id`], [Directed graph edge],
  ),
  caption: [The initial QLNotes semantic component set.],
) <tab-components>

== References and bibliography

Stable bibliography keys remain shared with the LaTeX baseline. For example,
the presentation here follows the standard development in @folland1999.
Typst reads the existing BibLaTeX format directly, so the bibliography database
does not need to fork.

#bibliography("references.bib", title: [References], style: "ieee")
