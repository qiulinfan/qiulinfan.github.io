// A small Typst template inspired by ElegantBook's math-note styling.

#let elegant-blue = (
  structure: rgb("#3c71b7"),
  main: rgb("#00a652"),
  second: rgb("#ff8618"),
  third: rgb("#00aef7"),
  wine: rgb("#800000"),
  def-bg: rgb("#f2fbf5"),
  thm-bg: rgb("#fff7ee"),
  prop-bg: rgb("#eefbff"),
  intro-bg: rgb("#eef5ff"),
)

#let definition-counter = counter("elegant-definition")
#let theorem-counter = counter("elegant-theorem")
#let proposition-counter = counter("elegant-proposition")
#let lemma-counter = counter("elegant-lemma")
#let corollary-counter = counter("elegant-corollary")
#let example-counter = counter("elegant-example")
#let exercise-counter = counter("elegant-exercise")
#let problem-counter = counter("elegant-problem")

#let reset-note-counters() = {
  definition-counter.update(0)
  theorem-counter.update(0)
  proposition-counter.update(0)
  lemma-counter.update(0)
  corollary-counter.update(0)
  example-counter.update(0)
  exercise-counter.update(0)
  problem-counter.update(0)
}

#let heading-number(it) = {
  if it.numbering == none {
    none
  } else {
    context counter(heading).display(it.numbering)
  }
}

#let local-number(c) = context {
  let levels = counter(heading).get()
  let chapter = if levels.len() > 0 { levels.at(0) } else { 0 }
  [#chapter.#c.display("1")]
}

#let titled-label(label, number, title) = {
  if title == none {
    [#label #number]
  } else {
    [#label #number (#title)]
  }
}

#let elegant-box(label, c, accent, background, mark, title: none, body) = {
  c.step()
  let number = local-number(c)
  let full-label = titled-label(label, number, title)

  block(above: 0.85em, below: 0.9em, breakable: true)[
    #stack(
      dir: ttb,
      spacing: 0pt,
      box(
        fill: accent,
        inset: (x: 7pt, y: 2.5pt),
        radius: 0pt,
      )[
        #text(fill: white, weight: "bold", size: 10pt)[#full-label]
      ],
      block(
        width: 100%,
        breakable: true,
        fill: background,
        stroke: (paint: accent, thickness: 0.55pt),
        radius: 2pt,
        inset: (x: 9pt, y: 8pt),
      )[
        #body
        #align(right)[#text(fill: accent, size: 12pt)[#mark]]
      ],
    )
  ]
}

#let inline-env(label, accent, title: none, italic: false, body) = {
  let head = if title == none { [#label] } else { [#label (#title)] }
  block(above: 0.6em, below: 0.6em, breakable: true)[
    #text(fill: accent, weight: "bold")[#head#h(0.45em)]
    #if italic { emph(body) } else { body }
  ]
}

#let numbered-inline(label, c, accent, title: none, body) = {
  c.step()
  let number = local-number(c)
  let head = titled-label(label, number, title)

  block(above: 0.6em, below: 0.6em, breakable: true)[
    #text(fill: accent, weight: "bold")[#head#h(0.45em)]
    #body
  ]
}

#let definition(title: none, body) = elegant-box(
  [Def],
  definition-counter,
  elegant-blue.main,
  elegant-blue.def-bg,
  [♣],
  title: title,
  body,
)

#let theorem(title: none, body) = elegant-box(
  [Theorem],
  theorem-counter,
  elegant-blue.second,
  elegant-blue.thm-bg,
  [♥],
  title: title,
  body,
)

#let lemma(title: none, body) = elegant-box(
  [Lemma],
  lemma-counter,
  elegant-blue.second,
  elegant-blue.thm-bg,
  [♥],
  title: title,
  body,
)

#let corollary(title: none, body) = elegant-box(
  [Corollary],
  corollary-counter,
  elegant-blue.second,
  elegant-blue.thm-bg,
  [♥],
  title: title,
  body,
)

#let proposition(title: none, body) = elegant-box(
  [Proposition],
  proposition-counter,
  elegant-blue.third,
  elegant-blue.prop-bg,
  [♠],
  title: title,
  body,
)

#let example(title: none, body) = numbered-inline(
  [Example],
  example-counter,
  elegant-blue.main,
  title: title,
  body,
)

#let exercise(title: none, body) = numbered-inline(
  [✎ Exercise],
  exercise-counter,
  elegant-blue.main,
  title: title,
  body,
)

#let problem(title: none, body) = numbered-inline(
  [Problem],
  problem-counter,
  elegant-blue.main,
  title: title,
  body,
)

#let proof(body) = inline-env([Proof.], elegant-blue.second, body)
#let solution(body) = inline-env([Sol.], elegant-blue.main, body)
#let remark(title: none, body) = inline-env([Remark], elegant-blue.second, title: title, body)
#let note(body) = inline-env([Note], elegant-blue.second, italic: true, body)

#let introduction(title: [Introduction], body) = {
  block(above: 0.9em, below: 1em, breakable: true)[
    #box(
      fill: elegant-blue.structure,
      inset: (x: 8pt, y: 3pt),
    )[
      #text(fill: white, weight: "bold")[#title]
    ]
    #block(
      width: 100%,
      breakable: true,
      fill: elegant-blue.intro-bg,
      stroke: (paint: elegant-blue.structure, thickness: 0.55pt),
      inset: (x: 10pt, y: 8pt),
    )[
      #body
    ]
  ]
}

#let elegant-title(title, subtitle: none, author: none, date: none) = {
  block(above: 1.5em, below: 2em)[
    #align(center)[
      #text(fill: elegant-blue.structure, weight: "bold", size: 22pt)[#title]
      #if subtitle != none [
        #v(0.45em)
        #text(fill: gray.darken(35%), weight: "bold", size: 13pt)[#subtitle]
      ]
      #if author != none or date != none [
        #v(0.6em)
        #text(fill: gray.darken(25%), size: 10pt)[
          #if author != none [Author: #author]
          #if author != none and date != none [#h(1.2em)]
          #if date != none [Date: #date]
        ]
      ]
    ]
    #v(0.9em)
    #line(length: 100%, stroke: (paint: elegant-blue.second, thickness: 1.1pt))
  ]
}

#let elegantbook(
  title: "Typst Notes",
  subtitle: none,
  author: none,
  date: none,
  body,
) = {
  set document(title: title, author: if author == none { () } else { (author,) })
  set page(
    paper: "a4",
    margin: (left: 20mm, right: 20mm, top: 25.4mm, bottom: 25.4mm),
    header: align(right)[
      #text(fill: elegant-blue.structure, size: 9pt, style: "italic")[#title]
    ],
    footer: align(center)[
      #text(fill: elegant-blue.structure, size: 9pt)[#context counter(page).display("1")]
    ],
  )
  set text(
    font: ("Times New Roman", "SimSun", "Noto Serif"),
    size: 11pt,
  )
  set par(justify: true, leading: 0.65em, first-line-indent: 0em)
  set heading(numbering: "1.1")
  set enum(numbering: "1.")
  show link: set text(fill: elegant-blue.wine)

  show heading.where(level: 1): it => {
    reset-note-counters()
    let number = heading-number(it)
    block(above: 1.4em, below: 1.05em, breakable: false)[
      #align(center)[
        #text(fill: elegant-blue.structure, weight: "bold", size: 17pt)[
          #if number != none [Module #number #h(0.35em)]
          #it.body
        ]
      ]
    ]
  }

  show heading.where(level: 2): it => {
    let number = heading-number(it)
    block(above: 1.1em, below: 0.65em, breakable: false)[
      #text(fill: elegant-blue.structure, weight: "bold", size: 14pt)[
        #if number != none [#number #h(0.45em)]
        #it.body
      ]
    ]
  }

  show heading.where(level: 3): it => {
    let number = heading-number(it)
    block(above: 0.8em, below: 0.45em, breakable: false)[
      #text(fill: elegant-blue.structure, weight: "bold", size: 12.5pt)[
        #if number != none [#number #h(0.45em)]
        #it.body
      ]
    ]
  }

  elegant-title(title, subtitle: subtitle, author: author, date: date)
  body
}
