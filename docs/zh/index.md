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
  </p>
</div>

这里是 Qiulin, from University of Michigan, 主修应数和 CS. 十香厨 & 露琪亚厨.

喜欢 computer graphics, game&game engine dev.

也喜欢分析学, 拓扑学和微分几何.

会在这个网站发布一些笔记, 求佬勿喷.
## Projects

### Game Projects
[查看项目页](game-projects.md)

<div style="display:flex; gap:16px; flex-wrap:wrap; margin:12px 0 20px 0;">
  <a href="game-projects/" style="display:block;">
    <img src="assets/villageRIM.png" alt="Village Rim" width="200">
  </a>
  <a href="game-projects/" style="display:block;">
    <img src="assets/Screenshot 2025-09-29 at 09.46.12.png" alt="Zelda 1986 recreation" width="200">
  </a>
  <a href="game-projects/" style="display:block;">
    <img src="assets/seal.png" alt="Colorable" width="200">
  </a>
</div>

### PocketEngine
[Project page](https://qiulinfan.github.io/pocketEngine/) | [Repository](https://github.com/qiulinfan/pocketEngine)

PocketEngine 是一个基于 C++17、SDL2、Lua、Box2D、Dear ImGui 和 JSON scene assets 的 2D engine / editor.

<div style="max-width:420px; margin:12px 0 0 0;">
  <a href="https://qiulinfan.github.io/pocketEngine/">
    <img
      src="https://qiulinfan.github.io/pocketEngine/show.gif"
      alt="PocketEngine editor preview"
      style="width:100%; height:auto; display:block;">
  </a>
</div>

编辑器包含一个 docked Sceneview, embedded runtime Viewport, Project browser, Hierarchy, Inspector, 和 live playmode mutation workflow.

## Research Projects
- [graphNL2SQL](https://github.com/qiulinfan/graphNL2SQL): 微调小型 LLM (3-8B) 以图增强的 schema 表示实现强大的自然语言到 SQL 生成性能. 



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
