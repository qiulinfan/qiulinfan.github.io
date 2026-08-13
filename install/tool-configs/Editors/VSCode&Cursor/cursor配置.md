# Cursor setup

cursor 挺好配置的, 主要是因为它可以直接一键复制 VSCode 的配置.

## import setting from VSCode

在 cursor setting 的 general 里.



## activity bar 改成 VSCode 布局

这个不知道为什么默认和 VSCode 的不一样. 就是左边的 side bar 旁边的 activity bar, 默认是横过来的, 我感觉挺不习惯的. 所以

1. `Cmd(Ctrl) + ,`
2. 搜索 `Activity Bar`
3. 找到 Orientation 把它改成 vertical

然后就和 VSCode 一模一样了.





## 打开/关闭代码续写

cursor 默认是没代码续写的, 和 copilot 不一样. 因为这个需求确实因人而异. 但是做一些简单的任务的时候真的很需要这个功能.

在 cursor setting 的 Beta 这里可以找到 autocomplete 的开关键.



## 设置 tab 补全单词的优先级 > tab 代码续写, 以及增加快捷键

这个是一个很奇怪的默认设置. 我们知道 tab 在 vscode copilot 里面即是智能补全单词又是 copilot 代码续写的接受键. copilot 里面补全单词优先级是高于 copilot 续写的.

而 Cursor 的 tab 是代码续写优先级 > 智能补全单词.

这个很容易改: `cmd + shift + P` 打开命令台, 输入 `Preferences: Open Keyboard Shortcuts (JSON)`, 加上:

```json
  {
    "key": "tab",
    "command": "acceptSelectedSuggestion",
    "when": "suggestWidgetVisible && textInputFocus"
  },
  {
    "key": "tab",
    "command": "cursor.acceptAutocomplete",
    "when": "!suggestWidgetVisible && inlineSuggestionVisible && textInputFocus"
  }
```

就好了. 这就把优先级调了过来.



但是有些时候我们又会需要 cursor 的补全更高优先级. 比如写 latex (tab complete 真的很垃圾), 那就注释掉



## 文件树中不要显示一类文件

在文件树中隐藏一类文件的方法: 以 .meta 为例
Cmd + Shift + P
→ Preferences: Open Settings (JSON)

```json
{
  "files.exclude": {
    "**/*.meta": true
  }
}
```





# 指令

使用 cursor 过程中要记得以下指令 (Mac 自动把 Ctrl 切换为 Cmd)

- ctrl + L 显示/隐藏 chat

- 选中代码 ctrl + K 打开 inline AI 对话

   Chat 里输入 `/` 会看到一些内置指令, 常见的有:

  - `/explain` 解释选中代码
  - `/edit` 按描述修改代码
  - `/fix` 修复错误
  - `/test` 生成测试
  - `/doc` 生成文档 / 注释
  - `/search` 在项目中搜索相关实现
