# Mouse-Warp-Spoon

在使用多个屏幕时，如果切换到的应用窗口在其他屏幕上，那么就把鼠标也移动到当前活跃窗口的中心。

## 功能

- 监听窗口焦点变化（Cmd+Tab 切换应用、应用内切换窗口等）。
- 仅当新聚焦的窗口与鼠标当前所在位置**不在同一个物理屏幕**时，才把鼠标移动到该窗口的中心；
  属于同一个物理屏幕时，不对鼠标位置做任何处理。
- 可通过自定义快捷键随时开启 / 关闭本插件。

## 安装

1. 将 `MouseWarp.spoon` 目录复制到 `~/.hammerspoon/Spoons/`：

   ```bash
   cp -r MouseWarp.spoon ~/.hammerspoon/Spoons/
   ```

2. 在 `~/.hammerspoon/init.lua` 中加载并启用：

   ```lua
   hs.loadSpoon("MouseWarp")
   spoon.MouseWarp:start()
   ```

   或使用 `hs.spoons.use`（会自动调用 `start`）：

   ```lua
   hs.spoons.use("MouseWarp")
   ```

3. 重新加载 Hammerspoon 配置（菜单栏图标 → Reload Config，或执行 `hs.reload()`）。

## 设置开关快捷键

两种写法等价，按键格式为「修饰键组合 + 按键」：

```lua
-- 写法一：经典格式
spoon.MouseWarp:bindHotkeys({
    toggle = { { "ctrl", "alt" }, "m" },
})

-- 写法二：字符串格式
spoon.MouseWarp:bindHotkeys({
    toggle = "ctrl-alt-m",
})
```

也可结合 `hs.spoons.use` 一步完成：

```lua
hs.spoons.use("MouseWarp", {
    hotkeys = {
        toggle = "ctrl-alt-m",
    },
})
```

快捷键绑定后始终可用，与插件当前的开启 / 关闭状态无关。也可以直接调用 `spoon.MouseWarp:start()`、`spoon.MouseWarp:stop()`、`spoon.MouseWarp:toggle()`。

## 行为说明

- 默认状态为**关闭**，需要调用 `start`（或 `hs.spoons.use`）后才生效。
- 「物理屏幕」依据 macOS 的显示器几何布局判断：鼠标所在屏幕与窗口所在屏幕不同时才会移动鼠标。
- 仅处理标准窗口；浮动面板、辅助窗口等非标准窗口不会触发鼠标移动。
- 鼠标位置在事件触发后再做一次确认：如果在延迟期间用户已手动把鼠标移到了目标屏幕，则不会移动鼠标。
- 通过快捷键（或 `toggle()`）开启 / 关闭插件时，除了写入 Hammerspoon 日志（`MouseWarp` 分类），还会在屏幕上弹出临时浮窗提示（`hs.alert.show`：`MouseWarp: 已启用` / `MouseWarp: 已禁用`）；
  直接调用 `start()` / `stop()`（例如在配置加载时）只写日志，不弹浮窗。