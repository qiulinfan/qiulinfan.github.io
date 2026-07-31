#import "@preview/cetz:0.5.2"

#let drawing() = cetz.canvas({
    import cetz.draw: *

    line((0, 0), (3, 0), mark: (end: ">"))
    line((0, 0), (0, 2), mark: (end: ">"))
    line(
      (0.2, 0.1),
      (0.8, 0.7),
      (1.4, 1.0),
      (2.0, 1.55),
      (2.7, 1.75),
      stroke: rgb("#2574d8") + 1.2pt,
    )
    content((3.15, 0), [$x$], anchor: "west")
    content((0, 2.15), [$f_X(x)$], anchor: "south")
})

#context {
  if target() == "html" {
    html.frame(drawing())
  } else {
    drawing()
  }
}
