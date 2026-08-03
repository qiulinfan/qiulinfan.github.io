---
authority: typst
course: QLNotes Export Contract
description: A compact semantic graph fixture.
keywords:
- probability
qlnotes-schema: qlnotes-v1
semantic-node-count: 3
source: fixture.typ
title: Probability graph fixture
---

# Joint distributions

::: {#def-joint-support .definition depends="random-variable, density" aliases="联合分布支撑集" concepts="joint-distribution, support"}
**Definition: Support**

The support of a joint density is the set on which it is positive.
:::

::: {#lem-probability-nonnegative .lemma depends="measure" concepts="probability-measure"}
**Lemma: Non-negativity**

Every measurable event has nonnegative probability.
:::

::: {#cor-probability-bound .corollary depends="probability-measure" concepts="probability-bound"}
**Corollary**

Every event has probability between zero and one.
:::

![A joint-distribution support set.](figure.svg){#fig-joint-support}

See [@folland1999].
