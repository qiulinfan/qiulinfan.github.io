#import "@preview/cetz:0.5.2"

#let blue = rgb("#2574d8")
#let red = rgb("#d84b4b")
#let gray = rgb("#667085")

#show figure: set align(left)

// Port of the support-set TikZ figure in
// notes/math/prob/chapters/03-joint&conditional-distribution.tex.
#let support-region() = cetz.canvas(length: 2.2cm, {
  import cetz.draw: *

  // Axes.
  line((-0.2, 0), (1.25, 0), mark: (end: ">"))
  line((0, -0.2), (0, 2.2), mark: (end: ">"))
  content((1.55, -0.03), text(size: 8pt)[$x$], anchor: "west")
  content((0, 2.25), text(size: 8pt)[$y$], anchor: "south")

  // Reference boundaries.
  line(
    (0, 0),
    (1, 2),
    stroke: (paint: gray, dash: "dashed"),
  )
  line(
    (0, 1.5),
    (1.5, 0),
    stroke: (paint: gray, dash: "dashed"),
  )
  content((1, 2), text(size: 8pt)[$y = 2x$], anchor: "south-west")
  content(
    (0.94, 0.72),
    text(size: 7pt)[$y = 3/2 - x$],
    anchor: "south-west",
  )

  // The two pieces of the support region.
  line(
    (0, 0),
    (0.5, 0),
    (0.5, 1),
    close: true,
    fill: blue.transparentize(72%),
    stroke: none,
  )
  line(
    (0.5, 0),
    (1, 0),
    (1, 0.5),
    (0.5, 1),
    close: true,
    fill: blue.transparentize(72%),
    stroke: none,
  )
  line(
    (0, 0),
    (0.5, 1),
    (1, 0.5),
    (1, 0),
    close: true,
    stroke: blue + 1.2pt,
  )

  // Vertices and labels.
  circle((0.5, 1), radius: 1.8pt, fill: red, stroke: none)
  circle((1, 0.5), radius: 1.8pt, fill: red, stroke: none)
  content((0.5, 1), text(size: 8pt)[$(1/2, 1)$], anchor: "south-east")
  content((1, 0.5), text(size: 8pt)[$(1, 1/2)$], anchor: "north-west")
  content(
    (0.43, 0.34),
    text(size: 7pt, fill: blue.darken(18%))[support],
    anchor: "center",
  )
})

#context {
  if target() == "html" {
    html.elem(
      "figure",
      attrs: (
        role: "img",
        aria-label: "The support region bounded by y equals 2x, y equals three halves minus x, and the x-axis.",
      ),
    )[
      #html.frame(support-region())
      #html.elem("figcaption")[A joint-distribution support set.]
    ]
  } else {
    figure(
      block(width: 100%)[
        #align(left)[#support-region()]
      ],
      caption: [A joint-distribution support set.],
    )
  }
}
