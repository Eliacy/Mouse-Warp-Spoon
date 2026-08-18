--- === MouseWarp ===
---
--- Warp the mouse cursor to the center of the focused window when it lives on a different physical screen than the cursor.
---
--- In a multi-display setup, switching to an application whose window is on another screen leaves the pointer
--- behind. This Spoon watches for window focus changes and only when the newly focused window and the current
--- cursor position are on different physical screens moves the cursor to the center of that window. If they are
--- on the same screen, the cursor is left untouched.
---
--- See the project README for installation and usage.

local obj = {}
obj.__index = obj

-- Metadata ----------------------------------------------------------------

obj.name = "MouseWarp"
obj.version = "1.0.0"
obj.author = "Elias Soong"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("MouseWarp")

-- Whether automatic warping is currently active.
obj.enabled = false

-- Internal state ------------------------------------------------------------

obj.windowFilter = hs.window.filter.new()
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

local function onWindowFocused(win)
    if not (obj.enabled and win and win:isStandard()) then return end
    -- Focus events can arrive while a transition (Mission Control / Exposé) is still animating the
    -- window frame, so re-check everything after the frame has settled.
    hs.timer.doAfter(0.08, function()
        if not obj.enabled then return end
        if not (win:isValid() and win:isStandard()) then return end
        if obj:sameScreen(win) then return end
        local f = win:frame()
        hs.mouse.setAbsolutePosition({ x = f.x + f.w / 2, y = f.y + f.h / 2 })
        obj.logger.d("Mouse warped to the center of \"" .. (win:title() or "") .. "\"")
    end)
end

--- MouseWarp:start([notify])
--- Method
--- Enables the auto-warp behavior. Idempotent. When `notify` is truthy, shows a temporary on-screen alert.
function obj:start(notify)
    if obj.enabled then return obj end
    obj.windowFilter:subscribe(hs.window.filter.windowFocused, onWindowFocused)
    obj.enabled = true
    obj.logger.i("Mouse warp enabled")
    if notify then hs.alert.show("MouseWarp: 已启用") end
    return obj
end

--- MouseWarp:stop([notify])
--- Method
--- Disables the auto-warp behavior. Idempotent. When `notify` is truthy, shows a temporary on-screen alert.
function obj:stop(notify)
    if not obj.enabled then return obj end
    obj.windowFilter:unsubscribe(onWindowFocused)
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