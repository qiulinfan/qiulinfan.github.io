#import "../qlnotes.typ": *
#import "../math-aliases.typ": *
#import "probability-support-region.typ": support-region

#show: qlnotes.with(
  title: "Probability export round-trip / 概率论导出试验",
  subtitle: "One Typst source, editable LaTeX and Markdown",
  course: "QLNotes Export Contract",
  author: "Qiulin Fan",
  date: "2026",
  description: "An end-to-end export fixture with semantic math and a CeTZ diagram.",
  keywords: ("probability", "Typst", "LaTeX", "Markdown"),
  bibliography: "../references.bib",
)

= Joint distributions / 联合分布

#definition(
  title: [Support / 支撑集],
  id: "def-joint-support",
  concepts: ("joint-distribution", "support"),
  depends: ("random-variable", "density"),
  aliases: ("联合分布支撑集",),
)[
  The support of a joint density $f_(X,Y)$ is the set on which
  $f_(X,Y)(x, y) > 0$. In the region below,
  $bP ((X,Y) in A)$ is obtained by integrating over $A$.
]

#lemma(
  title: [Non-negativity],
  id: "lem-probability-nonnegative",
  concepts: ("probability-measure",),
  depends: ("measure",),
)[
  For every measurable event $A$, $bP (A) >= 0$.
]

#proof[
  This follows directly from the codomain of a probability measure.
]

#corollary(
  id: "cor-probability-bound",
  concepts: ("probability-bound",),
  depends: ("probability-measure",),
)[
  Every event satisfies $0 <= bP (A) <= 1$.
]

#remark[
  The semantic IDs above are preserved in both exported formats.
]

#example(title: [A direct calculation])[
  If $bP (A) = 1/2$, compute $bP (A^c)$.

  #solution[
    Since $A$ and $A^c$ partition the sample space,
    $bP (A^c) = 1 - bP (A) = 1/2$.
  ]
]

#diagram(
  support-region,
  id: "fig-joint-support",
  caption: [A joint-distribution support set.],
  alt: "The support region bounded by y equals 2x, y equals three halves minus x, and the x-axis.",
)

The geometric interpretation is consistent with the standard measure-theoretic
development in @folland1999.

#bibliography("../references.bib", title: [References], style: "ieee")
