--- === MouseWarp ===
---
--- Warp the mouse cursor to the center of the focused window when it lives on a different physical screen than the cursor.
---
--- In a multi-display setup, switching to an application whose window is on another screen leaves the pointer
--- behind. This Spoon watches for window focus changes and only when the newly focused window and the current
--- cursor position are on different physical screens moves the cursor to the center of that window. If they are
--- on the same screen, the cursor is left untouched.
---
--- Because subscribing to `hs.window.filter` performs a one-time full scan of all apps/windows (which can jank
--- for a moment), that initialization is deferred until `MouseWarp.initDelay` seconds after the first enable.
---
--- See the project README for installation and usage.

local obj = {}
obj.__index = obj

-- Metadata ----------------------------------------------------------------

obj.name = "MouseWarp"
obj.version = "1.2.0"
obj.author = "Elias Soong"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("MouseWarp")

-- Whether automatic warping is currently active.
obj.enabled = false

-- Delay (in seconds) applied before the one-time window scan runs after the first enable,
-- moving the momentary jank out of the startup moment. Adjust before calling `start()`.
obj.initDelay = 1.0

-- Internal state ------------------------------------------------------------

-- The window filter is created lazily and then kept subscribed for the whole session, so that
-- enable/disable stays an instant flag flip. Subscribing triggers a one-time full scan of all
-- apps/windows, hence the deferred initialization above.
obj.windowFilter = nil
obj.initTimer = nil
obj.hotkey = nil

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

local function onWindowFocused(win)
    if not (obj.enabled and win) then return end
    hs.timer.doAfter(WARP_SETTLE_DELAY, function()
        if not obj.enabled then return end
        -- pcall guards against stale window objects and version differences in the hs.window API:
        -- if a method is unavailable or the window died, simply skip the warp.
        local ok, err = pcall(function()
            if not win:isStandard() then return end
            if obj:sameScreen(win) then return end
            local f = win:frame()
            hs.mouse.setAbsolutePosition({ x = f.x + f.w / 2, y = f.y + f.h / 2 })
            obj.logger.d("Mouse warped to the center of \"" .. (win:title() or "") .. "\"")
        end)
        if not ok then
            obj.logger.d("Warp skipped: " .. tostring(err))
        end
    end)
end

--- MouseWarp:start([notify])
--- Method
--- Enables the auto-warp behavior. Idempotent. When `notify` is truthy, shows a temporary on-screen alert.
--- Enabling is instant; the one-time window scan is scheduled `MouseWarp.initDelay` seconds later and
--- is canceled if the plugin is disabled again before it runs.
function obj:start(notify)
    if obj.enabled then return obj end
    obj.enabled = true
    obj.logger.i("Mouse warp enabled")
    if notify then hs.alert.show("MouseWarp: 已启用") end
    if not obj.windowFilter and not obj.initTimer then
        obj.initTimer = hs.timer.doAfter(obj.initDelay, function()
            obj.initTimer = nil
            if not obj.enabled then return end
            obj.windowFilter = hs.window.filter.new()
            obj.windowFilter:subscribe(hs.window.filter.windowFocused, onWindowFocused)
            obj.logger.i("Window filter initialized")
        end)
    end
    return obj
end

--- MouseWarp:stop([notify])
--- Method
--- Disables the auto-warp behavior. Idempotent. When `notify` is truthy, shows a temporary on-screen alert.
function obj:stop(notify)
    if not obj.enabled then return obj end
    if obj.initTimer then
        obj.initTimer:stop()
        obj.initTimer = nil
    end
    obj.enabled = false
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
