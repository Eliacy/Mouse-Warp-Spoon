--- === MouseWarp ===
---
--- Warp the mouse cursor to the center of the focused window when it lives on a different physical screen than the cursor.
---
--- In a multi-display setup, switching to an application whose window is on another screen leaves the pointer
--- behind. This Spoon watches for window focus changes and only when the newly focused window and the current
--- cursor position are on different physical screens moves the cursor to the center of that window. If they are
--- on the same screen, the cursor is left untouched.
---
--- Focus changes are tracked with two cheap event-driven sources instead of `hs.window.filter`, whose first
--- `:subscribe()` synchronously walks every running application and every window it owns (creating one AX
--- observer per window) and therefore stalls Hammerspoon's main thread for a noticeable moment:
---
---   * `hs.application.watcher` reports application switches (Cmd+Tab, clicking a Dock icon, ...).
---   * a single `hs.uielement.watcher` on the frontmost application reports window focus changes that happen
---     without an application switch (Cmd+` within the same app, clicking another window of the same app).
---
--- Installing both is a constant amount of work, so enabling the Spoon is immediate and needs no deferred
--- initialization. The trade-off is that focus changes happening in an application that is *not* frontmost are
--- not seen; every focus change that can leave the pointer behind goes through an application switch or through
--- the frontmost application, so those are covered.
---
--- See the project README for installation and usage.

local obj = {}
obj.__index = obj

-- Metadata ----------------------------------------------------------------

obj.name = "MouseWarp"
obj.version = "2.0.0"
obj.author = "Elias Soong"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Log level for the `MouseWarp` logger: "verbose", "debug", "info", "warning" or "error".
-- Be explicit here: `hs.logger.new` without a level falls back to 'warning' (hs.logger.defaultLogLevel),
-- which would hide the info/debug messages from the console. Change before startup, or at runtime via
-- `spoon.MouseWarp.logger:setLogLevel("info")`.
obj.logLevel = "verbose"

obj.logger = hs.logger.new("MouseWarp", obj.logLevel)

-- Whether automatic warping is currently active.
obj.enabled = false

-- Internal state ------------------------------------------------------------

-- The watchers are installed once and then left running for the whole session: `enabled` alone decides
-- whether a focus change warps the cursor, which keeps enable/disable an instant flag flip.
obj.appWatcher = nil      -- hs.application.watcher: reports application switches
obj.focusWatcher = nil    -- hs.uielement.watcher on the frontmost application's focused window
obj.focusWatcherPid = nil -- pid of the application obj.focusWatcher is attached to
obj.pendingWarp = nil     -- hs.timer coalescing a burst of focus changes into a single warp check

local MODIFIER_MAP = {
    cmd = "cmd", command = "cmd",
    alt = "alt", option = "alt",
    ctrl = "ctrl", control = "ctrl",
    shift = "shift", fn = "fn",
}

--- MouseWarp:sameScreen(win)
--- Method
--- Returns `true` when the window and the current mouse position are on the same physical screen.
--- Returns `true` as a safe default when either screen cannot be determined (no warping then).
function obj:sameScreen(win)
    local winScreen = win and win:screen()
    local mouseScreen = hs.mouse.getCurrentScreen()
    if not (winScreen and mouseScreen) then return true end
    local w, m = winScreen:frame(), mouseScreen:frame()
    return w.x == m.x and w.y == m.y and w.w == m.w and w.h == m.h
end

local WARP_SETTLE_DELAY = 0.08 -- focus events can arrive mid-transition; re-check after the frame settles

local function warpCheck()
    if not obj.enabled then return end
    -- The window is resolved here rather than carried in from the event: by the time the settle delay has
    -- elapsed the focus has landed, so this reads the state that actually matters. pcall guards against
    -- stale state and version differences in the hs.window API: if a method is unavailable or the window
    -- died, simply skip the warp.
    local ok, err = pcall(function()
        local win = hs.window.focusedWindow()
        if not (win and win:isStandard()) then return end
        if obj:sameScreen(win) then return end
        local f = win:frame()
        hs.mouse.absolutePosition({ x = f.x + f.w / 2, y = f.y + f.h / 2 })
        obj.logger.d("Mouse warped to the center of \"" .. (win:title() or "") .. "\"")
    end)
    if not ok then
        obj.logger.d("Warp skipped: " .. tostring(err))
    end
end

-- A single focus change can arrive as several events (an application switch reports an activation and a
-- focused-window change), and the check re-reads the state when it runs, so one pending check is enough
-- for any number of them.
local function scheduleWarpCheck()
    if not obj.enabled or obj.pendingWarp then return end
    obj.pendingWarp = hs.timer.doAfter(WARP_SETTLE_DELAY, function()
        obj.pendingWarp = nil
        warpCheck()
    end)
end

local function releaseFocusWatcher()
    if not obj.focusWatcher then return end
    local watcher = obj.focusWatcher
    obj.focusWatcher = nil
    obj.focusWatcherPid = nil
    pcall(function() watcher:stop() end)
end

-- Moves the focus watcher onto `app`, which the caller believes has just become frontmost. Watching only the
-- frontmost application is what keeps this cheap: any focus change that can leave the pointer behind happens
-- in the application that currently owns the focus.
local function observeApp(app)
    if not app then return end
    local pid = app:pid()
    if not pid or pid == obj.focusWatcherPid then return end
    local uiWatcher = require("hs.uielement").watcher
    local ok, watcher = pcall(function()
        return app:newWatcher(function(_, event)
            if event == uiWatcher.focusedWindowChanged then
                scheduleWarpCheck()
            end
        end)
    end)
    if not (ok and watcher) then
        obj.logger.w("Cannot watch focus changes of \"" .. (app:name() or "?") .. "\": " .. tostring(watcher))
        return
    end
    -- `newWatcher` reports failure by returning nil, but `:start()` has no equally dependable return value,
    -- so there a raised error is the only failure mode worth acting on.
    local started, startErr = pcall(function() watcher:start({ uiWatcher.focusedWindowChanged }) end)
    if not started then
        obj.logger.w("Cannot watch focus changes of \"" .. (app:name() or "?") .. "\": " .. tostring(startErr))
        return
    end
    -- Only once the new watcher is in place drop the previous one, so that the application switch that got
    -- us here never leaves a gap with nothing being watched.
    releaseFocusWatcher()
    obj.focusWatcher = watcher
    obj.focusWatcherPid = pid
    obj.logger.d("Watching focus changes of \"" .. (app:name() or "?") .. "\"")
end

--- MouseWarp:start([notify])
--- Method
--- Enables the auto-warp behavior. Idempotent. When `notify` is truthy, shows a temporary on-screen alert.
--- The watchers are installed on the first call; that is a constant amount of work (two notification
--- observers, no window scan), so enabling is immediate and needs no deferral.
function obj:start(notify)
    if obj.enabled then return obj end
    obj.enabled = true
    if not obj.appWatcher then
        local appWatcher = require("hs.application").watcher
        obj.appWatcher = appWatcher.new(function(_, event, app)
            if event == appWatcher.activated then
                observeApp(app or hs.application.frontmostApplication())
                -- Activation needs its own check: switching back to an application whose focused window never
                -- changed does not raise AXFocusedWindowChanged, yet that is the most common way to end up in
                -- front of a window that sits on another screen.
                scheduleWarpCheck()
            end
        end)
        obj.appWatcher:start()
    end
    observeApp(hs.application.frontmostApplication())
    obj.logger.i("Mouse warp enabled")
    if notify then hs.alert.show("MouseWarp: 已启用") end
    return obj
end

--- MouseWarp:stop([notify])
--- Method
--- Disables the auto-warp behavior. Idempotent. When `notify` is truthy, shows a temporary on-screen alert.
--- The watchers stay installed (and keep tracking the frontmost application) so that re-enabling is instant.
function obj:stop(notify)
    if not obj.enabled then return obj end
    obj.enabled = false
    if obj.pendingWarp then
        obj.pendingWarp:stop()
        obj.pendingWarp = nil
    end
    obj.logger.i("Mouse warp disabled")
    if notify then hs.alert.show("MouseWarp: 已禁用") end
    return obj
end

--- MouseWarp:toggle()
--- Method
--- Toggles the auto-warp behavior on or off, showing a temporary on-screen alert.
function obj:toggle()
    if obj.enabled then obj:stop(true) else obj:start(true) end
    return obj
end

local function parseHotkeySpec(spec)
    local mods, key
    if type(spec) == "table" then
        mods, key = spec[1], spec[2]
    elseif type(spec) == "string" then
        local tokens = {}
        for token in spec:gmatch("[^%-]+") do tokens[#tokens + 1] = token end
        key = table.remove(tokens)
        mods = {}
        for _, token in ipairs(tokens) do
            mods[#mods + 1] = MODIFIER_MAP[token:lower()] or token
        end
    end
    return mods, key
end

--- MouseWarp:bindHotkeys(mapping)
--- Method
--- Binds the "toggle" hotkey. Accepts the classic form
--- `{ toggle = { { "ctrl", "alt" }, "m" } }` as well as the string form `{ toggle = "ctrl-alt-m" }`.
function obj:bindHotkeys(mapping)
    if obj.hotkey then
        obj.hotkey:delete()
        obj.hotkey = nil
    end
    local spec = mapping and mapping.toggle
    if not spec then return obj end
    local mods, key = parseHotkeySpec(spec)
    if not (mods and key) then
        obj.logger.e("Invalid toggle hotkey spec: " .. tostring(spec))
        return obj
    end
    obj.hotkey = hs.hotkey.bind(mods, key, function() obj:toggle() end)
    obj.logger.i("Toggle hotkey bound: " .. table.concat(mods, "-") .. "-" .. key)
    return obj
end

return obj
