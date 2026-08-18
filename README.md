# Mouse-Warp-Spoon

**English** | [中文（简体）](README.zh-CN.md)

When using multiple screens, if the application window you switch to is on another screen, move the mouse cursor to the center of the currently active window.

There used to be an app called "Mouse Warp" that handled this on the Mac, but it stopped receiving updates a long time ago — so I made this Spoon.

## Features

- Listens for window focus changes (Cmd+Tab app switching, clicking a Dock icon or another app's window, switching windows within the same app with Cmd+` ...).
- Only when the newly focused window and the current mouse position are on **different physical screens** does it move the cursor to the center of that window; if they are on the same physical screen, the cursor is left untouched.
- Can be enabled / disabled at any time with a custom hotkey.

## Installation

1. Copy the `MouseWarp.spoon` directory to `~/.hammerspoon/Spoons/`:

   ```bash
   cp -r MouseWarp.spoon ~/.hammerspoon/Spoons/
   ```

2. Load and enable it in `~/.hammerspoon/init.lua`:

   ```lua
   hs.loadSpoon("MouseWarp")
   spoon.MouseWarp:start()
   ```

   Or use `hs.spoons.use` (which calls `start` automatically):

   ```lua
   hs.spoons.use("MouseWarp")
   ```

3. Reload the Hammerspoon config (menu bar icon → Reload Config, or run `hs.reload()`).

## Toggle hotkey

Both forms are equivalent; the key spec is "modifier combination + key":

```lua
-- Form 1: classic format
spoon.MouseWarp:bindHotkeys({
    toggle = { { "ctrl", "alt" }, "m" },
})

-- Form 2: string format
spoon.MouseWarp:bindHotkeys({
    toggle = "ctrl-alt-m",
})
```

Or do it in one step with `hs.spoons.use`:

```lua
hs.spoons.use("MouseWarp", {
    hotkeys = {
        toggle = "ctrl-alt-m",
    },
})
```

The hotkey remains active regardless of the plugin's current on/off state. You can also call `spoon.MouseWarp:start()`, `spoon.MouseWarp:stop()`, or `spoon.MouseWarp:toggle()` directly.

## Behavior notes

- Default state is **off**; it only takes effect after calling `start` (or `hs.spoons.use`).
- "Physical screen" is determined by the macOS display geometry layout: the cursor moves only when the window's screen differs from the screen the mouse is currently on.
- Only standard windows are handled; floating panels and accessory windows never trigger a warp.
- The mouse position is re-checked right before warping: if you manually moved the pointer onto the target screen during the delay, the mouse is left alone.
- Toggling via the hotkey (or `toggle()`) writes to the Hammerspoon log (category `MouseWarp`) and shows a transient on-screen alert (`hs.alert.show`, `MouseWarp: 已启用` / `MouseWarp: 已禁用`, i.e. "enabled" / "disabled"); directly calling `start()` / `stop()` (e.g. at config load) only logs.
- The log level defaults to `verbose`, so the plugin's info / debug messages all appear in the Hammerspoon console. Change it before loading via `spoon.MouseWarp.logLevel`, or at runtime with `spoon.MouseWarp.logger:setLogLevel('warning')`. Note that `hs.logger.new` falls back to `warning` when no level is given, which hides info / debug messages.
- Built on `hs.window.filter`. On the first enable, the one-time full window scan is deferred by `spoon.MouseWarp.initDelay` seconds (default 1 s, adjustable beforehand), moving the momentary startup jank to a quieter moment shortly after startup; disabling the plugin within the delay cancels the scan. Once the scan has run, toggling on/off is an instant flag flip.