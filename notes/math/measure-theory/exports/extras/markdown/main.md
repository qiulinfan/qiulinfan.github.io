---
author:
- Qiulin Fan
authority: typst
bibliography:
- reference.bib
course: MATH 597
date: Winter 2025
description: Supplementary Measure Theory material not enabled in the legacy main.tex.
keywords:
- measure theory
- problem solving
- practice problems
lang: zh-CN
qlnotes-schema: qlnotes-v1
semantic-node-count: 7
source: extras.typ
subtitle: Homework 0, problem-solving lectures, and practice problems
title: "MATH 597: Measure Theory --- Supplementary Material"
---

# hw 0

(Not graded.) Read Sections 0.1-0.3 and 0.5-0.6 in Folland's book. Note: I expect you to have seen much but not necessarily all of this material in earlier courses. It is not necessary to know everything by heart right now. However, in order to succeed in the class, you need to be able to read mathematical material at this level of abstraction and (lack of) detail.

## Approaching 597

Let $A$ be an infinite (not necessarily countable) set, and $f:A\rightarrow{\mathbb{R}}$ a function. Suppose that for every integer $N \geq 1$ there exist finite subsets $A_{N}^{+} \subset A$ and $A_{N}^{-} \subset A$ such that:

- \(i\) $\left. |f(\alpha) \middle| \leq N^{- 1} \right.$ for all $\alpha \in A\backslash(A_{N}^{+} \cup A_{N}^{-})$;

- \(ii\) $\sum_{\alpha \in A_{N}^{+}}f(\alpha) \geq N$;

- \(iii\) $\sum_{\alpha \in A_{N}^{-}}f(\alpha) \leq - N$.

Prove that for any $N \geq 1$, there exists a finite subset $B_{N} \subset A$ such that

$$\left| {597 - \sum\limits_{\alpha \in B_{N}}f(\alpha)} \right| \leq \frac{1}{N}.$$

::: proof
**Proof**

We first take $A_{N} = A_{N}^{+}\bigcup A_{N}^{-} \subset A$ s.t. $\left. |f(\alpha) \middle| \leq N^{- 1} \right.$ for all $\alpha \in A\backslash A_{N}$, as given by the conditions.\
Now we define $pos(A_{N}) := \left\{ {\alpha \in A_{N} \mid f(\alpha) \geq 0} \right\}$ and $neg(A_{N}) := \left\{ {\alpha \in A_{N} \mid f(\alpha) < 0} \right\}$.\
Let $gap := \sum_{\alpha \in A_{N}}f(\alpha) - 597$. This is a real number since $A_{N}$ is finite.\
\
Case 1: if $gap < 0$, then we need to fill in more elements whose image under $f$ sum up to be positive to make the sum close to 597 from below.\
We then take a finite set $B_{N}^{+} \subset A$ s.t. $\sum_{\alpha \in B_{N}^{+}}f(\alpha) \geq \lceil - gap + \sum_{\alpha \in pos(A_{N})}f(\alpha)\rceil$.\
Since $B_{N}^{+}\bigcap A_{N} \subset A_{N}$, we have

$$\sum\limits_{\alpha \in B_{N}^{+}\bigcap A_{N}}f(\alpha) \leq \sum\limits_{\alpha \in pos(A_{N})}f(\alpha)$$

and since $B_{N}^{+} = (B_{N}^{+}\backslash A_{N})\coprod(B_{N}^{+}\bigcap A_{N})$, we have

$$\sum\limits_{\alpha \in B_{N}^{+}}f(\alpha) = \sum\limits_{\alpha \in B_{N}^{+}\backslash A_{N}}f(\alpha) + \sum\limits_{\alpha \in B_{N}^{+}\bigcap A_{N}}f(\alpha)$$

By (1) and (2), it is clear that

$$\sum\limits_{\alpha \in B_{N}^{+}\backslash A_{N}}f(\alpha) \geq - gap$$

\(3\) means that the elements in $B_{N}^{+}\backslash A_{N}$ have big enough image sum to fill the gap. And by definition, for all $\alpha \in B_{N}^{+}\backslash A_{N}$, we have $\left. |f(\alpha) \middle| \leq \frac{1}{N} \right.$. This means that each element in this finite $B_{N}^{+}\backslash A_{N}$ takes up only a small portion of the sum, bounded by $1/N$. Together with (3), it follows that there is some subset $B_{N}' \subset B_{N}^{+}\backslash A_{N}$ s.t. $\sum_{\alpha \in B_{N}'}f(\alpha) \in \lbrack - gap - 1/N, - gap + 1/N\rbrack$. So for the finite set $A_{N}\bigcup B_{N}'$, we have

$$\sum\limits_{\alpha \in A_{N}\bigcup B_{N}'}f(\alpha) = \sum\limits_{\alpha \in A_{N}}f(\alpha) + \sum\limits_{\alpha \in B_{N}'}f(\alpha) \in \lbrack 597 - 1/N,597 + 1/N\rbrack$$

![Figure 1:[ ]{style="white-space: pre-wrap"}](main.assets/figure-raster-001.png){width="30%"}

Case 2: if $gap > 0$, then we need to fill in more elements whose image under $f$ sum up to be negative to make the sum close to 597 from above.\
We then take finite $B_{N}^{-} \subset A$ s.t. $\sum_{\alpha \in B_{N}^{-}}f(\alpha) \leq \lfloor - gap + \sum_{\alpha \in neg(A_{N})}f(\alpha)\rceil$.\
For the same reason as case 1, we get

$$\sum\limits_{\alpha \in B_{N}^{-}\backslash A_{N}}f(\alpha) \leq - gap$$

And by definition, for all $\alpha \in B_{N}^{-}\backslash A_{N}$, we have $\left. |f(\alpha) \middle| \leq \frac{1}{N} \right.$. Together with (5), it follows that there is some subset $B_{N}' \subset B_{N}^{-}\backslash A_{N}$ s.t. $\sum_{\alpha \in B_{N}'}f(\alpha) \in \lbrack - gap - 1/N, - gap + 1/N\rbrack$. So for the finite set $A_{N}\bigcup B_{N}'$, we have

$$\sum\limits_{\alpha \in A_{N}\bigcup B_{N}'}f(\alpha) = \sum\limits_{\alpha \in A_{N}}f(\alpha) + \sum\limits_{\alpha \in B_{N}'}f(\alpha) \in \lbrack 597 - 1/N,597 + 1/N\rbrack$$

\
Case 3: $gap = 0$, then we are done.\
This finishes the proof of the statement.
:::

::: remark
**Remark**

意思是说 $f$ 对于任意小的 bound 都存在一个 infinite set 上能够限于这一 bound 内(可逼近 0), 而在一个 finite set 上总和可以任意大. 要证明的是对于任意一个数, 我们都可以指定一个 finite set, 让这个函数在这个 finite set 上的总和无限接近这个数. 这里以 597 为例. 对于这个 bounded 的 infinite set, 我们简称它为 big flat set, 其补集称之为 small wavy set.\
\
这题思考甚久. 一开始卡住的原因就是局限于这个 big flat set 的 sum postive 和 sum negative 这两个划分上, 因为这占了条件中很大一部分笔墨. 但是最后却发现实际上这个集合在第一步构造中并没有用, 甚至作用一直都不大, 只用一边即可. 并且, 这两个条件不仅是透明条件, 而且我们甚至应该构建自己的 \"all positive\" 和 \"all negative\" set.\
\
为什么说这个 sum postive 和 sum negative 划分几乎没用: 因为它基本不给出任何 invariant 的信息. 举例: sum postive set 的 image sum $\geq 100$, sum negative set 的 image sum $\leq - 100$, 它们交的部分, 其可能的 image sum 上下都可以 unboundly large, 可以是 99999, 唯一能 imply 的信息是两边 $A_{N} + \backslash A_{N}^{-}$ 和 $A_{N} - \backslash A_{N}^{+}$ 之间的差距大于等于 200, 但是这也没用, 因为我们对元素个数也没有 control over.因而我们想要准确地逼近一个数, 必须要靠外界的大小全都 singly bounded 的元素.\
\
于是关键的解题点在于: small wavy set 的有限性, 所以我们可以把它的值设做 $gap$, 并可以把它分为全正和全负的两个 portion. 这样的目的是: 我们等于给 $\mathcal{P}(A)$ 中每个集合赋予了一个 measure, 等于 image sum under $f$, 而局限在 small wavy set 上, 这个 measure 最小的集合就是 all negative set, 最大的集合就是 all positive set. 从而, 我们先比较 $gap$ 和 597 的大小, 根据其正负, 制定一个 (差值 $\pm$ allPos/Neg set 的 function measure) 的 bound, 并创造第二个 big wavy set $B_{N}$. 这个 $B_{N}$ 和 $A_{N}$ 可能相交, 但是这一次, 我们可以 control over $B_{N}\backslash A_{N}$ 的部分, 因为这部分的值必须大于 $gap$ 和 597 的差值, 并且这个部分还属于 $A_{N}$ 外的 big flat set, 其中每个元素的函数值都是 bounded by a small number 的.
:::

## Limsup and Liminf

Let $X$ be a nonempty set, and $A,B$ subsets of $X$. Define a sequence $(E_{n})_{n = 1}^{\infty}$ of subsets of $X$ by

$$E_{n} = \left\{ \begin{matrix}
{A\ } & {\text{if}\ n\ \text{is a prime number,}} \\
{B\ } & \text{otherwise.}
\end{matrix} \right.$$

Characterize the sets $\operatorname{lim\, sup}E_{n}$ and $\operatorname{lim\, inf}E_{n}$ (see §0.1 in Folland for notation).

::: solution
**Solution**

By definition,

$$\operatorname{lim\, sup}(E_{n}) = \bigcap\limits_{k = 1}^{\infty}\bigcup\limits_{n = k}^{\infty}E_{n}$$

For each $k \in {\mathbb{N}}$, there are infinitely many $n \geq k$ such that $n$ is prime, and also there are infinitely many $n \geq k$ such that $n$ is not prime. So $\bigcup_{n = k}^{\infty}E_{n} = A\bigcup B$. Therefore

$$\operatorname{lim\, sup}(E_{n}) = \bigcap\limits_{k = 1}^{\infty}(A\bigcup B) = A\bigcup B$$

By definition,

$$\operatorname{lim\, inf}(E_{n}) = \bigcup\limits_{k = 1}^{\infty}\bigcap\limits_{n = k}^{\infty}E_{n}$$

For each $k \in {\mathbb{N}}$, there are infinitely many $n \geq k$ such that $n$ is prime, and also there are infinitely many $n \geq k$ such that $n$ is not prime. So $\bigcap_{n = k}^{\infty}E_{n} = A\bigcap B$. Therefore

$$\operatorname{lim\, inf}(E_{n}) = \bigcup\limits_{k = 1}^{\infty}(A\bigcap B) = A\bigcap B$$
:::

## Polynomial Convergence

Let $f:{\mathbb{Z}}_{\geq 0} \times {\mathbb{Z}}_{\geq 0}\rightarrow{\mathbb{R}}$ be a function with the property that for every polynomial

$$p(x) = x^{d} + a_{1}x^{d - 1} + \cdots + a_{d}$$

with integer coefficients, we have that

$$\lim\limits_{n\rightarrow\infty}f(n,p(n)) = \lim\limits_{n\rightarrow\infty}f(p(n),n) = 0.$$

Does it follow that $f(m,n)\rightarrow 0$ as $m,n\rightarrow\infty$? In other words, given $\epsilon > 0$, does there exist $N \geq 0$ such that $\left. |f(m,n) \middle| < \epsilon \right.$ whenever $\left. |m \middle| , \middle| n \middle| \geq N \right.$? Give a proof or a counterexample.

::: solution
**Solution**

Consider this function:

$$\begin{matrix}
{f(m,n) = \{ 1,\text{if}\ m = 2^{n}} \\
{0,\text{otherwise}}
\end{matrix}$$

Let **$p$ be arbitrary polynomial with integer coefficients.** Then there must be at most finite $n$ such that $p(n) = 2^{n}$. This is guaranteed by the asymptotic behavior of polynomial and exponential function: $\lim_{n\rightarrow\infty}\frac{p(n)}{2^{n}} = 0$. So there exists some $N \in {\mathbb{N}}$ s.t. $\frac{p(n)}{2^{n}} < 1/2$ for all $n \geq N$, therefore **$f(p(n),n)$ is eventually 0**.\
Also, there must be at most finite $n$ such that $2^{p(n)} = n$, i.e. $p(n) = \log_{2}n$. This is guaranteed by the asymptotic behavior of polynomial and logarithmic function: $\lim_{n\rightarrow\infty}\frac{\log_{2}n}{p(n)} = 0$. So there exists some $N \in {\mathbb{N}}$ s.t. $\frac{\log_{2}n}{p(n)} < 1/2$ for all $n \geq N$, therefore **$f(n,p(n))$ is eventually 0**.\
This confirms that $\lim_{n\rightarrow\infty}f(n,p(n)) = \lim_{n\rightarrow\infty}f(p(n),n) = 0$ for any polynomial $p$ with integer coefficients.\
Then we consider the sequence $((2^{n},n))_{n \in {\mathbb{N}}}$. For any $n \in {\mathbb{N}}$, $f((2^{n},n)) = 1$, so the sequential limit is $1$. This completes the counterexample.

![Figure 2:[ ]{style="white-space: pre-wrap"}](main.assets/figure-raster-002.jpg){width="30%"}
:::

::: remark
**Remark**

$f$ 是一个二元 input 的函数, 其满足, 将任何一个 polynomial 函数的 graph input 进入, limit behavior 都会趋近于 0.\
这个表现乍看很雾. 所以不如试一试: identity polynomial 和 trivial polynomial. 得到 $\lim_{n\rightarrow\infty}f(1,n) = \lim_{n\rightarrow\infty}f(n,1) = 0$, 以及 $\lim_{n\rightarrow\infty}f(n,n) = 0$, 以及可想折中的情况: 这两个 input 的增长速度是 polynoimial relation 的情况下(一个是 $n$, 一个是 $p(n)$)也是趋近于 0 的, 这个表现像是这个函数在两个 input 各自以任意速度增长时 converge to 0.\
\
但是直觉告诉我们这个 polynomial 关系的增长速度不能代表增长速度差距更大的情况, 比如 exponential.遂想到解题点: 这个 limit behavior, 针对的是任意 polynomial, 但是是随意选择一个固定的 polynomial 之后, 才在这个固定的 polynomial 上有这个行为.\
\
Then we think about: 一个在 exponential graph as input 上一直得到固定值, 在其他 input 上都得到 0 的函数. 从而对于这个 exponential graph input 的 seq, 函数的 limit behavior 是一个固定值; 而对于任意的 polynomial, 函数的 limit behavior 都是 0，因为任意 polynomial 函数, 和一个 exponential 函数至多有有限个重合点, asymptotic 增长速度不同.\
\
(PS: 笔者在思考构造时想到过一个很 silly 的问题: 对于任意两个整数 $x,y$，是否都存在一个无常数项的整系数 polynomial 使得 $p(x) = y$? 答:很显然不是. 回忆小学数学: 我们只要选择和 $x$ 没有 common factor 的 $y$ 即可得反.)
:::

# Problem solving

Recall: Given mspace $(X,\mathcal{A},\mu)$ 以及 $f:X\rightarrow{\mathbb{C}}$ mble, 我们可以 define distribution function:

$$\lambda_{f}:(0,\infty)\rightarrow\lbrack 0,\infty\rbrack$$

by

$$\lambda_{f}(\alpha) = \mu(\left\{ |f \middle| > \alpha \right\})$$

Chebyshevs ineq:

$$\lambda_{f}(\alpha) \leq (\frac{\parallel f\underset{p}{\parallel}}{\alpha})^{p}$$

for $0 < p < \infty$.\
Today: Problem Solving

::: {#prop-lec36-problem-solving-proposition-001 .proposition concepts="proposition-001"}
**Proposition**

对于任意 $0 < p < \infty$, 我们有:

$$\left. \int_{X} \middle| f \middle| {}_{p}\, d\mu = \int_{0}^{\infty}p\alpha^{p - 1}\lambda_{f}(\alpha)\, d\alpha \right.$$
:::

左边是 integral on $X$, 右边是 integral on $\mathbb{R}$.

::: proof
**Proof**

Sketch: Step 1: $f$ simple $\Longrightarrow$ $|f|$ simple.\
:::

Write

$$\left. |f \middle| = \sum\limits_{j = 1}^{N}c_{j}\chi_{A_{j}} \right.$$

where $A_{j}$ disjoint, $c_{1} > c_{2} > \cdots > c_{N} > 0$ This implies:

$$\left. \int \middle| f \middle| {}_{p}\, d\mu = \sum\limits_{j = 1}^{N}c_{j}^{p}r_{j},\quad r_{j} = \mu(A_{j}) \right.$$

Then

$$\lambda_{f}(\alpha) = \left\{ \begin{matrix}
{\sum_{j = 1}^{N}r_{j},} & {0 < \alpha < c_{N}} \\
{\sum_{j = 1}^{n - 1}r_{j},} & {c_{n} \leq \alpha < c_{n - 1},2 \leq n \leq N} \\
{0,} & {\alpha \geq c_{1}}
\end{matrix} \right.$$

从而

$$\begin{matrix}
{\int_{0}^{\infty}p\alpha^{p - 1}\lambda_{f}(\alpha)d\alpha} & {= (\sum\limits_{j = 1}^{N}r_{j})\int_{0}^{c_{N}}p\alpha^{p - 1}d\alpha + \sum\limits_{n = 2}^{N}(\sum\limits_{j = 1}^{n - 1}r_{j})\int_{c_{n}}^{c_{n - 1}}p\alpha^{p - 1}\, d\alpha} \\
 & =
\end{matrix}$$

Step 2: $f$ general.\
Use: $\exists$ simple functions $g_{n} \geq 0$ s.t. $\left. g_{n}\operatorname{\nearrow ︎} \middle| f| \right.$.\
MCT $\Longrightarrow$

$$\left. \int_{X} \middle| f \middle| {}_{p}\, d\mu = \lim\limits_{n\rightarrow\infty}\int_{X}g_{n}^{p}\, d\mu \right.$$

Also,

$$\lambda_{g_{n}}\operatorname{\nearrow ︎}\limits^{\text{CFB}}\lambda_{f}\quad\text{pointwisely on}(0,\infty)$$

从而 MCT $\Longrightarrow$

$$\lim\limits_{n\rightarrow\infty}\int_{0}^{\infty}p\alpha^{p - 1}\lambda_{g_{n}}(\alpha)\, d\alpha\rightarrow\int_{0}^{\infty}p\alpha^{p - 1}\lambda_{f}(\alpha)\, d\alpha$$

$\lambda_{f}(\alpha) = \mu(\left\{ |f \middle| > \alpha \right\})$, 以及 $\left\{ |f \middle| > \alpha \right\} = \bigcup_{1}^{\infty}\left\{ {g_{n} > \alpha} \right\}$ increasing union.

::: {#ex-lec36-problem-solving-example-001 .example concepts="example-001"}
**Example**

Let $f:\lbrack 0,1\rbrack\rightarrow{\mathbb{R}}$ be abs ctn. Suppose $f(0) = 0$ 以及 $f^{1} \in L^{2}(\lbrack 0,1\rbrack)$.\
Show that the limit

$$\lim\limits_{x\rightarrow 0^{+}}x^{- 1/2}f(x)$$

exists, 并 compute it.\
What could the limit be? Must be $0$.\
:::

::: solution
**Solution**

Use FTOC, can recover $f$ from $f'$.\

$$f(x) = f(0) + \int_{0}^{x}f'(t)\, dt,\quad 0 \leq x \leq 1$$

使用 Hölder with $p = q = 2$ (Cauchy-Swartz):

$$\left. |f(x) \middle| \leq \int_{0}^{x} \middle| f'(t) \middle| \, dt = \int_{0}^{x} \middle| f'(t) \middle| 1\, dt \leq (\int_{0}^{x} \middle| f'(t) \middle| {}_{2})^{\frac{1}{2}}x^{\frac{1}{2}} \right.$$

从而

$$\left. x^{- 1/2} \middle| f(x) \middle| \leq \int_{0}^{x} \middle| f'(t) \middle| {}_{2}\, dt \right.$$

Use fact: $g = L^{1}(X,\mathcal{A},\mu)\Longrightarrow\forall\epsilon > 0,\exists\delta > 0$ s.t. for all $\mu(E) < \delta$ we have $\left. \int_{E} \middle| g \middle| \, d\mu < \epsilon \right.$.\
(Proof of this fact: use approx by simple functions 可得).\
然后 use approx by simple functions, apply to $\left. g = \middle| f'|^{2} \right.$, $\mu = m$, $E = \lbrack 0,x\rbrack$, 于是得到

$$\left. \int_{0}^{x} \middle| f'(t) \middle| {}_{2}dt\overset{x\rightarrow 0}{\rightarrow}0 \right.$$
:::

::: {#ex-lec36-problem-solving-example-002 .example concepts="example-002"}
**Example**

Let $f:{\mathbb{R}}^{n}\rightarrow{\mathbb{R}}$ be a function.\
Assume: 对于 $\forall\epsilon > 0$, 都存在 Lebesgue mble functions $g,h \in L^{1}(m)$ s.t.

$$g(x) \leq f(x) \leq h(x)\quad\forall x \in {\mathbb{R}}^{n}$$

并且

$$\int_{{\mathbb{R}}^{n}}(h - g)\, dm < \epsilon$$

Prove that: $f$ 也是 Lebesgue mble 的, 并且 $f \in L^{1}(m)$.\
:::

::: proof
**Proof**

By assumption: Given $k \in {\mathbb{N}}$, 存在 $g_{k},h_{k} \in L^{1}({\mathbb{R}}^{n})$ s.t.

$$g_{k} \leq f \leq h_{k},\quad\int(h_{k} - g_{k}) < \frac{1}{k}$$

Idea: $f = \operatorname{lim\, sup}g_{k} = \operatorname{lim\, inf}h_{k}$ ?\
我们应该 try to prove: for a.e. $x$ 都有 $0 \leq h_{k}(x) - g_{k}(x)\rightarrow 0$.\
Use Fatou's Lemma:

$$\int\operatorname{lim\, inf}\limits_{k\rightarrow\infty}(h_{k} - g_{k}) \leq \operatorname{lim\, inf}\limits_{k\rightarrow\infty}\int(h_{k} - g_{k}) = 0$$

而 $h_{k} - g_{k} \geq 0$, 因而 This means:

$$\operatorname{lim\, inf}\limits_{k\rightarrow\infty}(h_{k} - g_{k}) = 0\quad\text{for a.e.}\ x$$

且我们知道

$$\operatorname{lim\, inf}\limits_{k\rightarrow\infty}(h_{k} - f) \leq \operatorname{lim\, inf}\limits_{k\rightarrow\infty}(h_{k} - g_{k}) = 0\quad\text{for a.e.}\ x$$

从而

$$f(x) = \operatorname{lim\, inf}\limits_{k\rightarrow\infty}h_{k}(x)\quad\text{for a.e.}\ x$$

This proves that, $f$ is Lebesgue measurable.
:::

::: {#ex-lec36-problem-solving-example-003 .example concepts="example-003"}
**Example**

Prove that:

$$\lim\limits_{n\rightarrow\infty}\int_{E}\sin(nx)\, dx = 0$$

for every bounded Borel set $E \subset {\mathbb{R}}$.\
:::

::: proof
**Proof**

Step 1: $E = (a,b)$ 是一个 interval.\

$$\int_{E}\sin(nx)\, dx = \lbrack - \frac{1}{n}\cos(nx)\rbrack_{a}^{b}$$

从而

$$\left. |\int_{E}\sin(nx)\, dx\  \middle| \leq \frac{2}{n}\overset{n\rightarrow\infty}{\rightarrow}0 \right.$$

Step 2: $E$ 是一个 finite union of disjoint open intervals.\
Same as Step 1.\
Step 3: General Case.\
Fix $\epsilon > 0$.\
Then by outer regularity: 存在 some $U$ 为 finite disjoint union of open intervals, 使得

$$m(U\Delta E) < \epsilon$$

从而

$$\left. |\int_{E}f_{n} = \int_{U}f_{n}\  \middle| < \middle| \int_{U\Delta E}f_{n}\  \middle| \leq m(U\Delta E) < \epsilon \right.$$

因而

$$\left. |\int_{E}f_{n}\  \middle| < \middle| \int_{U}f_{n}\  \middle| + \epsilon \right.$$

for all $n$. 并且 By step 2:

$$\left. \operatorname{lim\, sup}\limits_{n\rightarrow\infty} \middle| \int_{U}f_{n}\  \middle| + \epsilon = 0 + \epsilon \right.$$

因而

$$\left. \operatorname{lim\, sup}\limits_{n\rightarrow\infty} \middle| \int_{E}f_{n}\  \middle| \leq \epsilon \right.$$

Since $\epsilon$ arbitrary, 得证.
:::

::: {#ex-lec36-problem-solving-example-004 .example concepts="example-004"}
**Example**

Let $E \subset {\mathbb{R}}$ be a Borel set, with $m(E) > 0$.\
Set $f:{\mathbb{R}}\rightarrow{\mathbb{R}}$ be mble, nonneg, 并且 $\int f > 0$.\
Prove that: 存在 $t \in {\mathbb{R}}$ s.t.

$$\int_{E + t}f > 0$$
:::

::: proof
**Proof**

**Claim 1: STS to assume $f$ simple.**\
Proof of Claim 1: 对于 $f$, can find seq of simple functions $0 \leq f_{n} \leq f$, s.t. $f_{n}\operatorname{\nearrow ︎}f$.\
By MCT,
:::

# problem solving-III

::: {#ex-lec37-problem-solving-iii-example-001 .example concepts="example-001"}
**Example**

Let $f \in L_{loc}^{2}({\mathbb{R}})$.\
Assume

$$\left. \int_{a}^{a} \middle| t \middle| \middle| f(x + t) \middle| \, dt \geq \frac{2}{\sqrt{3}}a^{2} \right.$$

for all $a > 0$, $x \in {\mathbb{R}}$.\
Now show: $\left. |f(x) \middle| \geq 1 \right.$ for a.e. $x$.\
:::

::: proof
**Proof**

WLOG 可以假设 $f$ 是 nonneg 的. ($\left. f\mapsto \middle| f| \right.$).\
WTS: $\left. |f(x) \middle| \geq 1 \right.$ for a.e. $x$.\
Claim 1: by LDT, it STS:

$$\frac{1}{2a}\int_{- a}^{a}f(x + t)\, dt \geq 1$$

for all $x \in {\mathbb{R}}$.\
我们 try Cauchy Swartz:

$$\left. \int_{- a}^{a} \middle| t \middle| f(x + t)\, dt \leq (\int_{- a}^{a}t^{2}\, dt)^{1/2}(\int_{- a}^{a}f(x + t)^{2}\, dt)^{1/2} \right.$$

我们知道: 左边 $\geq \frac{2}{\sqrt{3}}a^{2}$, 而右边第一项 $(\int_{- a}^{a}t^{2}\, dt)^{1/2}$ 是可以计算的: 等于 $(\frac{2a^{3}}{3})^{1/2}$.\
于是, 我们得到

$$\int_{- a}^{a}f(x + t)^{2}\, dt \geq 2a$$

从而:

$$\frac{1}{2a}\int_{- a}^{a}f(x + t)^{2}\, dt \geq 1$$

然后 by LDT:

$$\frac{1}{2a}\int_{- a}^{a}f(x + t)^{2}\, dt = \frac{1}{2a}\int_{x - a}^{x + a}f(y)^{2}\, dy = f(x)^{2}$$

for a.e. $x$. 因而

$$f(x)^{2} \geq 1\,\quad\text{for a.e.}\ x$$

于是

$$\left. |f(x) \middle| \geq 1\,\quad\text{for a.e.}\ x \right.$$
:::

::: {#ex-lec37-problem-solving-iii-example-002 .example concepts="example-002"}
**Example**

Prove or disprove: 对于 bounded open set $E \subset {\mathbb{R}}$, 它的 boundary 是否一定满足 $m(\partial E) = 0$ ?\
:::

::: solution
**Solution**

Astonishingly 这个问题的回答是否定的. 我们可以构造
:::

# extra topics

## Minkowski ineq for integral

## convolution

我们已经证明了, for $1 \leq p < \infty$,

$$C_{c}^{0}({\mathbb{R}}^{n}) \subset L^{p}({\mathbb{R}}^{n})\quad\text{dense subset}$$

What about for $p = \infty$? 答案也是 true 的, 我们需要用到 convolution 来证明.\

# Use FTC and Tonelli for series

Let $g_{k},k = 1,2,\ldots$, be a sequence of functions that are absolutely continuous on the interval $\lbrack a,b\rbrack$. Suppose that there is a $c \in \lbrack a,b\rbrack$, such that the series $\sum_{k = 1}^{\infty}g_{k}(c)$ is convergent, and

$$\sum\limits_{k = 1}^{\infty}\int_{a}^{b}\left| {g_{k}'(x)} \right|dx < \infty$$

\(a\) Show that $\sum_{k = 1}^{\infty}g_{k}(x)$ is convergent for all $x \in \lbrack a,b\rbrack$. (b) Let $f(x) = \sum_{k = 1}^{\infty}g_{k}(x)$. Show that $f$ is absolutely continuous on $\lbrack a,b\rbrack$ and

$$f'(x) = \sum\limits_{k = 1}^{\infty}g_{k}'(x)\quad\text{for almost every} \in \lbrack a,b\rbrack$$



# Use FTC and Holder

Let $f:\lbrack 0,1\rbrack\rightarrow R$ be absolutely continuous, satisfy $f(0) = 0$ and $f' \in L^{2}(\lbrack 0,1\rbrack)$. Show that

$$\lim\limits_{x\rightarrow 0 +}x^{- 1/2}f(x)$$

exists and determine the value of this limit.

# Use density of compactly supported continuous functions in a suitable space

Let $f$ be a real Lebesgue measurable function on the interval $\lbrack 0,1\rbrack$ such that $\parallel f\underset{\infty}{\parallel} < \infty$. Show that for any $\varepsilon,\delta > 0$, there is a continuous function $g$ on $\lbrack 0,1\rbrack$ such that $m\left\{ x \in \lbrack 0,1\rbrack: \middle| f(x) - g(x) \middle| > \varepsilon \right\} < \delta$.

# Use one of the convergence theorems

Let A be a sequence of measurable subsets of $\lbrack 0,1\rbrack$ such that $\inf m\left( A_{n} \right) > 0$, where $m$ stands for the Lebesgue measure. (a) Prove that there exists $x \in \lbrack 0,1\rbrack$ which belongs to infinitely many of the sets $A_{n}$. (b) Does there necessarily exist a point which belongs to any of the sets $A_{n}$, except finitely many?

# How can we recover E from its indicator function

Let $E \subset {\mathbb{R}}^{1}$. Show that the characteristic function $\chi_{E}(x)$ is the limit of a sequence of continuous functions if and only if $E$ is both $F_{\sigma}$ and $G_{\delta}$.

# be an artisan

Let $f:\lbrack 0,1\rbrack\rightarrow{\mathbb{R}}$ be a positive function of bounded variation. (a) Show that if $\inf(f) > 0$, then the function $g(x) = 1/f(x)$ is also of bounded variation on $\lbrack 0,1\rbrack$. (b) Give an example of a positive function $f:\lbrack 0,1\rbrack\rightarrow{\mathbb{R}}$ of bounded variation such that $g(x) = 1/f(x)$ is integrable but not of bounded variation.

# Use a suitable theorem allowing you to differentiate $\exp(g)$ under the integral sign {#use-a-suitable-theorem-allowing-you-to-differentiate-exp-g-under-the-integral-sign}

Let $f$ be a real Lebesgue measurable function on the interval $\lbrack 0,1\rbrack$ such that $\parallel f\underset{\infty}{\parallel} < \infty$. For $\alpha \in {\mathbb{R}}$ define a function $g(\alpha)$ by

$$g(\alpha) = \log\left\lbrack {\int_{0}^{1}\exp\lbrack\alpha f(x)\rbrack dx} \right\rbrack$$



\(a\) Prove that the function $g( \cdot )$ is twice continuously differentiable and that $g^{''}(\alpha) \geq 0$ for all $\alpha \in {\mathbb{R}}$, i.e. the function $g( \cdot )$ is convex. (b) Prove that if $f$ is a non-constant function, i.e. $m\left\{ x \in \lbrack 0,1\rbrack: \middle| f(x) - c \middle| \neq 0 \right\} > 0$ for all constants $c \in {\mathbb{R}}$, then $g^{''}(\alpha) > 0,\alpha \in {\mathbb{R}}$.

# Use DCT

Let

$$f \in L_{1}(\lbrack 0,1\rbrack,dx)$$

Find:

$$\lim\limits_{n\rightarrow\infty}\frac{1}{n}\int_{0}^{1}\log\left( {1 + e^{nf(x)}} \right)dx$$



# Use Egoroff and Hölder

Let $\left\{ f_{n} \right\}$ be a sequence of functions in $L^{p}\left( {\mathbb{R}}^{n} \right),1 < p < \infty$, which converge almost everywhere to a function $f \in L^{p}\left( {\mathbb{R}}^{n} \right)$, and suppose that there is a constant $M$ such that $\parallel f_{n}\underset{p}{\parallel} \leq M$ for all $n$. Show that for every $g \in L^{q}\left( {\mathbb{R}}^{n} \right),q$ the conjugate of $p$,

$$\int fg = \lim\limits_{n\rightarrow\infty}\int f_{n}g$$

Is the statement true for $p = 1$ ? (Hint: you may want to use Egorov's Theorem.)

# Read up on HL

Let $f( \cdot )$ be a locally integrable function on ${\mathbb{R}}^{n}$ and $Mf$ the corresponding Hardy-Littlewood maximal function

$$\left. Mf(x) = \sup\limits_{R > 0}\frac{1}{|B(x,R)|}\int_{B(x,R)} \middle| f(y) \middle| dy,\quad x \in {\mathbb{R}}^{n} \right.$$

where $B(x,R)$ denotes the ball centered at $x$ with radius $R$. a) Show that if $f$ is integrable on ${\mathbb{R}}^{n}$ then $\sup_{\lambda > 0}\lambda m\left\{ x \in {\mathbb{R}}^{n}: \middle| \ f(x)\  \middle| > \lambda \right\} < \infty$. b) Let $f$ be the function

$$f(x) = \left\{ \begin{matrix}
{1\ } & {\text{if}\left| x \middle| < 1 \right.} \\
{0\ } & {\text{if}\left| x \middle| \geq 1 \right.}
\end{matrix} \right.$$

Show that $Mf$ is not integrable on ${\mathbb{R}}^{n}$, but $\sup_{\lambda > 0}\lambda m\left\{ {x \in {\mathbb{R}}^{n}:Mf(x) > \lambda} \right\} <$ $\infty$.

# Use density of such functions g somewhere, and then Hölder.

Fix $1 < p < \infty$. Let $f \in L^{p}(E)$, where $E$ is a measurable subset of ${\mathbb{R}}^{d}$. Assume that

$$\int_{E}f(x)g(x)dx = 0$$

for all compactly supported continuous functions $g:{\mathbb{R}}^{d}\rightarrow{\mathbb{R}}$. Is $f(x) = 0$ for almost every $x$ in $E$ ? If your answer is positive, prove it. Otherwise, given a counterexample.

# Fubini and Tonelli

Suppose that $f(x),x > 0$, is a real valued Lebesgue measurable square integrable function. (a) Prove that for any $\alpha > 0$, the inequality $\left. 2 \middle| f(z) \middle| \middle| f(y) \middle| \leq \alpha f(z)^{2} + f(y)^{2}/\alpha \right.$ holds for all $z,y,\alpha > 0$. (b) Express the double integral

$$\int_{0}^{\infty}\int_{0}^{\infty}\frac{\left. |f(z) \middle| \middle| f(y)| \right.}{y + z}dzdy$$

as an integral over the region $\left\{ {0 < z < y < \infty} \right\}$. (c) Show using your work from (a) and (b) that $\left. |f(z) \middle| \middle| f(y) \middle| /(y + z),y,z > 0 \right.$, is integrable and

$$\int_{0}^{\infty}\int_{0}^{\infty}\frac{\left. |f(z) \middle| \middle| f(y)| \right.}{y + z}dzdy \leq 4\int_{0}^{\infty}f(x)^{2}dx$$

Hint: Use the inequality in (a) with $\alpha = (z/y)^{1/2}$.

# Try a very nice function f first

Let $\left\{ {f_{n}(x)} \right\}$ be a sequence of continuous, strictly positive functions on $\mathbb{R}$ which converges uniformly to the function $f(x)$. Suppose that all the functions $\left\{ f_{n} \right\},f$ are integrable. Is

$$\lim\limits_{n\rightarrow\infty}\int f_{n}(x)dx = \int f(x)dx$$

Justify your answer.

# Use Lebesgue. Can you get the same equality for more sets E?

Let $f \in L_{1}(\lbrack 0,1\rbrack,dx)$ be a function such that $\int_{E}f(x)dx = 0$ for any measurable set $E \subset \lbrack 0,1\rbrack$ of Lebesgue measure .99. Prove that $f = 0$ a.e.

# Lebesgue

Let $f \in L^{2}(I)$, for any finite interval $I \subset {\mathbb{R}}$. Assume that

$$\left. \int_{- a}^{a} \middle| t \middle| \middle| f(x + t) \middle| dt \geq \frac{2}{\sqrt{3}}a^{2} \right.$$

for all $a > 0$ and $x \in {\mathbb{R}}$. Show that $\left. |f(x) \middle| \geq 1 \right.$ for a.e. $x \in {\mathbb{R}}$.

# Integration can be a trick to prove that a nonnegative function can't be identically zero.

Let $f$ and $g$ be nonnegative functions in $L^{1}({\mathbb{R}})$. Suppose that each function is positive on some set of positive measure. (However, there need not be a single set of positive measure where both functions are positive.) Prove that the convolution

$$h(x) = \int_{- \infty}^{\infty}f(x - t)g(t)dt$$

is positive on some set of positive measure.

# Check what happens on some set $\left\{ {f < c} \right\}$ with $\left. c < \middle| \middle| f \middle| |_{\infty} \right.$ {#check-what-happens-on-some-set-fc-with-cf_infty}

Let $E$ be a measurable subset of $\mathbb{R}$ such that $m(E) < \infty$. Let $f \in L^{\infty}(E)$ with $\parallel f\underset{\infty}{\parallel} > 0$. Show that

$$\lim\limits_{n\rightarrow\infty}\frac{\parallel f\underset{n + 1}{\overset{n + 1}{\parallel}}}{\parallel f\underset{n}{\overset{n}{\parallel}}} = \parallel f\underset{\infty}{\parallel}$$

Here $\parallel f\underset{n}{\parallel} := \parallel f\underset{L^{n}(E)}{\parallel}, \parallel f\underset{n + 1}{\parallel} := \parallel f\underset{L^{n + 1}(E)}{\parallel}$.

# Use distribution functions

Let $f:{\mathbb{R}}\rightarrow{\mathbb{R}}$ be a measurable function which has the property that

$$\left. m( \middle| f \middle| > \alpha) \leq \frac{1}{1 + \alpha^{3}}\quad\text{for}\ \alpha > 0 \right.$$

\(a\) Show that $|f|^{p}$ is integrable for $p < 3$. (b) Give an example of a function satisfying the above for which $|f|^{3}$ is not integrable.
