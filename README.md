# Mouse-Warp-Spoon

**English** | [中文（简体）](README.zh-CN.md)

When using multiple screens, if the application window you switch to is on another screen, move the mouse cursor to the center of the currently active window.

There used to be an app called "Mouse Warp" that handled this on the Mac, but it stopped receiving updates a long time ago — so I made this Spoon. If you find installing and configuring Hammerspoon too much hassle, you can also try AutoRaise (<https://github.com/sbmpost/AutoRaise>), a standalone app with similar functionality.

## Features

- Listens for window focus changes (Cmd+Tab app switching, clicking a Dock icon or another app's window, switching windows within the same app with Cmd+` ...).
- Only when the newly focused window and the current mouse position are on **different physical screens** does it move the cursor to the center of that window; if they are on the same physical screen, the cursor is left untouched.
- Can be enabled / disabled at any time with a custom hotkey.

## Installation

1. Download and install Hammerspoon itself (this plugin runs on top of it): visit <http://www.hammerspoon.org/>, click **Download the latest release** (it points to the GitHub releases page), then drag `Hammerspoon.app` into `/Applications/`. On first launch, follow the prompts to enable Accessibility access for the app — without that permission this plugin can neither read window info nor move the cursor.

   If you are on an older macOS version, check Hammerspoon's Release Notes for a build that is compatible with your system.

2. Copy the `MouseWarp.spoon` directory to `~/.hammerspoon/Spoons/`:

   ```bash
   cp -r MouseWarp.spoon ~/.hammerspoon/Spoons/
   ```

3. Load and enable it in `~/.hammerspoon/init.lua`:

   ```lua
   hs.loadSpoon("MouseWarp")
   spoon.MouseWarp:start()
   ```

   Or use `hs.spoons.use` (which calls `start` automatically):

   ```lua
   hs.spoons.use("MouseWarp")
   ```

4. Reload the Hammerspoon config (menu bar icon → Reload Config, or run `hs.reload()`).

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
- Focus changes are tracked through two cheap event-driven sources instead of `hs.window.filter`: `hs.application.watcher` for application switches (Cmd+Tab, clicking a Dock icon, ...), plus a single `hs.uielement.watcher` on the frontmost application for focus changes that do not switch apps (Cmd+` within the same app, clicking another window of the same app). Installing them is a constant amount of work — there is no window scan — so enabling the plugin is immediate, with no startup jank and no need for a deferred start.
- Because only the frontmost application is watched, a focus change happening inside a background application (one that never becomes frontmost) is not observed. Everything that can leave the cursor behind — app switches, Cmd+`, clicking another window of the same app — is covered.
- The watchers stay installed while the plugin is disabled, so toggling on/off is an instant flag flip.

## Version history

- **2.0.0** (2026-09-17) — Replaced `hs.window.filter` with a cheaper event layer: `hs.application.watcher` for application switches, plus a single `hs.uielement.watcher` on the frontmost application for focus changes within the same app. Installing the watchers is constant work, so the startup stall is gone and the `initDelay` option was removed.
- **1.2.2** (2026-08-18) — Fixed a deprecated mouse API call (`hs.mouse.setAbsolutePosition` → `hs.mouse.absolutePosition`) and made the log level explicit so info / debug messages are actually visible. Docs were expanded afterwards (bilingual README, installation notes, alternative apps) without further code changes.
- **1.2.0** (2026-08-18) — Added `initDelay`: a deferred one-time initialization that moved the `hs.window.filter` window scan off the config-load moment.
- **1.0.0** (2026-08-18) — First working version: move the cursor to the center of the focused window when it sits on a different screen, with a hotkey to toggle the plugin.
