# 游戏项目

[返回首页](index.md) | [English](../game-projects.md)

这里收集我做过的一些游戏项目。

部分 Unity 项目里的美术资源使用了 Suno AI 和 diffusion models，具体说明写在各项目的 `credit.txt` 里。

## Village Rim

<img src="../assets/villageRIM.png" alt="Village Rim screenshot" width="420">

[Village Rim](https://bluesamoyed.itch.io/village-rim) 是一个约 20 分钟的 2D 冒险游戏，与 Gigi Pan、James Tian、Emma Zhang 和 Yulong Huang 共同完成。

我主要负责敌人与战斗系统，包括动作设计与实现、动画，以及玩家和敌人的补充 tilesets。前期我使用 FSM，后期为了更丰富的交互切到了 behavior trees，并让 spawning system 同时兼容两种方案。我也负责了各个关卡的设计。

## Zelda 1986 Level 1 复刻

<img src="../assets/Screenshot 2025-09-29 at 09.46.12.png" alt="Zelda 1986 recreation screenshot" width="420">

这是我和 James Tian 一起做的《Zelda 1986》第一关 dungeon 复刻: [Zelda 1986 Game](https://bluesamoyed.itch.io/zelda1986-level1)。

我实现了敌人 AI、生命系统、房间控制系统，以及 bomb 和 boomerang 武器；也设计了我们自定义的 shadow feature，并完成了大部分动画。动画素材主要来自 [The Spriters Resource](https://www.spriters-resource.com/) 的开源 spritesheets。

## Colorable

<img src="../assets/seal.png" alt="Colorable screenshot" width="420">

[Colorable](https://bluesamoyed.itch.io/colorables) 是我第一个个人游戏项目，一个以颜色机制为核心的小型单人 FPS。

核心玩法是颜色变化与混合。玩家一共有八种颜色状态：黑色、三原色、两两混合后的颜色，以及纯白。敌人和场景物体也带有颜色属性，所以这个机制同时影响战斗和互动解谜。
