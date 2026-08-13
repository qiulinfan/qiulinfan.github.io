# 更改 VSCode 背景

我们可以下载 background 这个 extension.

Cmd+shift+P 打开 setting.json, 把这个配置加入进去

其中 images 填本地想放在上面的 Images.

panel 是 terminal 那边, sidebar 是侧边, editor 是代码边

```json
	"background.enabled": true,
    "background.panel": {
        "useFront": true,
        "images": ["file:///Users/fanqiulin/Documents/Photos/scene.jpeg"],
        "opacity": 0.08,
        "width": "100%",
        "height": "100%",
        "backgroundSize": "cover",
        "backgroundPosition": "center",
        "backgroundRepeat": "no-repeat"
    },
    "background.sidebar": {
        "useFront": true,
        "images": ["file:///Users/fanqiulin/Documents/Photos/samurai.jpeg"],
        "opacity": 0.08,
        "width": "100%",
        "height": "100%",
        "backgroundSize": "cover",
        "backgroundPosition": "center",
        "backgroundRepeat": "no-repeat"
    }
```





## 仅更改颜色

也是在 setting.json

```json
"workbench.colorCustomizations": {
     "editor.background": "#252424"
}
```

这个得自己调了, 或者偷别人的配色方案





## 更改 theme

需要下载对应的 theme extension.

然后在 setting.json 里修改.

我的选择是:

```json
"workbench.colorTheme":"Atom One Dark", // atom, 稍微浅一点的深色
"workbench.iconTheme":"vs-seti",
```



## background extension

需要下载 background 这个 extension. 注意不是动漫头那个, 是朴素蓝色底的那个. (个人觉得这个更灵活点, 且动漫头的那个调 editor 背景的 opacity 有点不灵, editor 还是得调小点的, 不然有点干扰代码.)

这个 extension 强烈推荐. 操作很方便, 下载了就知道了.





## 调整 VSCode 图标

虽然 seems 画蛇添足但是看实际效果真的很香:

![show](assets/show.png)

这个请参考: https://github.com/Aikoyori/ProgrammingVTuberLogos

设置起来很简单.
