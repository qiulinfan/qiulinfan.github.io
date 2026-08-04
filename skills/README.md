# Skills

用于存放个人积累和维护的 skills，以及从开源社区下载的
skills。本目录是 skill 文件的权威副本；`~/.codex/skills` 通过软链接使用它们。

## 跨设备安装

克隆仓库后执行：

```sh
./skills/link-codex-skills.sh
```

脚本会从每个 `SKILL.md` 的 `name` 字段推导 Codex 中的链接名。如果现有目录
与仓库副本一致，脚本会先备份再建立链接；如果内容不一致，脚本会拒绝覆盖并
报告冲突。

## 个人维护

- [build-unity-scene](./build-unity-scene/)
- [configure-unity-mcp](./configure-unity-mcp/)
- [create-latex-math-notes](./create-latex-math-notes/)
- [create-math-notes](./create-math-notes/)
- [discuss-game-design](./discuss-game-design/)
- [export-typst-math-notes](./export-typst-math-notes/)
- [extract-paper-concepts](./extract-paper-concepts/)
- [kgdistiller-distill](./kgdistiller-distill/)
- [play-unity-game](./play-unity-game/)
- [search-game-art](./search-game-art/)
- [trace-concept-lineage](./trace-concept-lineage/)

## 社区来源

- [find-skill-skillhub-1.0.2](./find-skill-skillhub-1.0.2/)：从 SkillHub 查找 skill。
  来源：<https://skillhub.cn/skills/find-skill-skillhub>
- [mainpdf](./mainpdf/)：PDF 编辑、转换、OCR 与内容提取。
- [mermaid-diagram-1.0.0](./mermaid-diagram-1.0.0/)：生成 Mermaid 图。
  来源：<https://skillhub.cn/skills/mermaid-generator>
