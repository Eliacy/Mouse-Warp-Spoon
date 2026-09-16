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
- 焦点变化由两个低成本的事件源跟踪（取代 `hs.window.filter`）：`hs.application.watcher` 负责应用切换（Cmd+Tab、点击 Dock 图标等）；
  另有一个挂在**最前台应用**上的 `hs.uielement.watcher`，负责不切换应用的焦点变化（同应用内用 Cmd+` 切换窗口、点击同一应用的另一个窗口）。
  两者的安装都是常数级开销（不做窗口扫描），因此开启插件是即时的，既没有启动卡顿，也不需要延迟启动。
- 由于只监听最前台应用，某个始终未进入前台的后台应用内部发生的焦点变化不会被感知；
  而所有可能「把鼠标留在原地」的场景（应用切换、Cmd+`、点击同一应用的另一个窗口）都已覆盖。
- 插件关闭期间这两个监听器仍然保留，因此开启 / 关闭依旧只是切换标志位，即时应答。

## 版本更新记录

- **2.0.0**（2026-09-17）—— 事件层重写：用 `hs.application.watcher`（负责应用切换）加挂在最前台应用上的单个 `hs.uielement.watcher`（负责同应用内焦点变化）取代 `hs.window.filter`。监听器的安装是常数级开销，启动卡顿消失，同时删除了 `initDelay` 选项。
- **1.2.2**（2026-08-18）—— 修正已弃用的鼠标 API 调用（`hs.mouse.setAbsolutePosition` → `hs.mouse.absolutePosition`），并把日志级别显式化，使 info / debug 日志真正可见。此后仅扩充文档（中英双语 README、安装说明、替代软件），代码未再变动。
- **1.2.0**（2026-08-18）—— 新增 `initDelay`：延迟执行一次性初始化，把 `hs.window.filter` 的窗口扫描从配置加载时刻挪开。
- **1.0.0**（2026-08-18）—— 首个可用版本：焦点窗口在另一块屏幕上时，把鼠标移到该窗口中心，并支持快捷键启停。
