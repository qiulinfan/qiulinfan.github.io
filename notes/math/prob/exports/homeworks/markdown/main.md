---
author:
- Qiulin Fan
authority: typst
bibliography:
- reference.bib
course: Math 525
date: 2026
description: Complete migrated probability homework solutions.
keywords:
- probability
- homework
- worked solutions
lang: zh-CN
qlnotes-schema: qlnotes-v1
semantic-node-count: "0"
source: homeworks.typ
subtitle: Typst-first worked solutions
title: "Math 525: Probability Homeworks"
---

# Homework 1

## Problem 1 {#problem-1-1}

Let $n \in {\mathbb{N}}$.

- Show that $2^{n} = \sum_{k = 0}^{n}\left( \frac{n}{k} \right)$. Given that a set of $n$ elements has $2^{n}$ subsets, what is the combinatorial interpretation of this equality?

- Show that

  $$\sum\limits_{k\ \text{odd},0 \leq k \leq n}\left( \frac{n}{k} \right) = \sum\limits_{k\ \text{even},0 \leq k \leq n}\left( \frac{n}{k} \right)$$

- Show that

  $$\left( \frac{2n}{n} \right) = \sum\limits_{k = 0}^{n}\left( \frac{n}{k} \right)^{2}$$

Hint: You may use $\left( \frac{n}{k} \right)^{2} = \left( \frac{n}{k} \right)\left( \frac{n}{n - k} \right)$.

::: proof
**Proof**

- By the binomial theorem, we have:

  $$(1 + 1)^{n} = \sum\limits_{k = 0}^{n}\left( \frac{n}{k} \right)1^{k}1^{n - k} = \sum\limits_{k = 0}^{n}\left( \frac{n}{k} \right)$$

  The combinatorial interpretation of this equality is that: Let $S_{k}$ be the collection of all subsets that have size $k$. For collection $S_{k}$, its size is $\left( \frac{n}{k} \right)$ since it represents choosing $k$ elements from $n$ elements without regard to order.\
  Therefore the total number of subsets of $S$ is:

  $$\left. |\mathcal{P}(S) \middle| = \sum\limits_{k = 0}^{n} \middle| S_{k} \middle| = \sum\limits_{k = 0}^{n}\left( \frac{n}{k} \right) = 2^{n} \right.$$

- Using the binomial theorem, we have:

  $$0 = (1 - 1)^{n} = \sum\limits_{k = 0}^{n}\left( \frac{n}{k} \right)( - 1)^{k}1^{n - k} = \sum\limits_{k = 0}^{n}\left( \frac{n}{k} \right)( - 1)^{k}$$

  Thus:

  $$\begin{matrix}
   & {\quad\quad\quad\quad\sum\limits_{k = 0}^{n}\left( \frac{n}{k} \right)( - 1)^{k} = 0} \\
   & {\Longrightarrow\sum\limits_{0 \leq k \leq n,\, k\ \text{odd}}\left( \frac{n}{k} \right)( - 1) + \sum\limits_{0 \leq k \leq n,\, k\ \text{even}}\left( \frac{n}{k} \right)(1) = 0} \\
   & {\Longrightarrow\sum\limits_{0 \leq k \leq n,\, k\ \text{odd}}\left( \frac{n}{k} \right) = \sum\limits_{0 \leq k \leq n,\, k\ \text{even}}\left( \frac{n}{k} \right)}
  \end{matrix}$$

- We prove by combinatorial argument.\
  Let $S$ be a setwith $2n$ distinct elements. The number of ways to choose a subset $P$ containing $n$ elements is $\left( \frac{2n}{n} \right)$.\
  In another way: We can first arbitrarily divide the $2n$ distinct elements into two groups: group $A$ and group $B$, each containing $n$ elements:

  $$S = A \sqcup B$$

  And fix the two groups.\
  For any subset $P$ of the $2n$ elements with size $n$, some of them are from group $A$, and the rest of them are from group $B$.\
  Let $k$ be the number of elements of $P$ that are chosen from $A$, then the number of elements chosen from $B$ must be $n - k$.\
  Note the number of ways to choose $k$ elements from $A$ is $\left( \frac{n}{k} \right)$, and the number of ways to choose $n - k$ elements from $B$ is $\left( \frac{n}{n - k} \right)$.\
  Therefore, the total number of ways to get $P$ from $S = A \sqcup B$ with $k$ elements from $A$ is $\left( \frac{n}{k} \right)\left( \frac{n}{n - k} \right) = \left( \frac{n}{k} \right)^{2}$.\
  Thus, summing over all possible values of $k = 0,1,\ldots,n$, the number of ways to choose $n$ elements from $S$ i.e. the number of ways to get $P$ from $S$, is

  $$\sum\limits_{k = 0}^{n}\left( \frac{n}{k} \right)^{2}$$

  Thus, we obtain

  $$\left( \frac{2n}{n} \right) = \sum\limits_{k = 0}^{n}\left( \frac{n}{k} \right)^{2}$$

  as desired.
:::

## Problem 2 {#problem-2-1}

We roll a fair die three times and record the outcomes $a,b,c \in \left\{ {1,2,3,4,5,6} \right\}$. What is the probability that the equation $ax^{2} + bx + c = 0$ does not have solutions in the real numbers?

::: solution
**Solution**

The equation $ax^{2} + bx + c = 0$ does not have solutions in the real numbers iff the the discriminant is negative, i.e. $\Delta = b^{2} - 4ac < 0$.\
Total possible equations is $6^{3} = 216$. For each $b$, the total possible $(a,c)$ pairs are $36$. We can calculate the number of $(a,c)$ pairs that satisfy the condition case by case.

- For $b = 1$: $4ac > 1$ holds for all $(a,c)$.

- For $b = 2$: $4ac > 4\Longrightarrow ac > 1$, which excludes only $(1,1)$.

- For $b = 3$: $4ac > 9\Longrightarrow ac \geq 3$ since they are integers, so excluding $(1,1),(1,2),(2,1)$ ($3$ cases).

- For $b = 4$: $4ac > 16\Longrightarrow ac \geq 5$, excluding: $(1,3),(1,4),(2,2),(3,1),(4,1)$ besides the previous case, thus $8$ cases excluded.

- For $b = 5$: $4ac > 25\Longrightarrow ac \geq 7$, excluding: $(1,5),(1,6),(2,3),(3,2),(5,1),(6,1)$ besides the previous case, thus $14$ cases excluded.

- For $b = 6$: $4ac > 36\Longrightarrow ac \geq 10$, excluding: $(2,4),(3,3),(4,2)$ besides the previous case, thus $17$ cases excluded.

Thus, the total number of triples for which the discriminant is not negative (exlcuded) is

$$1 + 3 + 8 + 14 + 17 = 43$$

Therefore, the desired probability is

$$1 - {\mathbb{P}}(\text{the equation has solutions in the real numbers}) = 1 - \frac{43}{216} = \frac{173}{216}$$
:::

## Problem 3 {#problem-3-1}

An ant starts at the origin $(0,0)$ on the integer lattice. At each step it moves either one unit to the right or one unit upward, each with probability $\frac{1}{2}$. The ant continues moving until it reaches the point $(205,200)$.\
What is the probability that the ant visits the point $(105,100)$ at some time during its journey?\
Hint: Start by counting the number of paths from $(0,0)$ to $(205,200)$.

::: solution
**Solution**

Any path from $(0,0)$ to $(205,200)$ must consist of $205$ steps to the right and $200$ steps upward, for a total of $405$ steps. So a path is uniquely determined by the choice of 205 steps to the right (which is equivalent to the choice of 200 steps upward).\
Thus total number of paths from $(0,0)$ to $(205,200)$ is

$$N = \left( \frac{405}{205} \right)$$

A path passes through the point $(105,100)$ if and only if it first goes from $(0,0)$ to $(105,100)$ and then from $(105,100)$ to $(205,200)$.\
Thus the number of such paths is the product of the number of paths from $(0,0)$ to $(105,100)$ and the number of paths from $(105,100)$ to $(205,200)$, by the fundamental counting principle. For the same reason as deciding the number of total paths from $(0,0)$ to $(205,200)$, the number of paths from $(0,0)$ to $(105,100)$ is

$$N_{1} = \left( \frac{205}{105} \right)$$

And similarly, the number of paths from $(105,100)$ to $(205,200)$ is

$$N_{2} = \left( \frac{200}{100} \right)$$

Note that from a point to another point, all such paths are equally likely to be chosen. Therefore, the desired probability is

$${\mathbb{P}}(\text{path passes through}(105,100)) = \frac{\left( \frac{205}{105} \right)\left( \frac{200}{100} \right)}{\left( \frac{405}{205} \right)}$$
:::

## Problem 4 {#problem-4-1}

From a lottery containing $n$ tickets numbered $1,2,\ldots,n$, a ticket is drawn, its number is recorded, and then it is returned to the lottery. This process is repeated $k \geq 3$ times. Find the probabilities of the following events:

- Ticket 1 is selected at least once.

- Tickets 1, 2, and 3 are each selected at least once.

::: solution
**Solution**

- Let $E$ be the event that ticket $1$ is selected at least once. \$\$\\begin{align\*} \\mathbb{P}(E) &= 1 - \\mathbb{P}(\\text{ticket \$1\$ is never selected in \$k\$ draws}) \\\\ &= 1 - \\left(\\frac{n-1}{n}\\right)\^k \\tag\*{\\text{(by independence of each draw)}} \\end{align\*}\$\$

- Let $F$ be the event that tickets $1,2,3$ are each selected at least once.\
  For $i = 1,2,3$, let

  $$A_{i} := \left\{ {\text{ticket}\ i\ \text{is never selected in the}\ k\ \text{draws}} \right\}$$

  Thus

  $$P(F) = 1 - P(A_{1} \cup A_{2} \cup A_{3})$$

  By the principle of inclusion-exclusion,

  $$P(A_{1} \cup A_{2} \cup A_{3}) = P(A_{1}) + P(A_{2}) + P(A_{3}) - P(A_{1} \cap A_{2}) - P(A_{1} \cap A_{3}) - P(A_{2} \cap A_{3}) + P(A_{1} \cap A_{2} \cap A_{3})$$

  Since similar to part (a), we have:${\mathbb{P}}(A_{i}) = \left( \frac{n - 1}{n} \right)^{k}$, ${\mathbb{P}}(A_{i} \cap A_{j}) = \left( \frac{n - 2}{n} \right)^{k}$, ${\mathbb{P}}(A_{1} \cap A_{2} \cap A_{3}) = \left( \frac{n - 3}{n} \right)^{k}$, we then calculate:

  $$\begin{matrix}
  {{\mathbb{P}}(F)} & {= 1 - \left( \frac{3}{1} \right)\left( \frac{n - 1}{n} \right)^{k} + \left( \frac{3}{2} \right)\left( \frac{n - 2}{n} \right)^{k} - \left( \frac{3}{3} \right)\left( \frac{n - 3}{n} \right)^{k}} \\
   & {= 1 - 3\left( \frac{n - 1}{n} \right)^{k} + 3\left( \frac{n - 2}{n} \right)^{k} - \left( \frac{n - 3}{n} \right)^{k}}
  \end{matrix}$$
:::

## Problem 5 {#problem-5-1}

In a house, drawer $S_{1}$ contains 3 gold coins and 3 silver coins, while drawer $S_{2}$ contains 3 gold coins and 6 silver coins. A thief (in the dark) randomly opens one drawer and then randomly takes two coins from it.

- What is the probability that both coins are gold?

- If it is discovered (upon his arrest) that he has stolen two gold coins, what is the probability that he opened drawer $S_{1}$ ?

::: solution
**Solution**

The thief chooses a drawer uniformly at random, so for each pick, ${\mathbb{P}}(S_{1}\ \text{is chosen}) = {\mathbb{P}}(S_{2}\ \text{is chosen}) = \frac{1}{2}$. Given a drawer, he draws two coins without replacement.

- Using the law of total probability,

  $$\begin{matrix}
  {{\mathbb{P}}(\text{two gold})} & {= {\mathbb{P}}(\text{two gold} \mid S_{1}\ \text{is chosen}){\mathbb{P}}(\text{drawer}\ S_{1}) + {\mathbb{P}}(\text{two gold} \mid S_{2}\ \text{is chosen}){\mathbb{P}}(\text{drawer}\ S_{2})} \\
   & {= \frac{1}{2} \cdot \frac{\left( \frac{3}{2} \right)}{\left( \frac{6}{2} \right)} + \frac{1}{2} \cdot \frac{\left( \frac{3}{2} \right)}{\left( \frac{9}{2} \right)}} \\
   & {= \frac{1}{2}\left( {\frac{3}{15} + \frac{3}{36}} \right)} \\
   & {= \frac{36 + 15}{360}} \\
   & {= \frac{17}{120}}
  \end{matrix}$$

- Let $G$ be the event that the thief stole two gold coins. By Bayes' rule,

  $${\mathbb{P}}(S_{1} \mid G) = \frac{{\mathbb{P}}(G \mid S_{1}){\mathbb{P}}(S_{1})}{{\mathbb{P}}(G)}$$

  Since we have ${\mathbb{P}}(G \mid S_{1}) = \frac{\left( \frac{3}{2} \right)}{\left( \frac{6}{2} \right)} = \frac{1}{5}$, ${\mathbb{P}}(S_{1}) = \frac{1}{2}$, and ${\mathbb{P}}(G) = \frac{17}{120}$ from part (a), we get:

  $${\mathbb{P}}(S_{1} \mid G) = \frac{\frac{1}{5} \cdot \frac{1}{2}}{\frac{17}{120}} = \frac{12}{17}$$
:::

## Problem 6 {#problem-6-1}

Let $A$ and $B$ be events of a probability space with ${\mathbb{P}}(A) > 0$. Show that:

- ${\mathbb{P}}(A \cup B) > 0$ and ${\mathbb{P}}(A \cap B \mid A \cup B) \leq {\mathbb{P}}(A \cap B \mid A)$.

- ${\mathbb{P}}(B \mid B \cup A) \geq {\mathbb{P}}(B \mid A)$.

::: proof
**Proof**

- Since $A \subseteq A \cup B$, we have by monotonicity of probability measure:

  $${\mathbb{P}}(A \cup B) \geq {\mathbb{P}}(A) > 0$$

  Also, since $A \cap B \subseteq A$ and ${\mathbb{P}}(A \cup B) \geq {\mathbb{P}}(A) > 0$, both conditional probabilities below are well-defined. Then

  $$\begin{matrix}
  {{\mathbb{P}}(A \cap B \mid A \cup B)} & {= \frac{{\mathbb{P}}((A \cap B) \cap (A \cup B))}{{\mathbb{P}}(A \cup B)}} \\
   & {= \frac{{\mathbb{P}}(A \cap B)}{{\mathbb{P}}(A \cup B)}} \\
   & {\leq \frac{{\mathbb{P}}(A \cap B)}{{\mathbb{P}}(A)}} \\
   & {= {\mathbb{P}}(A \cap B \mid A)}
  \end{matrix}$$

  This finishes the proof.

- Let $x := {\mathbb{P}}(A \cap B)$, $y := {\mathbb{P}}(A\backslash B)$, $z := {\mathbb{P}}(B\backslash A)$.\
  so $x,y,z \geq 0$ by non-negativity of probability measure.\
  And since

  $$A = (A \cap B) \sqcup (A\backslash B)$$

  Thus, we have:

  $${\mathbb{P}}(A) = {\mathbb{P}}(A \cap B) + {\mathbb{P}}(A\backslash B) = x + y$$

  By similar reason, we have:

  $${\mathbb{P}}(A \cup B) = x + y + z,\quad{\mathbb{P}}(B) = x + z$$

  Thus we have:

  $${\mathbb{P}}(B \mid A \cup B) = \frac{{\mathbb{P}}(B \cap (A \cup B))}{{\mathbb{P}}(A \cup B)} = \frac{{\mathbb{P}}(B)}{{\mathbb{P}}(A \cup B)} = \frac{x + z}{x + y + z}$$

  and

  $${\mathbb{P}}(B \mid A) = \frac{{\mathbb{P}}(A \cap B)}{{\mathbb{P}}(A)} = \frac{x}{x + y}$$

  Note the two probabilities are well-defined since $x + y = {\mathbb{P}}(A) > 0$ (and so $x + y + z > 0$).\
  Now it remains to show that:

  $$\frac{x + z}{x + y + z} \geq \frac{x}{x + y}$$

  i.e.

  $$(x + z)(x + y) \geq x(x + y + z)$$

  which is equivalent to:

  $$x(x + y) + z(x + y) \geq x(x + y) + xz$$

  Eliminating common terms, this is equivalent to:

  $$zy \geq 0$$

  which is true by non-negativity of $z$ and $y$. This finishes the proof that:

  $${\mathbb{P}}(B \mid A \cup B) \geq {\mathbb{P}}(B \mid A)$$
:::

# Homework 2

## Problem 1 {#problem-1-2}

Suppose that the cumulative distribution function (CDF) of a random variable $F:{\mathbb{R}}\rightarrow{\mathbb{R}}$ is strictly increasing and continuous. Let $U$ be a random variable with the uniform distribution on $(0,1)$ and define

$$X := F^{- 1}(U)$$

Show that $X$ has CDF equal to $F$. This exercise shows us how to construct a random variable with given distribution, assuming that we have a uniform random variable.

::: proof
**Proof**

Since $F$ is strictly increasing and continuous, it has an inverse function $F^{- 1}$ on its range, and $F^{- 1}$ is also strictly increasing. Thus for any $x,y \in {\mathbb{R}}$,

$$F^{- 1}(y) \leq x\Leftrightarrow y \leq (F^{- 1})^{- 1}(x) = F(x)$$

Therefore for any $x \in {\mathbb{R}}$, we have

$$\left\{ {x \mid X(x) \leq x} \right\} = \left\{ {x \mid F^{- 1}(U(x)) \leq x} \right\} = \left\{ {x \mid U(x) \leq F(x)} \right\}$$

Therefore

$${\mathbb{P}}(X \leq x) = {\mathbb{P}}(U(x) \leq F(x))$$

Since $U \sim Unif(0,1)$ and for a CDF we have $F(x) \in \lbrack 0,1\rbrack$, we get

$${\mathbb{P}}(U(x) \leq F(x)) = F(x)$$

Thus for all $x$ ${\mathbb{P}}(X \leq x) = F(x)$, i.e., the CDF of $X$ equals $F$.
:::

## Problem 2 {#problem-2-2}

A gas station fills its tank completely once a week. Let the weekly sales volume (in thousands of liters) be a random variable with density

$$f(x) = \left\{ \begin{matrix}
{a(1 - x)^{4},} & {x \in (0,1),} \\
{0,} & \text{otherwise}
\end{matrix} \right.$$

Find the constant $a$. What should be the tank capacity so that the probability of running out of fuel during a given week is $1/100$ ?

::: solution
**Solution**

Since the density integrates to 1,

$$1 = \int_{- \infty}^{\infty}f(x)\, dx = \int_{0}^{1}a(1 - x)^{4}\, dx = a\int_{0}^{1}(1 - x)^{4}\, dx$$

Let $u = 1 - x$, then

$$\int_{0}^{1}(1 - x)^{4}dx = \int_{0}^{1}u^{4}du = \frac{1}{5}$$

So $\frac{1}{5}a = 1$, which gives

$$a = 5$$

Now we look for the tank capacity $c$ such that ${\mathbb{P}}(X > c) = \frac{1}{100}$.\
Let the tank capacity be $c$ (in thousands of liters). Running out of fuel in a week occurs when sales exceed $c$, i.e., the event $\left\{ {X > c} \right\}$. We need

$${\mathbb{P}}(X > c) = \frac{1}{100}$$

Since $a = 5$,

$${\mathbb{P}}(X > c) = \int_{c}^{1}5(1 - x)^{4}\, dx$$

Again let $u = 1 - x$, then we have

$$\int_{c}^{1}5(1 - x)^{4}dx = 5\int_{1 - c}^{0}u^{4}( - du) = 5\int_{0}^{1 - c}u^{4}du = 5 \cdot \frac{(1 - c)^{5}}{5} = (1 - c)^{5}$$

Therefore

$$(1 - c)^{5} = \frac{1}{100}\Longrightarrow 1 - c = 100^{- 1/5} = 10^{- 2/5}\Longrightarrow c = 1 - 10^{- 2/5}$$

So the tank capacity should be $1 - 10^{- 2/5}$ thousand liters.
:::

## Problem 3 {#problem-3-2}

Let the random variable $X$ have density

$$f_{X}(x) = \left\{ \begin{matrix}
{\frac{1}{2x^{2}},} & \left. |x \middle| \geq 1, \right. \\
{0,} & \left. |x \middle| < 1. \right.
\end{matrix} \right.$$

Find the probability density function of $Y := X^{2}$ and compute the probability ${\mathbb{P}}(2Y + 3 \leq 10)$.

::: solution
**Solution**

Since $f_{X}(x) = 0$ for $\left. |x \middle| < 1 \right.$, we have $\left. {\mathbb{P}}( \middle| X \middle| \geq 1) = 1 \right.$. Hence $Y = X^{2} \geq 1$ almost surely, so $F_{Y}(y) = 0$ for $y < 1$ and therefore $f_{Y}(y) = 0$ for $y < 1$ (a.e.).

For $y \geq 1$,

$$F_{Y}(y) = {\mathbb{P}}(X^{2} \leq y) = {\mathbb{P}}( - \sqrt{y} \leq X \leq \sqrt{y}) = \int_{- \sqrt{y}}^{- 1}\frac{1}{2x^{2}}\, dx + \int_{1}^{\sqrt{y}}\frac{1}{2x^{2}}\, dx$$

Compute each integral:

[∫1𝑦12𝑥2𝑑𝑥=12∫1𝑦𝑥−2𝑑𝑥=12−𝑥−11𝑦=12(1−1𝑦)]{.math display="block"}

and similarly $\int_{- \sqrt{y}}^{- 1}\frac{1}{2x^{2}}\, dx = \frac{1}{2}\left( {1 - \frac{1}{\sqrt{y}}} \right)$ since the function is even. Therefore, for $y \geq 1$,

$$F_{Y}(y) = 1 - \frac{1}{\sqrt{y}}$$

Combining both cases we have

$$F_{Y}(y) = \left\{ \begin{matrix}
{0,} & {y < 1,} \\
{1 - \frac{1}{\sqrt{y}}} & {y \geq 1}
\end{matrix} \right.$$

Notice that on $y \geq 1$, $F_{Y}(y)$ is differentiable (except on $y = 1$):

$$F_{Y}'(y) = \frac{d}{dy}\left( {1 - y^{- 1/2}} \right) = \frac{1}{2}\, y^{- 3/2}$$

So consider the function

$$g(y) = \left\{ \begin{matrix}
{\frac{1}{2y^{3/2}},} & {y \geq 1,} \\
{0,} & {y < 1.}
\end{matrix} \right.$$

Then for $x < 1$,

$$\int_{- \infty}^{x}g(y)\, dy = 0 = F_{Y}(x)$$

and for $x \geq 1$

$$\int_{- \infty}^{x}g(y)\, dy = \int_{1}^{x}\frac{1}{2y^{3/2}}\, dy = \left\lbrack {- y^{- 1/2}} \right\rbrack_{1}^{x} = 1 - \frac{1}{\sqrt{x}} = F_{Y}(x)$$

This shows that **$Y$ is absolutely continuous and $g$ is a probability density of $Y$**. Hence

$$f_{Y}(y) = \left\{ \begin{matrix}
{\frac{1}{2y^{3/2}},} & {y \geq 1,} \\
{0,} & {y < 1}
\end{matrix} \right.$$

Now we compute ${\mathbb{P}}(2Y + 3 \leq 10)$.

We have $2Y + 3 \leq 10\Leftrightarrow Y \leq \frac{7}{2}$. Thus

$${\mathbb{P}}(2Y + 3 \leq 10) = {\mathbb{P}}\left( {Y \leq \frac{7}{2}} \right) = F_{Y}\mspace{-18mu}\left( \frac{7}{2} \right) = 1 - \frac{1}{\sqrt{7/2}} = 1 - \sqrt{\frac{2}{7}}$$

Thus,

$${\mathbb{P}}(2Y + 3 \leq 10) = 1 - \sqrt{\frac{2}{7}}$$
:::

## Problem 4 {#problem-4-2}

Let the random variable $X$ have density $f$, which is symmetric about $\mu \in {\mathbb{R}}$, that is, $f(\mu + x) = f(\mu - x)$, for all $x \in {\mathbb{R}}$. Show that ${\mathbb{P}}(X \leq \mu) = {\mathbb{P}}(X \geq \mu)$. If in addition $\left. {\mathbb{E}} \middle| X \middle| < \infty \right.$, show that ${\mathbb{E}}(X) = \mu$. Can you use this observation if $X \sim N(0,1)$ ?

::: proof
**Proof**

Since $X$ has density $f$,

$${\mathbb{P}}(X \leq \mu) = \int_{- \infty}^{\mu}f(t)\, dt$$

Let $t = \mu - x$ so that $dt = - dx$. Then

$$\int_{- \infty}^{\mu}f(t)\, dt = \int_{\infty}^{0}f(\mu - x)( - dx) = \int_{0}^{\infty}f(\mu - x)\, dx$$

Similarly,

$${\mathbb{P}}(X \geq \mu) = \int_{\mu}^{\infty}f(t)\, dt = \int_{0}^{\infty}f(\mu + x)\, dx$$

By symmetry $f(\mu - x) = f(\mu + x)$ for all $x$, hence the two integrals are equal, i.e. proved

$${\mathbb{P}}(X \leq \mu) = {\mathbb{P}}(X \geq \mu)$$

If $\left. {\mathbb{E}} \middle| X \middle| < \infty \right.$, then ${\mathbb{E}}\lbrack X\rbrack = \mu$ for some $\mu \in {\mathbb{R}}$, We want to show that this $\mu$ is the same as the one in the symmetry condition. Consider ${\mathbb{E}}\lbrack X - \mu\rbrack$. Since $\left. {\mathbb{E}} \middle| X \middle| < \infty \right.$, we also have $\left. {\mathbb{E}} \middle| X - \mu \middle| < \infty \right.$, so the following integral is well-defined:

$${\mathbb{E}}\lbrack X - \mu\rbrack = \int_{- \infty}^{\infty}(t - \mu)f(t)\, dt$$

Let $t = \mu + x$; then

$${\mathbb{E}}\lbrack X - \mu\rbrack = \int_{- \infty}^{\infty}x\, f(\mu + x)\, dx$$

Define $g(x) := f(\mu + x)$. The symmetry condition $f(\mu + x) = f(\mu - x)$ implies that $g$ is an even function, thus $xg(x)$ is an odd function. Since $\left. \int \middle| x \middle| g(x)\, dx < \infty \right.$, we may integrate over symmetric limits to get

$$\int_{- \infty}^{\infty}xg(x)\, dx = 0$$

Therefore ${\mathbb{E}}\lbrack X - \mu\rbrack = 0$, thus

$${\mathbb{E}}\lbrack X\rbrack = \mu$$

Application to $X \sim N(0,1)$: Since the standard normal density $\varphi(x) = \frac{1}{\sqrt{2\pi}}e^{- x^{2}/2}$ satisfies $\varphi(0 + x) = \varphi(0 - x)$, so it is symmetric about $\mu = 0$. Hence

$${\mathbb{P}}(X \leq 0) = {\mathbb{P}}(X \geq 0) = \frac{1}{2}\quad\text{and}\quad{\mathbb{E}}\lbrack X\rbrack = 0$$
:::

## Problem 5 {#problem-5-2}

An airline has observed that $5\%$ of ticket holders do not show up for their flight. Today's flight has an airplane with 200 seats, and the airline has sold 203 tickets. What is the probability that the airline will not be able to accommodate a ticketed passenger? Assume that, for each passenger $i$, the event $A_{i}$ that passenger $i$ shows up is independent of all others, for $1 \leq i \leq 203$.

::: solution
**Solution**

Let $S$ be the number of passengers who show up. The condition indicates that $S$ is a binomial random variable with parameters $n = 203$ and $p = 0.95$:

$$S \sim Binomial(n = 203,p = 0.95)$$

The airline cannot accommodate everyone exactly when more than 200 passengers show up, i.e.

$${\mathbb{P}}(\text{cannot accommodate}) = {\mathbb{P}}(S \geq 201) = \sum\limits_{k = 201}^{203}\left( \frac{203}{k} \right)(0.95)^{k}(0.05)^{203 - k}$$

Equivalently, letting $N := 203 - S$ be the number of no-shows, we have $N \sim Binomial(203,0.05)$ and

$${\mathbb{P}}(S \geq 201) = {\mathbb{P}}(N \leq 2) = \sum\limits_{j = 0}^{2}\left( \frac{203}{j} \right)(0.05)^{j}(0.95)^{203 - j}$$

Numerically we can calculate

$${\mathbb{P}}(\text{cannot accommodate}) \approx 0.206\%$$
:::

## Problem 6 {#problem-6-2}

Consider a sequence of tosses of a fair die. We continue tossing until both outcomes 3 and 4 have appeared at least once. For example, one possible sequence of results is

$$5,1,1,4,6,5,4,2,6,3,$$

and we then stop. Let $X$ be the number of tosses required (in this example, $X = 10$ ). What is the expected value of the random variable $X$ ?

::: solution
**Solution**

We can decompose the waiting time into two stages.

Stage 1: wait until the first time we see either 3 or 4: On each toss, the probability to get a 3 or 4 is $2/6 = 1/3$. Hence the number of tosses $T_{1}$ until the first occurrence of $\left\{ {3,4} \right\}$ is geometric with success probability $1/3$, so

$${\mathbb{E}}\lbrack T_{1}\rbrack = \frac{1}{1/3} = 3$$

Stage 2: after seeing one of them, wait until we see the other: Once 3 has appeared, each subsequent toss produces a 4 with probability $1/6$; otherwise we are still missing a 4. Thus the additional waiting time $T_{2}$ is geometric with success probability $1/6$, so

$${\mathbb{E}}\lbrack T_{2}\rbrack = \frac{1}{1/6} = 6$$

Since $X = T_{1} + T_{2}$, by linearity of expectation we get

$${\mathbb{E}}\lbrack X\rbrack = {\mathbb{E}}\lbrack T_{1}\rbrack + {\mathbb{E}}\lbrack T_{2}\rbrack = 3 + 6 = 9$$
:::

# Homework 3

## Problem 1 {#problem-1-3}

Let $Z$ be a standard normal random variable $Z \sim N(0,1)$. We denote by $\Phi$ its distribution function. Answer the questions below

- If $a,b \in {\mathbb{R}}$ with $a > 0$, show that the random variable $aZ + b$ is also normal and find its mean and variance.

- Show that $\Phi(0) = 1/2$.

- Show that $\Phi( - x) = 1 - \Phi(x)$ for any $x \in {\mathbb{R}}$.

::: solution
**Solution**

- $Z \sim N(0,1)$ has density

  $$f_{Z}(z) = \frac{1}{\sqrt{2\pi}}e^{- z^{2}/2}$$$$\begin{matrix}
  {F_{X}(x) = {\mathbb{P}}(X \leq x)} & {= {\mathbb{P}}(aZ + b \leq x)} \\
   & {= {\mathbb{P}}\left( {Z \leq \frac{x - b}{a}} \right)} \\
   & {= \Phi\left( \frac{x - b}{a} \right)}
  \end{matrix}$$

  Thus

  $$f_{X}(x) = \frac{d}{dx}\Phi\left( \frac{x - b}{a} \right) = \frac{1}{a}\varphi\left( \frac{x - b}{a} \right) = \frac{1}{\sqrt{a^{22}\pi}}e^{- \frac{(x - b)^{2}}{2a^{2}}}$$

  Note this is the density of a normal distribution with mean $b$ and variance $a^{2}$. Therefore

  $$aZ + b \sim N(b,a^{2})$$

  Since $Z$ has mean $0$ and variance $1$, use linearity we have

  $${\mathbb{E}}\lbrack aZ + b\rbrack = a{\mathbb{E}}\lbrack Z\rbrack + b = b$$

  and

  $$Var(aZ + b) = a^{2}Var(Z) = a^{2}$$

- Note the standard normal density is an even function:

  $$\varphi(x) = \frac{1}{\sqrt{2\pi}}e^{- x^{2}/2} = \varphi( - x)$$

  Thus

  $$\Phi(0) = \int_{- \infty}^{0}\varphi(x)\, dx = \int_{0}^{\infty}\varphi(x)\, dx$$

  Since $\int_{- \infty}^{\infty}\varphi(x)\, dx = 1$, the two equal halves are each $1/2$, so $\Phi(0) = 1/2$.

- For any $x \in {\mathbb{R}}$,

  $$\Phi( - x) = \int_{- \infty}^{- x}\varphi(t)\, dt$$

  Let $u = - t$, using $\varphi( - u) = \varphi(u)$ we have

  $$\Phi( - x) = \int_{\infty}^{x}\varphi( - u)( - du) = \int_{x}^{\infty}\varphi(u)\, du = 1 - \int_{- \infty}^{x}\varphi(u)\, du = 1 - \Phi(x)$$
:::

## Problem 2 {#problem-2-3}

Let $X$ and $Y$ be random variables with joint density

$$f(x,y) = \left\{ \begin{matrix}
{- xy,} & {(x,y) \in ( - 1,0) \times (0,1) \cup (1,2) \times ( - 1,0),} \\
{0,} & \text{otherwise}
\end{matrix} \right.$$

- Compute the probability ${\mathbb{P}}(X + Y < 0)$.

- Compute the expected value ${\mathbb{E}}\lbrack XY\rbrack$.

- Are $X$ and $Y$ independent?

::: solution
**Solution**

- On $(1,2) \times ( - 1,0)$ we have $x + y > 0$ since $x > 1$ and $y > - 1$, hence this region contributes nothing to $\left\{ {X + Y < 0} \right\}$.

  On $( - 1,0) \times (0,1)$, the ineq $x + y < 0$ is equivalent to $0 < y < - x$. Therefore,

  $${\mathbb{P}}(X + Y < 0) = \int_{- 1}^{0}\int_{0}^{- x}( - xy)\, dy\, dx$$

  Compute the inner integral:

  $$\int_{0}^{- x}( - xy)\, dy = - x \cdot \frac{( - x)^{2}}{2} = - \frac{x^{3}}{2}$$

  Hence,

  [ℙ(𝑋+𝑌\<0)=∫−10(−𝑥32)𝑑𝑥=−12⋅𝑥44−10=18]{.math display="block"}

- By def,

  $$\begin{matrix}
  {{\mathbb{E}}\lbrack XY\rbrack} & {= \int_{{\mathbb{R}}^{2}}xy\, f(x,y)\, dx\, dy} \\
   & {= - \int_{( - 1,0) \times (0,1) \cup (1,2) \times ( - 1,0)}x^{2}y^{2}\, dx\, dy} \\
   & {= - \int_{- 1}^{0}\int_{0}^{1}x^{2}y^{2}\, dy\, dx - \int_{1}^{2}\int_{- 1}^{0}x^{2}y^{2}\, dy\, dx}
  \end{matrix}$$

  Split over the two rectangles. On $( - 1,0) \times (0,1)$,

  $$- \int_{- 1}^{0}\int_{0}^{1}x^{2}y^{2}\, dy\, dx = - \left( {\int_{- 1}^{0}x^{2}\, dx} \right)\left( {\int_{0}^{1}y^{2}\, dy} \right) = - \left( \frac{1}{3} \right)\left( \frac{1}{3} \right) = - \frac{1}{9}$$

  On $(1,2) \times ( - 1,0)$,

  $$- \int_{1}^{2}\int_{- 1}^{0}x^{2}y^{2}\, dy\, dx = - \left( {\int_{1}^{2}x^{2}\, dx} \right)\left( {\int_{- 1}^{0}y^{2}\, dy} \right) = - \left( \frac{7}{3} \right)\left( \frac{1}{3} \right) = - \frac{7}{9}$$

  Thus,

  $${\mathbb{E}}\lbrack XY\rbrack = - \frac{1}{9} - \frac{7}{9} = - \frac{8}{9}$$

- Consider: For $x \in ( - 1,0)$,

  $$f_{X}(x) = \int_{0}^{1}( - xy)\, dy = \frac{- x}{2}$$

  For $y \in (0,1)$,

  $$f_{Y}(y) = \int_{- 1}^{0}( - xy)\, dx = y\int_{- 1}^{0}( - x)\, dx = \frac{y}{2}$$

  And for $(x,y) \in ( - 1,0) \times (0,1)$,

  $$f_{X}(x)f_{Y}(y) = \left( \frac{- x}{2} \right)\left( \frac{y}{2} \right) = \frac{- xy}{4} \neq - xy = f(x,y)$$

  Thus $X$ and $Y$ are not independent.
:::

## Problem 3 {#problem-3-3}

Let $X \sim \text{Exp}(1)$ and $Y = X + \frac{1}{X + 1}$. Find ${\mathbb{P}}((X + 1)Y \leq 2)$ and $\text{Cov}(X,Y)$.\
Hint: You may leave your answer as a function of the integral $\int_{0}^{\infty}\frac{e^{- x}}{1 + x}dx$.

::: solution
**Solution**

Note

$$(X + 1)Y = (X + 1)\left( {X + \frac{1}{X + 1}} \right) = X(X + 1) + 1 = X^{2} + X + 1$$

Thus,

$$(X + 1)Y \leq 2\Leftrightarrow X^{2} + X - 1 \leq 0$$

The roots of $x^{2} + x - 1 = 0$ are $\frac{- 1 \pm \sqrt{5}}{2}$. Since $X \geq 0$, the event is

$$0 \leq X \leq \frac{\sqrt{5} - 1}{2}$$

Therefore, using the CDF of $Exp(1)$,

$${\mathbb{P}}((X + 1)Y \leq 2) = {\mathbb{P}}(X \leq \frac{\sqrt{5} - 1}{2}) = 1 - e^{- \frac{\sqrt{5} - 1}{2}} = 1 - \exp\mspace{-18mu}\left( {- \frac{\sqrt{5} - 1}{2}} \right)$$

Nowe we compute the covariance. By def,

$$Cov(X,Y) = {\mathbb{E}}\lbrack XY\rbrack - {\mathbb{E}}\lbrack X\rbrack{\mathbb{E}}\lbrack Y\rbrack$$

For $X \sim Exp(1)$, ${\mathbb{E}}\lbrack X\rbrack = 1$ and ${\mathbb{E}}\lbrack X^{2}\rbrack = 2$. Let

$$I := \int_{0}^{\infty}\frac{e^{- x}}{1 + x}\, dx = {\mathbb{E}}\mspace{-18mu}\left\lbrack \frac{1}{1 + X} \right\rbrack$$

Then

$${\mathbb{E}}\lbrack Y\rbrack = {\mathbb{E}}\lbrack X\rbrack + {\mathbb{E}}\mspace{-18mu}\left\lbrack \frac{1}{1 + X} \right\rbrack = 1 + I$$

Also,

$$XY = X\left( {X + \frac{1}{1 + X}} \right) = X^{2} + \frac{X}{1 + X} = X^{2} + \left( {1 - \frac{1}{1 + X}} \right)$$

so

$${\mathbb{E}}\lbrack XY\rbrack = {\mathbb{E}}\lbrack X^{2}\rbrack + 1 - {\mathbb{E}}\mspace{-18mu}\left\lbrack \frac{1}{1 + X} \right\rbrack = 2 + 1 - I = 3 - I$$

Hence,

$$Cov(X,Y) = (3 - I) - (1)(1 + I) = 2 - 2I = 2 - 2\int_{0}^{\infty}\frac{e^{- x}}{1 + x}\, dx$$
:::

## Problem 4 {#problem-4-3}

Find the conditional density $f_{Y \mid X}(y \mid x)$ of $Y$ given that $X = x$ and the corresponding conditional expectation ${\mathbb{E}}\lbrack Y \mid X = x\rbrack$ if the pair of random variables $(X,Y)$ has absolutely continuous distribution with joint density: $f_{X,Y}(x,y) = \lambda^{2}e^{- \lambda y}\mathbf{1}_{\{{0 \leq x \leq y}\}}$.

::: solution
**Solution**

Given the joint density $f_{X,Y}(x,y) = \lambda^{2}e^{- \lambda y}\mathbf{1}_{\{{0 \leq x \leq y}\}}$, we first compute the marginal density of $X$. For $x \geq 0$,

$$f_{X}(x) = \int_{y = x}^{\infty}\lambda^{2}e^{- \lambda y}\, dy = \lambda^{2} \cdot \frac{e^{- \lambda x}}{\lambda} = \lambda e^{- \lambda x}$$

and $f_{X}(x) = 0$ for $x < 0$.

Therefore, for $x \geq 0$,

$$\left. f_{Y|X}(y \middle| x) = \frac{f_{X,Y}(x,y)}{f_{X}(x)} = \frac{\lambda^{2}e^{- \lambda y}\mathbf{1}_{\{{y \geq x}\}}}{\lambda e^{- \lambda x}} = \lambda e^{- \lambda(y - x)}\mathbf{1}_{\{{y \geq x}\}} \right.$$

This shows that $\left. Y \middle| X = x \right.$ has the same distribution as $x + E$ where $E \sim Exp(\lambda)$, hence

$$\left. {\mathbb{E}}\lbrack Y \middle| X = x\rbrack = x + \frac{1}{\lambda} \right.$$
:::

## Problem 5 {#problem-5-3}

A machine produces a coin that shows heads with a random probability $p$. The value of $p$ is unknown to us, but from many observations of the coins produced by the machine we know that the distribution of the random parameter $p$ is uniform on $(0,1/2)$. We start tossing the coin. Compute the following probabilities:

- The coin shows heads on the first toss.

- The expected number of tosses until tails show up.

::: solution
**Solution**

- The head probability $p \sim Unif(0,1/2)$. Thus the density is:

  $$f_{P}(p) = 2\,\mathbf{1}_{(0,1/2)}(p)$$

  The unconditional probability of heads on the first toss is

  [ℙ(H on first toss)=𝔼\[𝑝\]=∫01/2𝑝⋅2𝑑𝑝=2⋅𝑝2201/2=14]{.math display="block"}

- Let $T$ be the number of tosses until the first tail occurs. Conditional on $p$, tails occurs with probability $1 - p$ each toss, so $T$ is geometric with parameter $1 - p$. Hence

  $$\left. {\mathbb{E}}\lbrack T\, \middle| \, p\rbrack = \frac{1}{1 - p} \right.$$

  Taking expectation over $p$,

  [𝔼\[𝑇\]=𝔼\[11−𝑝\]=∫01/211−𝑝⋅2𝑑𝑝=2−ln(1−𝑝)01/2=2ln2]{.math display="block"}
:::

## Problem 6 {#problem-6-3}

The joint probability density function of the random variables $X$ and $Y$ is given by

$$f_{X,Y}(x,y) = \left\{ \begin{matrix}
{c\left( {x^{2} + \frac{xy}{2}} \right),} & {(x,y) \in (0,1) \times (0,2)} \\
{0,} & \text{otherwise}
\end{matrix} \right.$$

- Find the constant $c$.

- Find the marginal density of $X$ and compute ${\mathbb{E}}\lbrack X\rbrack$.

- Compute ${\mathbb{P}}(X > Y)$.

- Compute ${\mathbb{P}}\left( Y > \frac{1}{2} \middle| \, X < \frac{1}{2} \right)$.

::: solution
**Solution**

- Determine $c$ from normalization:

  $$1 = \int_{0}^{1}\int_{0}^{2}c\left( {x^{2} + \frac{xy}{2}} \right)\, dy\, dx$$

  For fixed $x$,

  [∫02(𝑥2+𝑥𝑦2)𝑑𝑦=2𝑥2+𝑥2⋅𝑦2202=2𝑥2+𝑥]{.math display="block"}

  Thus

  $$1 = c\int_{0}^{1}(2x^{2} + x)\, dx = c\left( {\frac{2}{3} + \frac{1}{2}} \right) = c \cdot \frac{7}{6}$$

  so $c = \frac{6}{7}$

- The marginal density of $X$ (for $0 < x < 1$) is

  $$f_{X}(x) = \int_{0}^{2}c\left( {x^{2} + \frac{xy}{2}} \right)\, dy = c(2x^{2} + x) = \frac{6}{7}(2x^{2} + x)$$

  and $f_{X}(x) = 0$ otherwise.

  Thus

  $${\mathbb{E}}\lbrack X\rbrack = \int_{0}^{1}xf_{X}(x)\, dx = \frac{6}{7}\int_{0}^{1}(2x^{3} + x^{2})\, dx = \frac{6}{7}\left( {\frac{1}{2} + \frac{1}{3}} \right) = \frac{5}{7}$$

- The event $\left\{ {X > Y} \right\}$ corresponds to the region $0 < y < x < 1$ (since $x \in (0,1)$). Hence

  $${\mathbb{P}}(X > Y) = \int_{0}^{1}\int_{0}^{x}c\left( {x^{2} + \frac{xy}{2}} \right)\, dy\, dx$$

  For fixed $x$,

  [∫0𝑥(𝑥2+𝑥𝑦2)𝑑𝑦=𝑥3+𝑥2⋅𝑦220𝑥=𝑥3+𝑥34=54𝑥3]{.math display="block"}

  Therefore

  $${\mathbb{P}}(X > Y) = c\int_{0}^{1}\frac{5}{4}x^{3}\, dx = c \cdot \frac{5}{4} \cdot \frac{1}{4} = c \cdot \frac{5}{16} = \frac{6}{7} \cdot \frac{5}{16} = \frac{15}{56}$$

- By definition,

  $${\mathbb{P}}\mspace{-18mu}\left( Y > \frac{1}{2} \middle| \ X < \frac{1}{2} \right) = \frac{{\mathbb{P}}\left( {Y > \frac{1}{2},\ X < \frac{1}{2}} \right)}{{\mathbb{P}}\left( {X < \frac{1}{2}} \right)}$$

  Calculate each part. First the denominator:

  $${\mathbb{P}}\left( {X < \frac{1}{2}} \right) = \int_{0}^{1/2}f_{X}(x)\, dx = c\int_{0}^{1/2}(2x^{2} + x)\, dx = c\left( {\frac{1}{12} + \frac{1}{8}} \right) = c \cdot \frac{5}{24} = \frac{5}{28}$$

  And the numerator:

  $${\mathbb{P}}\left( {Y > \frac{1}{2},\ X < \frac{1}{2}} \right) = \int_{0}^{1/2}\int_{1/2}^{2}c\left( {x^{2} + \frac{xy}{2}} \right)\, dy\, dx$$

  For fixed $x$,

  [∫1/22(𝑥2+𝑥𝑦2)𝑑𝑦=𝑥2(2−12)+𝑥2⋅𝑦221/22=32𝑥2+𝑥4(4−14)=32𝑥2+1516𝑥]{.math display="block"}

  Thus

  $${\mathbb{P}}\left( {Y > \frac{1}{2},\ X < \frac{1}{2}} \right) = c\int_{0}^{1/2}\left( {\frac{3}{2}x^{2} + \frac{15}{16}x} \right)dx = c\left( {\frac{1}{16} + \frac{15}{128}} \right) = c \cdot \frac{23}{128} = \frac{69}{448}$$

  Therefore,

  $${\mathbb{P}}\mspace{-18mu}\left( Y > \frac{1}{2} \middle| \ X < \frac{1}{2} \right) = \frac{69/448}{5/28} = \frac{69}{80}$$
:::

# Homework 4

## Problem 1 {#problem-1-4}

Let $X$ be a random variable with values in $\lbrack 0, + \infty\rbrack$ such that ${\mathbb{E}}\lbrack X\rbrack = 0$. Explain why $X < \infty$ almost surely and show that $X = 0$ almost surely.

::: proof
**Proof**

Since $X \geq 0$ and ${\mathbb{E}}\lbrack X\rbrack = 0 < \infty$, by Markov's inequality, for any $t > 0$,

$${\mathbb{P}}(X \geq t) \leq \frac{{\mathbb{E}}\lbrack X\rbrack}{t} = 0$$

Hence ${\mathbb{P}}(X \geq t) = 0$ for all $t > 0$. In particular,

$${\mathbb{P}}(X = + \infty) = \lim\limits_{t\rightarrow + \infty}{\mathbb{P}}(X \geq t) = \lim\limits_{t\rightarrow + \infty}0 = 0$$

that is, $X < \infty$ almost surely.

Also notice that

$$\left\{ {X > 0} \right\} = \bigcup\limits_{n = 1}^{\infty}\left\{ {X \geq \frac{1}{n}} \right\}$$

and by countable subadditivity,

$${\mathbb{P}}(X > 0) \leq \sum\limits_{n = 1}^{\infty}{\mathbb{P}}\left( {X \geq \frac{1}{n}} \right) = 0$$

Thus ${\mathbb{P}}(X > 0) = 0$. And since $X$ takes values in $\lbrack 0, + \infty\rbrack$, we have

$${\mathbb{P}}(\left\{ {X = 0} \right\}) = {\mathbb{P}}(\left\{ {X \leq 0} \right\}) = 1 - {\mathbb{P}}(\left\{ {X > 0} \right\}) = 1$$

, and

This finishes the proof that $X < \infty$ a.s. and $X = 0$ a.s.
:::

## Problem 2 {#problem-2-4}

Let $X$ be a random variable with ${\mathbb{E}}\lbrack X\rbrack = 3$ and ${\mathbb{E}}\lbrack X^{2}\rbrack = 13$. Show that:

$${\mathbb{P}}( - 2 \leq X \leq 8) \geq \frac{21}{25}$$

::: solution
**Solution**

Compute the variance of $X$:

$$Var(X) = {\mathbb{E}}\lbrack X^{2}\rbrack - ({\mathbb{E}}\lbrack X\rbrack)^{2} = 13 - 3^{2} = 4$$

Observe that

$$\left. {\mathbb{P}}( - 2 \leq X \leq 8) = {\mathbb{P}}( \middle| X - 3 \middle| \leq 5) \right.$$

By Chebyshev's inequality,

$$\left. {\mathbb{P}}( \middle| X - 3 \middle| \geq 5) \leq \frac{Var(X)}{5^{2}} = \frac{4}{25} \right.$$

Therefore,

$$\left. {\mathbb{P}}( \middle| X - 3 \middle| \leq 5) = 1 - {\mathbb{P}}( \middle| X - 3 \middle| \geq 5) \geq 1 - \frac{4}{25} = \frac{21}{25} \right.$$

Thus,

$${\mathbb{P}}( - 2 \leq X \leq 8) \geq \frac{21}{25}$$
:::

## Problem 3 {#problem-3-4}

Let $X,Y$ be two random variables such that ${\mathbb{P}}(Y = 1) = 1/5,{\mathbb{P}}(Y = 2) = 3/5$ and ${\mathbb{P}}(Y = 3) = 1/5$. In addition

$$\left. X \middle| \left\{ {Y = 1} \right\} \sim \text{Exp}(2),X \middle| \left\{ {Y = 2} \right\} \sim \text{Exp}(3)\text{and}\ X \mid \left\{ {Y = 3} \right\} = 7. \right.$$

Compute the moment generating function of $X$.

::: solution
**Solution**

Compute each conditional moment generating function:

For $X \mid \left\{ {Y = 1} \right\} \sim \text{Exp}(2)$

$${\mathbb{E}}\lbrack e^{tX} \mid Y = 1\rbrack = \frac{2}{2 - t},\quad t < 2$$

For $X \mid \left\{ {Y = 2} \right\} \sim \text{Exp}(3)$

$${\mathbb{E}}\lbrack e^{tX} \mid Y = 2\rbrack = \frac{3}{3 - t},\quad t < 3$$

For $X \mid \left\{ {Y = 3} \right\} = 7$,

$${\mathbb{E}}\lbrack e^{tX} \mid Y = 3\rbrack = e^{7t}$$

Then we use the law of total expectation conditioning on $Y$: for any $t$ such that the expectations below are finite, we have

$$\begin{matrix}
{M_{X}(t) = {\mathbb{E}}\lbrack e^{tX}\rbrack} & {= \sum\limits_{y = 1}^{3}{\mathbb{E}}\lbrack e^{tX} \mid Y = y\rbrack{\mathbb{P}}(Y = y)} \\
 & {= \frac{1}{5} \cdot \frac{2}{2 - t} + \frac{3}{5} \cdot \frac{3}{3 - t} + \frac{1}{5}e^{7t}} \\
 & {= \frac{2}{5(2 - t)} + \frac{9}{5(3 - t)} + \frac{1}{5}e^{7t},\quad t < 2}
\end{matrix}$$

So the moment generating function of $X$ is

$$M_{X}(t) = \frac{2}{5(2 - t)} + \frac{9}{5(3 - t)} + \frac{1}{5}e^{7t},\quad t < 2$$
:::

## Problem 4 {#problem-4-4}

For any $n \in {\mathbb{N}}$ with $n \geq 1$ we set $a_{n} = 1/\left( {2n^{2}} \right)$. Consider the sequence of random variables $\left( X_{n} \right)_{n \in {\mathbb{N}}}$ with

$$X_{n} = \left\{ \begin{matrix}
{0,} & {\text{with probability}\ a_{n}} \\
{1,} & {\text{with probability}\ 1 - 2a_{n}} \\
{n^{2},} & {\text{with probability}\ a_{n}}
\end{matrix} \right.$$

Check if $\left( X_{n} \right)$ converges in probability and if $\left( X_{n} \right)$ converges in $L^{1}$.

::: solution
**Solution**

We first show that $X_{n}\rightarrow 1$ in probability.

Let $\varepsilon > 0$.\
For $n$ large enough s.t. $n^{2} - 1 > \varepsilon$, $\left. |X_{n} - 1 \middle| > \varepsilon \right.$ iff $X_{n} = 0$ or $X_{n} = n^{2}$. Therefore,

$$\left. {\mathbb{P}}( \middle| X_{n} - 1 \middle| > \varepsilon) = {\mathbb{P}}(X_{n} = 0) + {\mathbb{P}}(X_{n} = n^{2}) = a_{n} + a_{n} = 2a_{n} = \frac{1}{n^{2}} \right.$$

Since $\frac{1}{n^{2}}\rightarrow 0$, we have:

$$\left. \lim\limits_{n\rightarrow\infty}\ {\mathbb{P}}( \middle| X_{n} - 1 \middle| > \varepsilon) = 0 \right.$$

Since $\varepsilon > 0$ is arbitrary, we conclude that

$$X_{n}\overset{\mathbb{P}}{\rightarrow}1$$

We then show that $X_{n}$ does not converge to $1$ in $L^{1}$.

We compute

$$\begin{matrix}
\left. {\mathbb{E}}\lbrack \middle| X_{n} - 1 \middle| \rbrack \right. & \left. = \middle| 0 - 1 \middle| a_{n} + \middle| 1 - 1 \middle| (1 - 2a_{n}) + \middle| n^{2} - 1 \middle| a_{n} \right. \\
 & {= a_{n} + (n^{2} - 1)a_{n}} \\
 & {= n^{2}a_{n} = \frac{1}{2}\operatorname{\rightarrow\not{}}0}
\end{matrix}$$

Hence \$\$X_n \\not\\xrightarrow{L\^1} 1\$\$
:::

## Problem 5 {#problem-5-4}

Let $X$ and $Y$ be independent random variables with densities

$$\begin{matrix}
{f_{X}(x) = \{ 2x,} & {0 \leq x \leq 1,} \\
{0,} & {\text{otherwise}\quad f_{Y}(y) = \left\{ \begin{matrix}
{1/2,} & {0 \leq y \leq 2} \\
{0,} & \text{otherwise}
\end{matrix} \right.}
\end{matrix}$$

Find the distribution function of the sum $Z = X + Y$.

::: solution
**Solution**

Since $X$ and $Y$ are independent, the density of $Z = X + Y$ is given by convolution:

$$f_{Z}(z) = \int_{- \infty}^{\infty}f_{X}(x)f_{Y}(z - x)\, dx$$

where we know

$$f_{X}(x) = 2x\mathbf{1}_{\lbrack 0,1\rbrack}(x),\quad f_{Y}(y) = \frac{1}{2}\mathbf{1}_{\lbrack 0,2\rbrack}(y)$$

Thus

$$\begin{matrix}
{f_{Z}(z)} & {= \int_{- \infty}^{\infty}2x \cdot \frac{1}{2}\mathbf{1}_{\lbrack 0,1\rbrack}(x)\mathbf{1}_{\lbrack 0,2\rbrack}(z - x)\, dx} \\
 & {= \int_{- \infty}^{\infty}x\ \ \mathbf{1}_{\lbrack 0,1\rbrack}(x)\ \ \mathbf{1}_{\lbrack 0,2\rbrack}(z - x)\, dx} \\
 & {= \int_{\max(0,z - 2)}^{\min(1,z)}x\, dx}
\end{matrix}$$

Compute this piecewise: If $0 \leq z \leq 1$, then the interval is $\lbrack 0,z\rbrack$, so

$$f_{Z}(z) = \int_{0}^{z}x\, dx = \frac{z^{2}}{2}$$

If $1 \leq z \leq 2$, then the interval is $\lbrack 0,1\rbrack$, so

$$f_{Z}(z) = \int_{0}^{1}x\, dx = \frac{1}{2}$$

If $2 \leq z \leq 3$, then the interval is $\lbrack z - 2,1\rbrack$, so

$$f_{Z}(z) = \int_{z - 2}^{1}x\, dx = \frac{1 - (z - 2)^{2}}{2}$$

Outside $\lbrack 0,3\rbrack$, clearly $f_{Z}(z) = 0$. Therefore,

$$f_{Z}(z) = \left\{ \begin{matrix}
{0,} & {z < 0,} \\
{\frac{z^{2}}{2},} & {0 \leq z \leq 1,} \\
{\frac{1}{2},} & {1 \leq z \leq 2,} \\
{\frac{1 - (z - 2)^{2}}{2},} & {2 \leq z \leq 3,} \\
{0,} & {z > 3}
\end{matrix} \right.$$

Now we integrate to get the cdf. For $z < 0$, $F_{Z}(z) = 0$.

For $0 \leq z \leq 1$,

$$F_{Z}(z) = \int_{0}^{z}\frac{t^{2}}{2}\, dt = \frac{z^{3}}{6}$$

For $1 \leq z \leq 2$,

$$F_{Z}(z) = F_{Z}(1) + \int_{1}^{z}\frac{1}{2}\, dt = \frac{1}{6} + \frac{z - 1}{2} = \frac{z}{2} - \frac{1}{3}$$

For $2 \leq z \leq 3$,

$$F_{Z}(z) = F_{Z}(2) + \int_{2}^{z}\frac{1 - (t - 2)^{2}}{2}\, dt = \frac{2}{3} + \frac{z - 2}{2} - \frac{(z - 2)^{3}}{6}$$

And for $z \geq 3$, $F_{Z}(z) = 1$.

Hence the cdf of $Z = X + Y$ is

$$F_{Z}(z) = \left\{ \begin{matrix}
{0,} & {z < 0,} \\
{\frac{z^{3}}{6},} & {0 \leq z \leq 1,} \\
{\frac{z}{2} - \frac{1}{3},} & {1 \leq z \leq 2,} \\
{\frac{2}{3} + \frac{z - 2}{2} - \frac{(z - 2)^{3}}{6},} & {2 \leq z \leq 3,} \\
{1,} & {z \geq 3}
\end{matrix} \right.$$
:::

## Problem 6 {#problem-6-4}

Let $a_{1},a_{2},\ldots,a_{n}$ and $\lambda$ be positive constants and let $\left\{ {X_{i}:1 \leq i \leq n} \right\}$ be independent random variables with

$$X_{i} \sim \Gamma\left( {a_{i},\lambda} \right),\quad i = 1,2,\ldots,n$$

(i.e., with the same second parameter $\lambda$ ). Show that $X_{1} + X_{2} + \cdots + X_{n} \sim \Gamma(a,\lambda)$, with $a = \sum_{i = 1}^{n}a_{i}$.

::: proof
**Proof**

Let

$$S_{n} := X_{1} + X_{2} + \cdots + X_{n},\quad a = \sum\limits_{i = 1}^{n}a_{i}$$

We need to show that $S_{n} \sim \Gamma(a,\lambda)$.

Since $X_{i} \sim \Gamma(a_{i},\lambda)$, its moment generating function is

$$M_{X_{i}}(t) = {\mathbb{E}}\lbrack e^{tX_{i}}\rbrack = \left( \frac{\lambda}{\lambda - t} \right)^{a_{i}},\quad t < \lambda$$

Since $X_{1},\ldots,X_{n}$ are independent, the moment generating function of $S_{n}$ is

$$M_{S_{n}}(t) = {\mathbb{E}}\lbrack e^{t(X_{1} + \cdots + X_{n})}\rbrack = \prod\limits_{i = 1}^{n}{\mathbb{E}}\lbrack e^{tX_{i}}\rbrack = \prod\limits_{i = 1}^{n}M_{X_{i}}(t)$$

Therefore,

$$M_{S_{n}}(t) = \prod\limits_{i = 1}^{n}\left( \frac{\lambda}{\lambda - t} \right)^{a_{i}} = \left( \frac{\lambda}{\lambda - t} \right)^{\sum_{i = 1}^{n}a_{i}} = \left( \frac{\lambda}{\lambda - t} \right)^{a},\quad t < \lambda$$

Note this is exactly the moment generating function of a $\Gamma(a,\lambda)$ random variable. Hence,

$$S_{n} = X_{1} + \cdots + X_{n} \sim \Gamma(a,\lambda),\quad a = \sum\limits_{i = 1}^{n}a_{i}$$
:::

# Homework 5

## Problem 1 {#problem-1-5}

Let $\left( U_{i} \right)_{i \in {\mathbb{N}}}$ be an i.i.d sequence of random variables with $U_{i} \sim U(\lbrack 0,1\rbrack)$. Show that

- $\lim_{n\rightarrow\infty}\left( {U_{1}U_{2}\ldots U_{n}} \right)^{1/n} = e^{- 1}$ almost surely.

- $\lim_{n\rightarrow\infty}U_{1}U_{2}\ldots U_{n} = 0$ almost surely.

::: proof
**Proof**

- Let

  $$X_{i} := - \log U_{i},\quad i \in {\mathbb{N}}$$

  Since $U_{i} \sim U(\lbrack 0,1\rbrack)$, for $x \geq 0$,

  $${\mathbb{P}}(X_{i} \leq x) = {\mathbb{P}}( - \log U_{i} \leq x) = {\mathbb{P}}(U_{i} \geq e^{- x}) = 1 - e^{- x}$$

  Thus $X_{i} \sim Exp(1)$, so ${\mathbb{E}}\lbrack X_{i}\rbrack = 1$. Also,

  $$\log\left( {(U_{1}U_{2}\cdots U_{n})^{1/n}} \right) = \frac{1}{n}\sum\limits_{i = 1}^{n}\log U_{i} = - \frac{1}{n}\sum\limits_{i = 1}^{n}X_{i}$$

  By the Strong Law of Large Numbers,

  $$\frac{1}{n}\sum\limits_{i = 1}^{n}X_{i} = \frac{1}{n}\sum\limits_{i = 1}^{n}\log U_{i}\rightarrow 1\quad\text{a.s.}$$

  Since the exponential function is continuous,

  $$(U_{1}U_{2}\cdots U_{n})^{1/n} = \exp\left( {\frac{1}{n}\sum\limits_{i = 1}^{n}\log U_{i}} \right)\rightarrow e^{- 1}\quad\text{a.s.}$$

- Let

  $$P_{n} := U_{1}U_{2}\cdots U_{n}$$

  Then from the first part we instantly have

  $$P_{n}^{1/n}\rightarrow e^{- 1} < 1\quad\text{a.s.}$$

  Then for any event $\omega$ in the event of probability one where this convergence holds, choose $r$ s.t. $e^{- 1} < r < 1$, then for all sufficiently large $n$,

  $$P_{n}(\omega)^{1/n} < r,\quad\text{i.e.}\quad P_{n}(\omega) < r^{n}$$

  Since $0 < r < 1$, we have $r^{n}\rightarrow 0$. Therefore $P_{n}(\omega)\rightarrow 0$. Therefore

  $$U_{1}U_{2}\cdots U_{n}\rightarrow 0\quad\text{a.s.}$$
:::

## Problem 2 {#problem-2-5}

A factory produces small resistors, and the resistance of each resistor is a random variable $X_{i}$ with unknown mean $\mu$ and variance $\sigma^{2} = 0.25$ ohms $\begin{matrix}
\end{matrix}^{2}$. The quality control engineer wants to estimate the average resistance of a batch. She decides to measure $n$ resistors and compute the sample average

$${\bar{X}}_{n} := \frac{X_{1} + X_{2} + \cdots + X_{n}}{n}$$

Determine approximately the number of resistors $n$ she needs to measure so that the probability that the sample mean differs from the true mean by more than 0.005 ohms is less than $1\%$, i.e.,

$${\mathbb{P}}\left( {\left| {{\bar{X}}_{n} - \mu} \right| > 0.005} \right) < 0.01$$

::: proof
**Proof**

By linearity of expectation,

$${\mathbb{E}}\lbrack{\bar{X}}_{n}\rbrack = \mu$$

And (assmuming the $X_{i}$ are independent), we have

$$Var\left( {\sum\limits_{i = 1}^{n}X_{i}} \right) = \sum\limits_{i = 1}^{n}Var(X_{i}) + \sum\limits_{i \neq j}Cov(X_{i},X_{j}) = n\sigma^{2} = 0.25n$$

Thus

$$Var({\bar{X}}_{n}) = \frac{\sigma^{2}}{n} = \frac{0.25}{n}$$

By Chebyshev's inequality, for any $\varepsilon > 0$,

$${\mathbb{P}}\left( |\ {\bar{X}}_{n} - \mu\  \middle| > \varepsilon \right) \leq \frac{Var({\bar{X}}_{n})}{\varepsilon^{2}}$$

Taking $\varepsilon = 0.005$, we get

$${\mathbb{P}}\left( |\ {\bar{X}}_{n} - \mu\  \middle| > 0.005 \right) \leq \frac{0.25/n}{(0.005)^{2}} = \frac{0.25}{n \cdot 0.000025} = \frac{10000}{n}$$

We want this upper bound to be less than $0.01$, so it is enough to require

$$\frac{10000}{n} < 0.01$$

Therefore, she needs to measure approximately $n \approx 1,000,000$ resistors.
:::

## Problem 3 {#problem-3-5}

Let $\left( X_{n} \right)_{n \in {\mathbb{N}}}$ be a sequence of random variables with ${\mathbb{P}}\left( {X_{n} \neq 0} \right) = 1/n^{2}$ for all $n \in {\mathbb{N}}$. Show that with probability 1, there exists an $n_{0} \in {\mathbb{N}}$ such that $X_{n} = 0$ for all $n \geq n_{0}$.

::: proof
**Proof**

Let

$$A_{n} := \left\{ {X_{n} \neq 0} \right\},\quad n \in {\mathbb{N}}$$

Then ${\mathbb{P}}(A_{n}) = \frac{1}{n^{2}}$ by assumption. Hence

$$\sum\limits_{n = 1}^{\infty}{\mathbb{P}}(A_{n}) = \sum\limits_{n = 1}^{\infty}\frac{1}{n^{2}} < \infty$$

By Borel-Cantelli lemma,

$${\mathbb{P}}\left( {\operatorname{lim\, sup}\limits_{n\rightarrow\infty}A_{n}} \right) = 0$$

So with probability $1$, only finitely many of the events $A_{n}$ occur. In other words, with probability $1$, there exists $n_{0} \in {\mathbb{N}}$ such that for all $n \geq n_{0}$,

$$A_{n}^{c} = \left\{ {X_{n} = 0} \right\}$$

occurs. Equivalently,

$$X_{n} = 0\qquad\text{for all}\ n \geq n_{0}$$

Therefore, with probability $1$, there exists $n_{0} \in {\mathbb{N}}$ such that $X_{n} = 0$ for all $n \geq n_{0}$.
:::

## Problem 4 {#problem-4-5}

Assume that $\left( X_{n} \right)_{n \in {\mathbb{N}}}$ be a sequence of i.i.d random variables with density

$$f(x) = \left\{ \begin{matrix}
{\frac{1}{2\sqrt{x}},} & {\text{if}\ x \in (0,1),} \\
{0,} & \text{otherwise}
\end{matrix} \right.$$

- Find the distribution function of $X_{1}$.

- Let $Y_{n} = \min\left\{ {X_{1},\ldots,X_{n}} \right\}$ for any $n \in {\mathbb{N}}$. Show that $n^{2}Y_{n}\overset{d}{\rightarrow}Y$, where $Y$ has distribution function

  $$F_{Y}(x) = \left\{ \begin{matrix}
  {0,} & {\text{if}\ x \leq 0} \\
  {1 - e^{- \sqrt{x}},} & \text{otherwise}
  \end{matrix} \right.$$

::: proof
**Proof**

- For $x \in {\mathbb{R}}$,

  $$F_{X_{1}}(x) = {\mathbb{P}}(X_{1} \leq x) = \int_{- \infty}^{x}f(t)\, dt = \left\{ \begin{matrix}
  {0,} & {x \leq 0,} \\
  {\int_{0}^{x}\frac{1}{2\sqrt{t}}\, dt = \sqrt{x},} & {0 < x < 1,} \\
  {1,} & {x \geq 1.}
  \end{matrix} \right.$$

- If $x \leq 0$, then $n^{2}Y_{n} \geq 0$, so

  $${\mathbb{P}}(n^{2}Y_{n} \leq x) = 0$$

  Now consider $x > 0$. Then

  $${\mathbb{P}}(n^{2}Y_{n} > x) = {\mathbb{P}}\left( {Y_{n} > \frac{x}{n^{2}}} \right)$$

  Since

  $$Y_{n} > \frac{x}{n^{2}}\Leftrightarrow X_{1} > \frac{x}{n^{2}},\ldots,X_{n} > \frac{x}{n^{2}}$$

  and the $X_{i}$ are independent,

  $${\mathbb{P}}\left( {Y_{n} > \frac{x}{n^{2}}} \right) = \left( {{\mathbb{P}}\left( {X_{1} > \frac{x}{n^{2}}} \right)} \right)^{n}$$

  For all sufficiently large $n$, we have $0 < \frac{x}{n^{2}} < 1$, hence

  $${\mathbb{P}}\left( {X_{1} > \frac{x}{n^{2}}} \right) = 1 - F_{X_{1}}\left( \frac{x}{n^{2}} \right) = 1 - \sqrt{\frac{x}{n^{2}}} = 1 - \frac{\sqrt{x}}{n}$$

  Therefore,

  $${\mathbb{P}}(n^{2}Y_{n} > x) = \left( {1 - \frac{\sqrt{x}}{n}} \right)^{n}$$

  so

  $$F_{n^{2}Y_{n}}(x) = {\mathbb{P}}(n^{2}Y_{n} \leq x) = 1 - \left( {1 - \frac{\sqrt{x}}{n}} \right)^{n}$$

  Taking $n\rightarrow\infty$, we use the standard limit

  $$\left( {1 - \frac{a}{n}} \right)^{n}\rightarrow e^{- a}$$

  with $a = \sqrt{x}$, we obtain

  $$F_{n^{2}Y_{n}}(x)\rightarrow 1 - e^{- \sqrt{x}},\quad x > 0$$

  Thus,

  $$F_{n^{2}Y_{n}}(x)\rightarrow\left\{ \begin{matrix}
  {0,} & {x \leq 0,} \\
  {1 - e^{- \sqrt{x}},} & {x > 0}
  \end{matrix} \right.$$

  which is exactly $F_{Y}(x)$. Hence

  $$n^{2}Y_{n}\overset{d}{\rightarrow}Y$$
:::

## Problem 5 {#problem-5-5}

Let $\left( X_{n} \right)_{n \in {\mathbb{N}}}$ be a sequence of random variables with values in $\mathbb{R}$. Show that there exists a sequence $\left( a_{n} \right)_{n \in {\mathbb{N}}}$ with $a_{n} > 0$ such that

$$\frac{X_{n}}{a_{n}}\overset{\text{a.s.}}{\rightarrow}0$$

For simplicity you may assume that $X_{n} \sim \text{Exp}(1/n)$.

Hint: For any $n \in {\mathbb{N}}$ construct $b_{n}$ such that ${\mathbb{P}}\left( {\left| X_{n} \right| \geq b_{n}} \right) \leq \frac{1}{2^{n}}$ and use Borel-Cantelli for the events $\left\{ {\left| X_{n} \right|/b_{n} \geq n} \right\}$.

::: proof
**Proof**

For each $n \in {\mathbb{N}}$, choose $b_{n} > 0$ such that

$$\left. {\mathbb{P}}( \middle| X_{n} \middle| \geq b_{n}) \leq \frac{1}{2^{n}} \right.$$

Notice such a choice is always possible, since $|X_{n}|$ is a well-defined random variable, which implies $\left. {\mathbb{P}}( \middle| X_{n} \middle| \geq t)\rightarrow 0 \right.$ as $t\rightarrow\infty$.

Now define

$$a_{n} := nb_{n} > 0$$

Consider the sequence of events

$$E_{n} := \left\{ {\frac{|X_{n}|}{a_{n}} \geq \frac{1}{n}} \right\}$$

By the definition of $a_{n}$, we have

$$E_{n} = \left\{ {\frac{|X_{n}|}{nb_{n}} \geq \frac{1}{n}} \right\} = \left\{ |X_{n} \middle| \geq b_{n} \right\}$$

It follows that

$$\left. \sum\limits_{n = 1}^{\infty}{\mathbb{P}}(E_{n}) = \sum\limits_{n = 1}^{\infty}{\mathbb{P}}( \middle| X_{n} \middle| \geq b_{n}) \leq \sum\limits_{n = 1}^{\infty}\frac{1}{2^{n}} < \infty \right.$$

By the first Borel-Cantelli lemma,

$${\mathbb{P}}(E_{n}\ \text{infinitely often}) = 0$$

This means that for almost all $\omega \in \Omega$, there exists $N(\omega) \in {\mathbb{N}}$ such that: for all $n \geq N(\omega)$, the event $E_{n}$ does not occur, i.e.,

$$\frac{|X_{n}(\omega)|}{a_{n}} < \frac{1}{n}$$

Since $1/n\rightarrow 0$ as $n\rightarrow\infty$, it follows immediately that

$$\frac{X_{n}}{a_{n}}\rightarrow 0\quad\text{a.s.}$$

If we assume $X_{n} \sim Exp(1/n)$, we can provide an explicit sequence. Since

$${\mathbb{P}}(X_{n} \geq t) = e^{- t/n}\quad\text{for}\ t \geq 0$$

we can choose $b_{n} = n^{2}\log 2$. So that

$${\mathbb{P}}(X_{n} \geq b_{n}) = e^{- (n^{2}\log 2)/n} = e^{- n\log 2} = \frac{1}{2^{n}}$$

Then $a_{n} = nb_{n} = n^{3}\log 2$, the general argument above guarantees that

$$\frac{X_{n}}{a_{n}} = \frac{X_{n}}{n^{3}\log 2}\overset{\text{a.s.}}{\rightarrow}0$$

This completes the proof.
:::

## Problem 6 {#problem-6-5}

Let $\left\{ X_{i} \right\}_{i \geq 1}$ be i.i.d. positive integer-valued random variables with $0 < {\mathbb{E}}\left\lbrack X_{1} \right\rbrack < \infty$. Interpret $X_{i}$ as the number of children in family $i$. From the first $n$ families, choose a child uniformly at random among all children. Let $N_{n}$ denote the number of children in the selected child's family. Show that $N_{n}\overset{d}{\rightarrow}X_{1}^{\ast}$, where $X_{1}^{\ast}$ has distribution

$${\mathbb{P}}\left( {X_{1}^{\ast} = k} \right) = \frac{k{\mathbb{P}}\left( {X_{1} = k} \right)}{{\mathbb{E}}\left\lbrack X_{1} \right\rbrack}$$

::: proof
**Proof**

For each $n \in {\mathbb{N}}$, let

$$S_{n} := X_{1} + \cdots + X_{n}$$

be the total number of children in the first $n$ families.

Given $X_{1},\ldots,X_{n}$, we choose one child uniformly at random among these $S_{n}$ children. Hence, conditionally on $X_{1},\ldots,X_{n}$, the probability that the chosen child comes from a family with exactly $k$ children is

$${\mathbb{P}}(N_{n} = k \mid X_{1},\ldots,X_{n}) = \frac{\sum_{i = 1}^{n}X_{i}\mathbf{1}_{\{{X_{i} = k}\}}}{S_{n}}$$

Since $X_{i}\mathbf{1}_{\{{X_{i} = k}\}} = k\mathbf{1}_{\{{X_{i} = k}\}}$, this becomes

$${\mathbb{P}}(N_{n} = k \mid X_{1},\ldots,X_{n}) = \frac{k\sum_{i = 1}^{n}\mathbf{1}_{\{{X_{i} = k}\}}}{S_{n}} = \frac{k \cdot \frac{1}{n}\sum_{i = 1}^{n}\mathbf{1}_{\{{X_{i} = k}\}}}{\frac{1}{n}\sum_{i = 1}^{n}X_{i}}$$

By the Strong Law of Large Numbers,

$$\frac{1}{n}\sum\limits_{i = 1}^{n}\mathbf{1}_{\{{X_{i} = k}\}}\rightarrow{\mathbb{E}}\lbrack\mathbf{1}_{\{{X_{1} = k}\}}\rbrack = {\mathbb{P}}(X_{1} = k)\quad\text{a.s.}$$

and

$$\frac{1}{n}\sum\limits_{i = 1}^{n}X_{i}\rightarrow{\mathbb{E}}\lbrack X_{1}\rbrack\quad\text{a.s.}$$

Since $0 < {\mathbb{E}}\lbrack X_{1}\rbrack < \infty$, it follows that

$${\mathbb{P}}(N_{n} = k \mid X_{1},\ldots,X_{n})\rightarrow\frac{k{\mathbb{P}}(X_{1} = k)}{{\mathbb{E}}\lbrack X_{1}\rbrack}\quad\text{a.s.}$$

Taking expectations on both sides, and using dominated convergence because $0 \leq {\mathbb{P}}(N_{n} = k \mid X_{1},\ldots,X_{n}) \leq 1$, we obtain

$${\mathbb{P}}(N_{n} = k) = {\mathbb{E}}\ \ {\mathbb{P}}(N_{n} = k \mid X_{1},\ldots,X_{n})\rightarrow\frac{k{\mathbb{P}}(X_{1} = k)}{{\mathbb{E}}\lbrack X_{1}\rbrack}$$

Thus, for every $k \in {\mathbb{N}}$,

$${\mathbb{P}}(N_{n} = k)\rightarrow{\mathbb{P}}(X_{1}^{\ast} = k)$$

Hence

$$N_{n}\overset{d}{\rightarrow}X_{1}^{\ast}$$
:::

# Homework 6

## Problem 1 {#problem-1-6}

Let $X$ be a random variable such that ${\mathbb{E}}\left\lbrack |X| \right\rbrack < \infty$, that is $X \in L^{1}$. Denote by $\phi_{X}(t) := {\mathbb{E}}\left\lbrack e^{itX} \right\rbrack,t \in {\mathbb{R}}$, its characteristic function.

- Show that $\phi_{X}$ is differentiable with $\phi_{X}'(t) = i{\mathbb{E}}\left\lbrack {Xe^{itX}} \right\rbrack$. (Hint: DCT)

- If, in addition, $X$ has symmetric distribution(i.e. $X, - X$ have the same distribution), then show that $\phi_{X}(t) \in {\mathbb{R}}$ for any $t \in {\mathbb{R}}$.

::: proof
**Proof**

- Fix $t \in {\mathbb{R}}$. Consider the difference quotient

  $$\frac{\phi_{X}(t + h) - \phi_{X}(t)}{h} = {\mathbb{E}}\left\lbrack {e^{itX}\frac{e^{ihX} - 1}{h}} \right\rbrack$$

  Notice we have (for a.e. $\omega$):

  $$\lim\limits_{h\rightarrow 0}\frac{e^{ihX} - 1}{h} = iX$$

  Hence

  $$e^{itX}\frac{e^{ihX} - 1}{h}\rightarrow iXe^{itX}\quad\text{a.s.}\quad\text{as}\ h\rightarrow 0$$

  Using the mean value theorem for the function $u\mapsto e^{iuX}$, for $\left. |h \middle| \leq 1 \right.$ we have

  $$\left. \left| \frac{e^{ihX} - 1}{h} \right| \leq \middle| X| \right.$$

  Also, $\left. |e^{itX} \middle| = 1 \right.$, so

  $$\left. \left| {e^{itX}\frac{e^{ihX} - 1}{h}} \right| = \middle| e^{itX} \middle| \left| \frac{e^{ihX} - 1}{h} \right| \leq \middle| X| \right.$$

  Since $X \in L^{1}$, we have $\left. {\mathbb{E}}\lbrack \middle| X \middle| \rbrack < \infty \right.$, therefore $|X|$ is a dominating integrable random variable for $e^{itX}\frac{e^{ihX} - 1}{h}$. Then by DCT,

  $$\lim\limits_{h\rightarrow 0}\frac{\phi_{X}(t + h) - \phi_{X}(t)}{h} = {\mathbb{E}}\left\lbrack {\lim\limits_{h\rightarrow 0}e^{itX}\frac{e^{ihX} - 1}{h}} \right\rbrack = {\mathbb{E}}\lbrack iXe^{itX}\rbrack$$

  Thus $\phi_{X}$ is differentiable and

  $$\phi_{X}'(t) = i{\mathbb{E}}\lbrack Xe^{itX}\rbrack$$

- Since random variables with the same distribution have the same expectation under measurable functions for which the expectation exists, we get

  $$\phi_{X}(t) = {\mathbb{E}}\lbrack e^{itX}\rbrack = {\mathbb{E}}\lbrack e^{it( - X)}\rbrack = {\mathbb{E}}\lbrack e^{- itX}\rbrack = \phi_{X}( - t)$$

  On the other hand since $\phi_{X}( - t) = \bar{\phi_{X}(t)}$, we thus have

  $$\phi_{X}(t) = \bar{\phi_{X}(t)}$$

  A complex number equal to its own conjugate must be real. Therefore,

  $$\phi_{X}(t) \in {\mathbb{R}},\qquad\forall t \in {\mathbb{R}}$$

  Writing

  $$\phi_{X}(t) = {\mathbb{E}}\lbrack\cos(tX)\rbrack + i{\mathbb{E}}\lbrack\sin(tX)\rbrack$$

  Since $X$ is symmetric, $\sin(tx)$ is odd, so

  $${\mathbb{E}}\lbrack\sin(tX)\rbrack = 0$$

  Therefore $\phi_{X}(t) = {\mathbb{E}}\lbrack\cos(tX)\rbrack \in {\mathbb{R}}$.
:::

## Problem 2 {#problem-2-6}

Let $X \sim \text{Bin}(n,p)$, where $n \in {\mathbb{N}},p \in (0,1)$ and $Y \sim \text{Pois}(\lambda)$, where $\lambda > 0$.

- Compute the characteristic functions of $X,Y$.

- Let $\left( p_{n} \right)_{n \in {\mathbb{N}}}$ be a sequence in $(0,1)$ such that $\lim_{n\rightarrow\infty}np_{n} = \lambda$ and $\left( X_{n} \right)_{n \in {\mathbb{N}}}$ be a sequence of random variables with $X_{n} \sim \text{Bin}\ \left( {n,p_{n}} \right)$. Show that $X_{n}\overset{d}{\rightarrow}Y$.

::: proof
**Proof**

- We have

  $${\mathbb{P}}(X = k) = \left( \frac{n}{k} \right)p^{k}(1 - p)^{n - k},\quad k = 0,1,\ldots,n$$

  Therefore,

  $$\phi_{X}(t) = {\mathbb{E}}\lbrack e^{itX}\rbrack = \sum\limits_{k = 0}^{n}e^{itk}\left( \frac{n}{k} \right)p^{k}(1 - p)^{n - k}$$

  We factor $e^{itk}$ into $(pe^{it})^{k}/p^{k}$ and obtain

  $$\phi_{X}(t) = \sum\limits_{k = 0}^{n}\left( \frac{n}{k} \right)(pe^{it})^{k}(1 - p)^{n - k}$$

  By the binomial formula,

  $$\phi_{X}(t) = (1 - p + pe^{it})^{n}$$

  Next for $Y \sim \text{Pois}(\lambda)$ we have

  $${\mathbb{P}}(Y = k) = e^{- \lambda}\frac{\lambda^{k}}{k!},\quad k = 0,1,2,\ldots$$

  Hence

  $$\phi_{Y}(t) = {\mathbb{E}}\lbrack e^{itY}\rbrack = \sum\limits_{k = 0}^{\infty}e^{itk}e^{- \lambda}\frac{\lambda^{k}}{k!}$$

  Thus

  $$\phi_{Y}(t) = e^{- \lambda}\sum\limits_{k = 0}^{\infty}\frac{(\lambda e^{it})^{k}}{k!} = e^{- \lambda}e^{\lambda e^{it}} = e^{\lambda(e^{it} - 1)}$$

  So the characteristic functions are

  $$\phi_{X}(t) = (1 - p + pe^{it})^{n},\quad\phi_{Y}(t) = e^{\lambda(e^{it} - 1)}$$

- By part (a),

  $$\phi_{X_{n}}(t) = (1 - p_{n} + p_{n}e^{it})^{n} = \left( {1 + p_{n}(e^{it} - 1)} \right)^{n}$$

  We now compute the limit as $n\rightarrow\infty$.

  Set

  $$a_{n} := p_{n}(e^{it} - 1)$$

  Since $p_{n}\rightarrow 0$ (as $np_{n}\rightarrow\lambda < \infty$), we have $a_{n}\rightarrow 0$. Therefore,

  $$\log(1 + a_{n})\rightarrow a_{n},\quad n\rightarrow\infty$$

  Hence

  $$n\log(1 + a_{n})\rightarrow na_{n} = np_{n}(e^{it} - 1)\Longrightarrow\lambda(e^{it} - 1)$$

  Exponentiating, we get

  $$\phi_{X_{n}}(t) = \exp\ n\log(1 + a_{n})\rightarrow\exp\ \lambda(e^{it} - 1)$$

  But by part (a),

  $$\exp\ \lambda(e^{it} - 1) = \phi_{Y}(t)$$

  Thus for every $t \in {\mathbb{R}}$,

  $$\phi_{X_{n}}(t)\rightarrow\phi_{Y}(t)$$

  Since $\phi_{Y}$ is the characteristic function of $Y \sim \text{Pois}(\lambda)$, by the uniqueness theorem for characteristic functions, this implies

  $$X_{n}\overset{d}{\rightarrow}Y$$
:::

## Problem 3 {#problem-3-6}

Show that

$$\lim\limits_{n\rightarrow\infty}\int_{0}^{n/2}\frac{2^{n}}{(n - 1)!}t^{n - 1}e^{- 2t}dt = \frac{1}{2}$$

Hint: Observe that the integral is the probability of an event related to a Gamma distribution. Can we apply the central limit theorem?

::: proof
**Proof**

Let

$$I_{n} := \int_{0}^{n/2}\frac{2^{n}}{(n - 1)!}t^{n - 1}e^{- 2t}\, dt$$

Then

$$f_{n}(t) = \frac{2^{n}}{(n - 1)!}t^{n - 1}e^{- 2t}\mathbf{1}_{(0,\infty)}(t)$$

is the density of a Gamma distribution with parameters $(n,2)$, that is, $T_{n} \sim \Gamma(n,2)$. Hence

$$I_{n} = {\mathbb{P}}(T_{n} \leq n/2)$$

Now let $X_{1},X_{2},\ldots$ be i.i.d. random variables with

$$X_{i} \sim \text{Exp}(2)$$

We know that

$$T_{n} = X_{1} + \cdots + X_{n}$$

Also,

$$\mu := {\mathbb{E}}\lbrack X_{1}\rbrack = \frac{1}{2},\quad\sigma^{2} := \text{Var}(X_{1}) = \frac{1}{4}$$

Therefore,

$$I_{n} = {\mathbb{P}}(X_{1} + \cdots + X_{n} \leq n/2) = {\mathbb{P}}\mspace{-18mu}\left( {\frac{T_{n} - n\mu}{\sigma\sqrt{n}} \leq 0} \right)$$

Since $\mu = 1/2$ and $\sigma = 1/2$, this is

$$I_{n} = {\mathbb{P}}\mspace{-18mu}\left( {\frac{T_{n} - n/2}{\sqrt{n}/2} \leq 0} \right)$$

By the Central Limit Theorem,

$$\frac{T_{n} - n\mu}{\sigma\sqrt{n}} = \frac{T_{n} - n/2}{\sqrt{n}/2}\overset{d}{\rightarrow}Z,\quad Z \sim N(0,1)$$

Hence, since the standard normal distribution function is continuous at $0$,

$$\lim\limits_{n\rightarrow\infty}I_{n} = \lim\limits_{n\rightarrow\infty}{\mathbb{P}}\mspace{-18mu}\left( {\frac{T_{n} - n/2}{\sqrt{n}/2} \leq 0} \right) = {\mathbb{P}}(Z \leq 0) = \frac{1}{2}$$

Thus

$$\lim\limits_{n\rightarrow\infty}\int_{0}^{n/2}\frac{2^{n}}{(n - 1)!}t^{n - 1}e^{- 2t}dt = \frac{1}{2}$$
:::

## Problem 4 {#problem-4-6}

A casino offers the following random game: A player rolls a fair die once. If the outcome is 2 or 4, then the player wins 3 euros from the casino. If the outcome is $1,3,5$, then the player loses 4 euros to the casino. If the outcome is 6 , then the player neither wins nor loses. If 90 players play the above game independently, find approximately the probability that the casino wins at least 30 euros in total.

::: solution
**Solution**

Let $X_{i}$ be the gain of the casino from the $i$-th player, for $i = 1,\ldots,90$. Then the random variables $X_{1},\ldots,X_{90}$ are independent and identically distributed, with

$$X_{i} = \left\{ \begin{matrix}
{- 3,} & \text{if the player wins 3 euros} \\
{4,} & \text{if the player loses 4 euros} \\
{0,} & \text{if the outcome is 6}
\end{matrix} \right.$$

Since the die is fair, we have

$${\mathbb{P}}(X_{i} = - 3) = \frac{2}{6} = \frac{1}{3},\qquad{\mathbb{P}}(X_{i} = 4) = \frac{3}{6} = \frac{1}{2},\qquad{\mathbb{P}}(X_{i} = 0) = \frac{1}{6}$$

Let

$$S_{90} = X_{1} + \cdots + X_{90}$$

be the total gain of the casino after 90 players. We want to approximate

$${\mathbb{P}}(S_{90} \geq 30)$$

We first compute the mean and variance of $X_{1}$. The mean is

$$\mu := {\mathbb{E}}\lbrack X_{1}\rbrack = ( - 3) \cdot \frac{1}{3} + 4 \cdot \frac{1}{2} + 0 \cdot \frac{1}{6} = - 1 + 2 = 1$$

Also,

$${\mathbb{E}}\lbrack X_{1}^{2}\rbrack = 9 \cdot \frac{1}{3} + 16 \cdot \frac{1}{2} + 0 = 3 + 8 = 11$$

Hence

$$\sigma^{2} := \text{Var}(X_{1}) = {\mathbb{E}}\lbrack X_{1}^{2}\rbrack - \mu^{2} = 11 - 1 = 10$$

Therefore,

$${\mathbb{E}}\lbrack S_{90}\rbrack = 90\mu = 90,\quad\text{Var}(S_{90}) = 90\sigma^{2} = 900$$

So the standard deviation of $S_{90}$ is

$$\sqrt{900} = 30$$

By the Central Limit Theorem,

$$\frac{S_{90} - 90}{30} \approx N(0,1)$$

Thus,

$${\mathbb{P}}(S_{90} \geq 30) = {\mathbb{P}}\left( {\frac{S_{90} - 90}{30} \geq \frac{30 - 90}{30}} \right) \approx {\mathbb{P}}(Z \geq - 2)$$

where $Z \sim N(0,1)$. Since

$${\mathbb{P}}(Z \geq - 2) = {\mathbb{P}}(Z \leq 2) \approx 0.9772$$

we conclude that

$${\mathbb{P}}(S_{90} \geq 30) \approx 0.9772$$

Hence, the probability that the casino wins at least 30 euros in total is approximately 0.9772.
:::

## Problem 5 {#problem-5-6}

Assume that $\left( X_{n} \right)_{n \in {\mathbb{N}}}$ is an i.i.d. sequence of random variables such that ${\mathbb{E}}\left\lbrack X_{1} \right\rbrack = 0$ and ${\mathbb{E}}\left\lbrack X_{1}^{2} \right\rbrack = 1$. Show that

$$\frac{\sum_{i = 1}^{n}X_{i}}{\sqrt{\sum_{i = 1}^{n}X_{i}^{2}}}\overset{d}{\rightarrow}Z,\quad Z \sim N(0,1)$$

::: proof
**Proof**

Let

$$S_{n} := \sum\limits_{i = 1}^{n}X_{i},\quad Q_{n} := \sum\limits_{i = 1}^{n}X_{i}^{2}$$

We want to show that

$$\frac{S_{n}}{\sqrt{Q_{n}}}\overset{d}{\rightarrow}Z,\quad Z \sim N(0,1)$$

First, since $(X_{n})_{n \in {\mathbb{N}}}$ are i.i.d. with ${\mathbb{E}}\lbrack X_{1}\rbrack = 0,$ and ${\mathbb{E}}\lbrack X_{1}^{2}\rbrack = 1$, we have $\text{Var}(X_{1}) = 1$. And thus by the Central Limit Theorem,

$$\frac{S_{n}}{\sqrt{n}}\overset{d}{\rightarrow}Z,\quad Z \sim N(0,1)$$

And then, consider $Q_{n}$. Since $(X_{i}^{2})$ are i.i.d. and ${\mathbb{E}}\lbrack X_{1}^{2}\rbrack = 1 < \infty$, by the Law of Large Numbers we have

$$\frac{Q_{n}}{n}\overset{P}{\rightarrow}1$$

By continuity of the square root function,

$$\sqrt{\frac{Q_{n}}{n}}\overset{P}{\rightarrow}1$$

Write

$$\frac{S_{n}}{\sqrt{Q_{n}}} = \frac{S_{n}}{\sqrt{n}} \cdot \frac{1}{\sqrt{Q_{n}/n}}$$

Define

$$A_{n} := \frac{S_{n}}{\sqrt{n}},\quad B_{n} := \frac{1}{\sqrt{Q_{n}/n}}$$

Then we have shown that $A_{n}\overset{d}{\rightarrow}Z$ and $B_{n}\overset{P}{\rightarrow}1$.

**Now we claim that: $A_{n}B_{n}\overset{d}{\rightarrow}Z$.**

It suffices to show that ${\mathbb{E}}\lbrack f(A_{n}B_{n})\rbrack\rightarrow{\mathbb{E}}\lbrack f(Z)\rbrack$ for every bounded continuous function $f:{\mathbb{R}}\rightarrow{\mathbb{R}}$.

Let $f:{\mathbb{R}}\rightarrow{\mathbb{R}}$ be bounded and continuous. Then

$${\mathbb{E}}\lbrack f(A_{n}B_{n})\rbrack - {\mathbb{E}}\lbrack f(Z)\rbrack = \ {\mathbb{E}}\lbrack f(A_{n}B_{n})\rbrack - {\mathbb{E}}\lbrack f(A_{n})\rbrack + \ {\mathbb{E}}\lbrack f(A_{n})\rbrack - {\mathbb{E}}\lbrack f(Z)\rbrack$$

Since $A_{n}\overset{d}{\rightarrow}Z$, the second term converges to $0$. It remains to show that ${\mathbb{E}}\lbrack f(A_{n}B_{n})\rbrack - {\mathbb{E}}\lbrack f(A_{n})\rbrack\rightarrow 0$.

Observe $A_{n}B_{n} - A_{n} = A_{n}(B_{n} - 1)$. Because $A_{n}\overset{d}{\rightarrow}Z$, the sequence $(A_{n})$ is tight. Also, since $B_{n}\overset{P}{\rightarrow}1$, we have

$$B_{n} - 1\overset{P}{\rightarrow}0$$

It follows that

$$A_{n}(B_{n} - 1) = A_{n}B_{n} - A_{n}\overset{P}{\rightarrow}0$$

We now show that

$$f(A_{n}B_{n}) - f(A_{n})\overset{P}{\rightarrow}0$$

Fix $\varepsilon > 0$. Since $(A_{n})$ is tight, there exists $M > 0$ such that

$$\left. \sup\limits_{n \geq 1}{\mathbb{P}}( \middle| A_{n} \middle| > M) < \varepsilon \right.$$

Since $f$ is continuous on the compact interval $\lbrack - M - 1,M + 1\rbrack$, it is uniformly continuous there. Thus there exists $\delta > 0$ such that whenever $x,y \in \lbrack - M - 1,M + 1\rbrack$ and $\left. |x - y \middle| < \delta \right.$, we have

$$\left. |f(x) - f(y) \middle| < \varepsilon \right.$$

Now on the event

$$\left\{ |A_{n} \middle| \leq M,\  \middle| A_{n}B_{n} - A_{n} \middle| < \min(\delta,1) \right\}$$

we also have $\left. |A_{n}B_{n} \middle| \leq M + 1 \right.$, so

$$\left. |f(A_{n}B_{n}) - f(A_{n}) \middle| < \varepsilon \right.$$

Therefore,

$$\left. {\mathbb{P}}\  \middle| f(A_{n}B_{n}) - f(A_{n}) \middle| > \varepsilon\  \leq {\mathbb{P}}( \middle| A_{n} \middle| > M) + {\mathbb{P}}( \middle| A_{n}B_{n} - A_{n} \middle| \geq \min(\delta,1)) \right.$$

The first term is less than $\varepsilon$, and the second term tends to $0$. Hence

$$f(A_{n}B_{n}) - f(A_{n})\overset{P}{\rightarrow}0$$

Since $f$ is bounded, the random variables $f(A_{n}B_{n}) - f(A_{n})$ are uniformly bounded. Therefore,

$${\mathbb{E}}\lbrack f(A_{n}B_{n}) - f(A_{n})\rbrack\rightarrow 0$$

Combining this with ${\mathbb{E}}\lbrack f(A_{n})\rbrack\rightarrow{\mathbb{E}}\lbrack f(Z)\rbrack$, we get

$${\mathbb{E}}\lbrack f(A_{n}B_{n})\rbrack\rightarrow{\mathbb{E}}\lbrack f(Z)\rbrack$$

Thus

$$A_{n}B_{n}\overset{d}{\rightarrow}Z$$

This finishes the proof that

$$\frac{S_{n}}{\sqrt{Q_{n}}} = A_{n}B_{n}\overset{d}{\rightarrow}Z$$

That is,

$$\frac{\sum_{i = 1}^{n}X_{i}}{\sqrt{\sum_{i = 1}^{n}X_{i}^{2}}}\overset{d}{\rightarrow}Z,\quad Z \sim N(0,1)$$
:::
