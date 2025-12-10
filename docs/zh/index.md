# Qiulin's Homepage

<div style="text-align: right; margin-top: 10px;">
  <label for="lang">🌐 Language:</label>
  <select id="lang" onchange="location = this.value;">
    <option value="https://qiulinfan.github.io/">English</option>
    <option value="https://qiulinfan.github.io/zh/">中文</option>
  </select>
</div>


<script>
  const langSelect = document.getElementById("lang");
  // 根据 URL 来决定默认选中
  if (window.location.pathname.startsWith("/zh")) {
    langSelect.value = "https://qiulinfan.github.io/zh/";
  } else {
    langSelect.value = "https://qiulinfan.github.io/";
  }
  // 切换时跳转
  langSelect.addEventListener("change", function() {
    window.location.href = this.value;
  });
</script>

<div style="float:right; width:200px; text-align:center;">
  <img src="./assets/%E5%8D%81%E9%A6%99.jpg" alt="十香" width="200" align="left">
  <p style="font-size:0.8em; color:gray; margin:4px 0;">
  十香. Image credit: <a href="https://www.pixiv.net/artworks/74140599">Bison倉鼠</a>
  </span>
</div>这里是 Qiulin, from University of Michigan, 主修应数和 CS. 十香厨 & 露琪亚厨.

喜欢 computer graphics, game&game engine dev.

也喜欢分析学, 拓扑学和微分几何.

会在这个网站发布一些笔记, 求佬勿喷.

## 游戏 projects

### Village Rim

我们的最新 2D 冒险游戏: [Village Rim](https://saddysamoyed.itch.io/village-rim).

一个约 20 分钟（或更长）的 2D 冒险游戏，与 Gigi Pan, James Tian, Emma Zhang, 和 Yulong Huang 共同创作。

游戏托管在 itch.io 上，你可以从游戏页面下载。请按照教程中的说明操作，希望你喜欢这个游戏！


### Zelda 1986, Dungen Level 1 复刻
web play 链接在这里: [Zelda 1986 Game](https://saddysamoyed.itch.io/zelda1986-level1), host 于 [itch.io](https://itch.io/) .<img src="assets/Screenshot 2025-09-24 at 09.12.18.png" alt="Screenshot 2025-09-24 at 09.12.18" style="zoom:25%;" />



## CS 笔记

Programming and Computer Systems

- [C++ Programming](https://qiulinfan.github.io/cpp/index.html)
- [数据结构与算法](https://qiulinfan.github.io/dsa/index.html)

AI and Optimization: 

- [机器学习](https://qiulinfan.github.io/ml/index.html)
- [非线性优化](https://qiulinfan.github.io/opt/index.html)
- [计算机视觉](https://qiulinfan.github.io/cv/index.html)
- [自然语言处理](https://qiulinfan.github.io/nlp/index.html)
- [Unity 游戏开发](https://qiulinfan.github.io/gamedev/index.html)


## 数学笔记
- [测度论 (following *Real Analysis* by Folland)](https://qiulinfan.github.io/math-597-measure_theory-notes/index.html)

