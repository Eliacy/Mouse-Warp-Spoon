# Mouse-Warp-Spoon

[English](README.md) | **中文（简体）**

在使用多个屏幕时，如果切换到的应用窗口在其他屏幕上，那么就把鼠标也移动到当前活跃窗口的中心。

最初有个名为“Mouse Warp”的应用能在 Mac 上完成这部分功能，但后来这个应用很久不更新了，我就做了这个插件。如果你觉得安装和配置 HammerSpoon 太麻烦，那也可以试试包含类似功能的独立应用 <https://github.com/sbmpost/AutoRaise> 。

## 功能

- 监听窗口焦点变化（Cmd+Tab 切换应用、点击 Dock 图标或另一应用的窗口、同一应用内 Cmd+` 切换窗口等）。
- 仅当新聚焦的窗口与鼠标当前所在位置**不在同一个物理屏幕**时，才把鼠标移动到该窗口的中心；
  属于同一个物理屏幕时，不对鼠标位置做任何处理。
- 可通过自定义快捷键随时开启 / 关闭本插件。

## 安装

1. 下载并安装 Hammerspoon 本体（本插件需运行在它之上）：访问 <http://www.hammerspoon.org/>，点击 **Download the latest release**（跳转到 GitHub Releases 页面）下载安装包，再把 `Hammerspoon.app` 拖入「应用程序」（`/Applications/`）。首次运行时按提示为它开启「辅助功能（Accessibility）」权限——没有该权限，本插件无法读取窗口信息、也无法移动鼠标。

   如果你的 Mac 系统版本较旧，请查阅 Hammerspoon 的 Release Notes 选择与其兼容的版本。

2. 将 `MouseWarp.spoon` 目录复制到 `~/.hammerspoon/Spoons/`：

   ```bash
   cp -r MouseWarp.spoon ~/.hammerspoon/Spoons/
   ```

3. 在 `~/.hammerspoon/init.lua` 中加载并启用：

   ```lua
   hs.loadSpoon("MouseWarp")
   spoon.MouseWarp:start()
   ```

   或使用 `hs.spoons.use`（会自动调用 `start`）：

   ```lua
   hs.spoons.use("MouseWarp")
   ```

4. 重新加载 Hammerspoon 配置（菜单栏图标 → Reload Config，或执行 `hs.reload()`）。

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
- 日志级别默认 `verbose`，插件的 info / debug 日志都会显示在 Hammerspoon 控制台；可在加载前修改 `spoon.MouseWarp.logLevel`，或运行时调用
  `spoon.MouseWarp.logger:setLogLevel('warning')` 调整。注意 `hs.logger.new` 不传级别时默认是 `warning`，会把 info / debug 日志隐藏。
- 插件基于 `hs.window.filter`。首次开启后会延迟 `spoon.MouseWarp.initDelay` 秒（默认 1 秒，可提前调整）再执行一次性全量窗口扫描，
  把启动瞬间的集中卡顿移到启动后几秒的相对安静时机；若在延迟内关闭插件则取消扫描。扫描完成后开启 / 关闭只是切换标志位，即时应答。
