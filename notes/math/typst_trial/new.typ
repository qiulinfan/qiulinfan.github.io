#import "elegantbook.typ": *

#show: elegantbook.with(
  title: "Math 525",
  subtitle: "ElegantBook-flavored Typst experiment",
  author: "notesblog",
  date: "2026-05-06",
)

#outline(title: [Contents], depth: 2)

= basic combinatorics and probability space

#introduction[
  - 用绿色框放 definition / 术语。
  - 用橙色框放 theorem / lemma / corollary。
  - 用青蓝色框放 proposition。
  - example、proof、solution、remark 保持轻量的行内标签。
]

== permutations and combinations

=== permutations

#definition(title: [permutations])[
  一个 permutation 就是对一组 objects 的一个 *rearrangement*。对于 $n$ 个
  *distinct objects*，一共存在
  $ n! = n (n - 1) (n - 2) dots 2 dot 1 $
  个 permutations。
]

#example(title: [distinct permutations])[
  求 `"STATISTICS"` 的 distinct permutations 数量。

  #solution[
    这里一共有 10 个 objects，其中有 3 个 $S$、3 个 $T$、2 个 $I$ 是相同的。
    如果先把它们都看作 distinct objects，会得到 $10!$ 个 permutations；
    但每个真实排列都被重复计算了 $3! 3! 2!$ 次。因此答案是
    $ 10! / (3! 3! 2!) $
  ]
]

#remark[
  求一组 objects 的 distinct permutations 数量时，只需要除去每一类相同 object
  的内部 permutation 数量：
  $ n! / (n_1! n_2! dots n_k!) $
]

#definition(title: [multinomial coefficient])[
  令 $n in NN$，且 $n_1 + n_2 + dots + n_k = n$。我们定义
  $ binom(n, n_1 comma n_2 comma dots comma n_k)
    = n! / (n_1! n_2! dots n_k!) $
]

#proposition[
  如果我们需要 $n_1$ 个 object 1、$n_2$ 个 object 2、直到 $n_k$ 个 object $k$，
  那么它们的 distinct permutations 的数量为
  $ binom(n_1 + n_2 + dots + n_k, n_1 comma n_2 comma dots comma n_k) $
]

=== combinations

#definition(title: [combinations])[
  一个 combination 就是从一个 set 中选取若干个 elements，而忽略它们的顺序。
]

#proposition[
  从 $n$ 个 *distinct objects* 中选取 $k$ 个的 combinations 数量为
  $ binom(n, k) = n! / (k! (n - k)!) $
]

#proof[
  先数 ordered selections：共有
  $ n (n - 1) dots (n - k + 1) = n! / (n - k)! $
  种。每个 valid combination 会对应 $k!$ 个 ordering，所以最终除以 $k!$。
]

=== binomial theorem

#theorem(title: [Binomial Theorem])[
  令 $x, y in RR$，$n in NN$。则有
  $ (x + y)^n = sum_(k=0)^n binom(n, k) x^(n-k) y^k $
]

#proof[
  展开 $n$ 个 $(x + y)$ 的乘积时，每一项都来自于在每个括号里选择 $x$ 或 $y$。
  项 $x^(n-k) y^k$ 的系数等于从 $n$ 个位置里选出 $k$ 个位置放 $y$ 的组合数，
  即 $binom(n, k)$。
]

#exercise(title: [quick check])[
  用 binomial theorem 解释为什么
  $ sum_(k=0)^n binom(n, k) = 2^n $
]
