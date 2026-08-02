--[[
    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║    ◐  OVERTURN  ·  Remote Spy  ·  v2.0.0                 ║
    ║                                                           ║
    ║    purple  ·  matte black  ·  fast  ·  extensible        ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝

    https://github.com/burningtire1/Overturn-Spy
    Source: src/  ·  Docs: docs/  ·  Plugins: plugins/

    Required executor globals:
        hookmetamethod  getrawmetatable  getnamecallmethod  newcclosure
]]

-- ── Guard: clean reload if already running
if _G.__Overturn then
    pcall(function() _G.__Overturn._gui:Destroy() end)
    _G.__Overturn = nil
end

-- ─────────────────────────────────────────────────────────────
-- §1  SERVICES
-- ─────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")

local lp = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────
-- §2  THEME
-- ─────────────────────────────────────────────────────────────
local T = {
    Bg          = Color3.fromRGB(10,  9, 16),
    Surface     = Color3.fromRGB(17, 15, 26),
    SurfaceAlt  = Color3.fromRGB(22, 19, 34),
    SurfaceHigh = Color3.fromRGB(28, 24, 44),
    Elevated    = Color3.fromRGB(24, 21, 37),

    Border      = Color3.fromRGB(52, 40, 84),
    BorderSub   = Color3.fromRGB(30, 26, 50),

    Purple      = Color3.fromRGB(139,  92, 246),
    PurpleHi    = Color3.fromRGB(167, 139, 250),
    PurpleLo    = Color3.fromRGB(109,  68, 210),
    PurpleDim   = Color3.fromRGB( 72,  44, 148),
    PurpleBg    = Color3.fromRGB( 22,  14,  48),

    Text        = Color3.fromRGB(228, 220, 255),
    TextSub     = Color3.fromRGB(148, 132, 185),
    TextMuted   = Color3.fromRGB( 82,  72, 118),
    TextCode    = Color3.fromRGB(190, 172, 230),

    Green       = Color3.fromRGB( 74, 222, 128),
    Red         = Color3.fromRGB(248, 113, 113),
    Orange      = Color3.fromRGB(251, 146,  60),

    BadgeRE     = Color3.fromRGB(139,  92, 246),
    BadgeRF     = Color3.fromRGB( 59, 130, 246),
    BadgeURE    = Color3.fromRGB(234,  88,  12),
    BadgeRet    = Color3.fromRGB( 34, 197,  94),
    BadgeSpam   = Color3.fromRGB(234, 179,   8),

    Scrollbar   = Color3.fromRGB(70, 54, 118),

    Font     = Enum.Font.GothamMedium,
    FontBold = Enum.Font.GothamBold,
    FontSemi = Enum.Font.Gotham,
    FontMono = Enum.Font.Code,
}

-- ─────────────────────────────────────────────────────────────
-- §3  CONFIG
-- ─────────────────────────────────────────────────────────────
local CFG = {
    Version    = "2.0.0",
    MaxLogs    = 500,   -- how many entries to keep in memory
    MaxVisible = 100,   -- max rows rendered simultaneously
    AnimTime   = 0.15,
    WinW       = 730,
    WinH       = 480,
    LogH       = 40,
    RebuildMs  = 80,    -- min ms between full list rebuilds (filter changes)

    Spam = {
        enabled      = true,
        rateWindow   = 2.0,   -- measure call rate over this many seconds
        rateLimit    = 20,    -- calls per window before flagging
        dedupMs      = 60,    -- drop identical remote+argsHash within N ms
        action       = "hide",-- "hide" | "block" | "log"
        hysteresis   = 0.6,   -- unflag when rate falls to rateLimit * this
        maxTracked   = 300,   -- max per-remote records before LRU eviction
        whitelist    = {},    -- [path] = true → never flag this remote
    },
}

-- ─────────────────────────────────────────────────────────────
-- §4  EVENTS
-- ─────────────────────────────────────────────────────────────
local Ev = {
    onLog    = Instance.new("BindableEvent"), -- (entry)
    onSpam   = Instance.new("BindableEvent"), -- (path, record)
    onBlock  = Instance.new("BindableEvent"), -- (path)
    onIgnore = Instance.new("BindableEvent"), -- (path)
    onClear  = Instance.new("BindableEvent"), -- ()
    onPause  = Instance.new("BindableEvent"), -- (paused: bool)
}

-- ─────────────────────────────────────────────────────────────
-- §5  STATE
-- ─────────────────────────────────────────────────────────────
local S = {
    logs     = {},
    ignored  = {},   -- [path] = true
    blocked  = {},   -- [path] = true
    paused   = false,
    hooked   = false,
    tab      = "ALL",
    query    = "",
    total    = 0,
    hookOrig = nil,

    dirtyFull   = false, -- needs full list rebuild (filter changed)
    lastRebuild = 0,

    -- Incremental row management
    activeRows  = {},   -- { {entry, frame}, … }  newest-first
    rowCount    = 0,
    rowOrderCtr = 2^31, -- decrements so newer rows sort first
}

-- ─────────────────────────────────────────────────────────────
-- §6  SERIALISER
-- ─────────────────────────────────────────────────────────────
local _ser  -- forward declaration for recursive calls

local _fns = {
    ["nil"]     = function()  return "nil" end,
    boolean     = function(v) return tostring(v) end,
    number      = function(v)
        if v ~= v          then return "0/0 --[[NaN]]" end
        if v ==  math.huge then return  "math.huge"    end
        if v == -math.huge then return "-math.huge"    end
        if v % 1 == 0 and math.abs(v) < 1e15 then
            return tostring(math.floor(v))
        end
        return string.format("%.6g", v)
    end,
    string = function(v)
        local s = v
            :gsub("\\", "\\\\"):gsub('"',  '\\"')
            :gsub("\n", "\\n") :gsub("\r", "\\r")
            :gsub("\t", "\\t")
            :gsub("[%c]", function(c) return ("\\%d"):format(c:byte()) end)
        if #s > 96 then s = s:sub(1, 93) .. "…" end
        return '"' .. s .. '"'
    end,
    table = function(v, d)
        if d >= 3 then return "{…}" end
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n += 1
            if n > 20 then parts[#parts + 1] = "…"; break end
            local key = (type(k) == "string" and k:match("^[%a_][%w_]*$"))
                and k or ("[" .. _ser(k, d + 1) .. "]")
            parts[#parts + 1] = key .. " = " .. _ser(val, d + 1)
        end
        return n == 0 and "{}" or ("{ " .. table.concat(parts, ", ") .. " }")
    end,
    Instance = function(v)
        local parts, cur, lim = {}, v, 28
        while cur and cur ~= game and lim > 0 do
            table.insert(parts, 1, cur.Name)
            cur, lim = cur.Parent, lim - 1
        end
        return cur ~= game and tostring(v) or ("game." .. table.concat(parts, "."))
    end,
    Vector3      = function(v) return ("Vector3.new(%g, %g, %g)"):format(v.X, v.Y, v.Z) end,
    Vector2      = function(v) return ("Vector2.new(%g, %g)"):format(v.X, v.Y) end,
    Vector3int16 = function(v) return ("Vector3int16.new(%d, %d, %d)"):format(v.X, v.Y, v.Z) end,
    Vector2int16 = function(v) return ("Vector2int16.new(%d, %d)"):format(v.X, v.Y) end,
    CFrame = function(v)
        local x, y, z   = v.X, v.Y, v.Z
        local rx, ry, rz = v:ToEulerAnglesXYZ()
        if rx == 0 and ry == 0 and rz == 0 then
            return ("CFrame.new(%g, %g, %g)"):format(x, y, z)
        end
        return ("CFrame.new(%g, %g, %g) * CFrame.Angles(%g, %g, %g)"):format(
            x, y, z, rx, ry, rz)
    end,
    Color3 = function(v)
        return ("Color3.fromRGB(%d, %d, %d)"):format(
            math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
    end,
    UDim2 = function(v)
        return ("UDim2.new(%g, %d, %g, %d)"):format(
            v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    end,
    UDim              = function(v) return ("UDim.new(%g, %d)"):format(v.Scale, v.Offset) end,
    BrickColor        = function(v) return ('BrickColor.new("%s")'):format(v.Name) end,
    EnumItem          = tostring,
    Enum              = tostring,
    NumberRange       = function(v) return ("NumberRange.new(%g, %g)"):format(v.Min, v.Max) end,
    NumberSequence    = function()  return "NumberSequence.new({--[[…]]})" end,
    ColorSequence     = function()  return "ColorSequence.new({--[[…]]})" end,
    RBXScriptSignal   = function()  return "--[[RBXScriptSignal]]" end,
    RBXScriptConnection = function() return "--[[RBXScriptConnection]]" end,
    Ray = function(v)
        local o, d = v.Origin, v.Direction
        return ("Ray.new(Vector3.new(%g,%g,%g), Vector3.new(%g,%g,%g))"):format(
            o.X, o.Y, o.Z, d.X, d.Y, d.Z)
    end,
    TweenInfo = function(v)
        return ("TweenInfo.new(%g, %s, %s, %d, %s, %g)"):format(
            v.Time, tostring(v.EasingStyle), tostring(v.EasingDirection),
            v.RepeatCount, tostring(v.Reverses), v.DelayTime)
    end,
    PhysicalProperties = function(v)
        return ("PhysicalProperties.new(%g, %g, %g)"):format(
            v.Density, v.Friction, v.Elasticity)
    end,
}

_ser = function(v, depth)
    depth = depth or 0
    local fn = _fns[typeof(v)]
    if not fn then return ("--[[%s]]"):format(typeof(v)) end
    local ok, out = pcall(fn, v, depth)
    return ok and out or ("--[[err:%s]]"):format(typeof(v))
end

local function argsStr(args)
    if #args == 0 then return "" end
    local p = table.create(#args)
    for i = 1, #args do p[i] = _ser(args[i]) end
    return table.concat(p, ", ")
end

local function pathOf(inst)
    if not inst then return "nil" end
    local parts, cur, lim = {}, inst, 28
    while cur and cur ~= game and lim > 0 do
        table.insert(parts, 1, cur.Name)
        cur, lim = cur.Parent, lim - 1
    end
    if cur ~= game then return tostring(inst) end
    return "game." .. table.concat(parts, ".")
end

local function toScript(e)
    if not e.remote or not e.remote.Parent then
        return "-- remote was garbage collected"
    end
    local p    = pathOf(e.remote)
    local args = argsStr(e.args)
    if   e.type == "RemoteEvent" or e.type == "UnreliableRemoteEvent" then
        return ("%s:FireServer(%s)"):format(p, args)
    elseif e.type == "RemoteFunction" then
        return ("local result = %s:InvokeServer(%s)"):format(p, args)
    elseif e.type == "ReturnValue" then
        return ("-- Returned: %s"):format(args ~= "" and args or "nil")
    end
    return "-- unknown type: " .. tostring(e.type)
end

-- ─────────────────────────────────────────────────────────────
-- §7  CLIPBOARD
-- ─────────────────────────────────────────────────────────────
local function clip(text)
    if     setclipboard           then pcall(setclipboard, text)
    elseif syn                    then pcall(function() syn.clipboard.set(text) end)
    elseif toclipboard            then pcall(toclipboard, text)
    end
end

-- ─────────────────────────────────────────────────────────────
-- §8  ANTI-SPAM ENGINE
-- src/core/antispam.lua
-- ─────────────────────────────────────────────────────────────
local Spam = {
    _records      = {},   -- [path] = SpamRecord
    _trackedPaths = {},   -- FIFO list for LRU eviction
    _flagCount    = 0,
}

-- djb2-variant: hash serialised args for dedup comparison
local function hashArgs(args)
    local s
    if #args == 0 then
        s = ""
    else
        local lim = math.min(#args, 3)
        local p   = table.create(lim)
        for i = 1, lim do p[i] = _ser(args[i]) end
        s = table.concat(p, "|")
        if #s > 128 then s = s:sub(1, 128) end
    end
    local h = 5381
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 0x7FFFFFFF end
    return h
end

local function spamRecord(path)
    local r = Spam._records[path]
    if r then return r end

    -- LRU eviction when over cap
    if #Spam._trackedPaths >= CFG.Spam.maxTracked then
        local evict = table.remove(Spam._trackedPaths, 1)
        if Spam._records[evict] and Spam._records[evict].flagged then
            Spam._flagCount = math.max(0, Spam._flagCount - 1)
        end
        Spam._records[evict] = nil
    end

    r = { times = {}, lastHash = -1, lastHashT = 0, flagged = false, total = 0, dropped = 0 }
    Spam._records[path] = r
    table.insert(Spam._trackedPaths, path)
    return r
end

-- Returns true if this call should be dropped entirely.
-- Also flags/unflags the remote in Spam._records.
local function spamCheck(path, args)
    local cfg = CFG.Spam
    if not cfg.enabled or cfg.whitelist[path] then return false end

    local r   = spamRecord(path)
    local now = os.clock()
    r.total  += 1

    -- ── Dedup: same hash within dedupMs → silently drop
    local h = hashArgs(args)
    if h == r.lastHash and (now - r.lastHashT) * 1000 < cfg.dedupMs then
        r.dropped += 1
        return true
    end
    r.lastHash  = h
    r.lastHashT = now

    -- ── Rate: slide the window, count recent calls
    local cutoff = now - cfg.rateWindow
    local t, head = r.times, 1
    while head <= #t and t[head] < cutoff do head += 1 end
    if head > 1 then
        local n = #t - head + 1
        for i = 1, n   do t[i] = t[i + head - 1] end
        for i = n + 1, #t do t[i] = nil end
    end
    t[#t + 1] = now

    -- ── Flag / unflag with hysteresis
    local rate = #t
    if not r.flagged and rate > cfg.rateLimit then
        r.flagged       = true
        Spam._flagCount += 1
        task.defer(function() Ev.onSpam:Fire(path, r) end)
    elseif r.flagged and rate <= math.floor(cfg.rateLimit * cfg.hysteresis) then
        r.flagged       = false
        Spam._flagCount = math.max(0, Spam._flagCount - 1)
    end

    if r.flagged and cfg.action == "block" then
        r.dropped += 1
        return true
    end

    return false
end

-- ─────────────────────────────────────────────────────────────
-- §9  HOOK ENGINE
-- src/core/hooks.lua
-- ─────────────────────────────────────────────────────────────
local function addEntry(data)
    if S.paused or not data.remote then return end

    local ok, path = pcall(pathOf, data.remote)
    if not ok then return end

    if S.blocked[path] then return end
    if spamCheck(path, data.args or {}) then return end

    S.total += 1

    local rec = Spam._records[path]
    local entry = {
        id     = S.total,
        type   = data.type,
        remote = data.remote,
        path   = path,
        name   = data.remote.Name,
        args   = data.args or {},
        time   = data.time or os.clock(),
        spam   = rec and rec.flagged or false,
        linked = data.linked,
    }

    table.insert(S.logs, 1, entry)
    if #S.logs > CFG.MaxLogs then table.remove(S.logs) end

    task.defer(function() Ev.onLog:Fire(entry) end)
end

local function initHooks()
    if not (hookmetamethod and getrawmetatable and getnamecallmethod and newcclosure) then
        warn("[Overturn] Missing executor globals — hooks unavailable")
        return
    end

    local mt   = getrawmetatable(game)
    local orig = mt.__namecall
    S.hookOrig = orig

    hookmetamethod(mt, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if not S.paused then
            local cls = typeof(self) == "Instance" and self.ClassName or nil

            if method == "FireServer" then
                if cls == "RemoteEvent" then
                    addEntry({ type = "RemoteEvent", remote = self, args = {...} })
                elseif cls == "UnreliableRemoteEvent" then
                    addEntry({ type = "UnreliableRemoteEvent", remote = self, args = {...} })
                end

            elseif method == "InvokeServer" and cls == "RemoteFunction" then
                local inv = { type = "RemoteFunction", remote = self, args = {...}, time = os.clock() }
                addEntry(inv)

                local ret = table.pack(orig(self, ...))
                if ret.n > 0 then
                    local retArgs = table.create(ret.n)
                    for i = 1, ret.n do retArgs[i] = ret[i] end
                    addEntry({ type = "ReturnValue", remote = self, args = retArgs, linked = inv })
                end
                return table.unpack(ret, 1, ret.n)
            end
        end

        return orig(self, ...)
    end))

    S.hooked = true
end

local function destroyHooks()
    if S.hooked and S.hookOrig then
        pcall(function()
            hookmetamethod(getrawmetatable(game), "__namecall", S.hookOrig)
        end)
        S.hooked = false
    end
end

-- ─────────────────────────────────────────────────────────────
-- §10  UI HELPERS
-- src/ui/helpers.lua
-- ─────────────────────────────────────────────────────────────
local function New(cls, props)
    local i = Instance.new(cls)
    for k, v in pairs(props) do
        if k ~= "Parent" then i[k] = v end
    end
    if props.Parent then i.Parent = props.Parent end
    return i
end

local function corner(r, p)   New("UICorner", { CornerRadius = UDim.new(0, r), Parent = p }) end
local function stroke(t, c, p) New("UIStroke", { Thickness = t, Color = c, Parent = p }) end
local function pad(l, r, top, bot, p)
    New("UIPadding", {
        PaddingLeft   = UDim.new(0, l   or 0),
        PaddingRight  = UDim.new(0, r   or 0),
        PaddingTop    = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bot or 0),
        Parent = p,
    })
end

local function tw(obj, goal, dur, style, dir)
    TweenService:Create(obj,
        TweenInfo.new(
            dur   or CFG.AnimTime,
            style or Enum.EasingStyle.Quart,
            dir   or Enum.EasingDirection.Out
        ), goal
    ):Play()
end

-- ─────────────────────────────────────────────────────────────
-- §11  ROOT GUI
-- ─────────────────────────────────────────────────────────────
local guiHost = (pcall(gethui) and gethui()) or CoreGui
local gui = New("ScreenGui", {
    Name           = "OverturnSpy",
    DisplayOrder   = 999,
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent         = guiHost,
})

-- ─────────────────────────────────────────────────────────────
-- §12  WINDOW
-- src/ui/window.lua
-- ─────────────────────────────────────────────────────────────
local vp = workspace.CurrentCamera.ViewportSize

-- Offset-based position so drag works correctly from frame 0
local win = New("Frame", {
    Name             = "Window",
    Size             = UDim2.fromOffset(CFG.WinW, CFG.WinH),
    Position         = UDim2.fromOffset(
        math.floor((vp.X - CFG.WinW) / 2),
        math.floor((vp.Y - CFG.WinH) / 2)
    ),
    BackgroundColor3 = T.Surface,
    ClipsDescendants = true,
    Parent           = gui,
})
corner(10, win)
stroke(1, T.Border, win)

New("UIGradient", {
    Color    = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(28, 18, 52)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(15, 12, 26)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(10,  9, 16)),
    }),
    Rotation = 128,
    Parent   = win,
})

-- Nebula glow top-left
New("ImageLabel", {
    Size                   = UDim2.fromOffset(420, 420),
    Position               = UDim2.fromOffset(-160, -160),
    BackgroundTransparency = 1,
    Image                  = "rbxassetid://6014261993",
    ImageColor3            = T.Purple,
    ImageTransparency      = 0.90,
    ZIndex                 = 1,
    Parent                 = win,
})
-- Dim accent bottom-right
New("ImageLabel", {
    Size                   = UDim2.fromOffset(280, 280),
    Position               = UDim2.new(1, -100, 1, -100),
    BackgroundTransparency = 1,
    Image                  = "rbxassetid://6014261993",
    ImageColor3            = T.PurpleLo,
    ImageTransparency      = 0.94,
    ZIndex                 = 1,
    Parent                 = win,
})

-- ─────────────────────────────────────────────────────────────
-- §13  TITLE BAR
-- src/ui/titlebar.lua
-- ─────────────────────────────────────────────────────────────
local titleBar = New("Frame", {
    Size                   = UDim2.new(1, 0, 0, 44),
    BackgroundTransparency = 1,
    ZIndex                 = 4,
    Parent                 = win,
})

-- ── Crescent Moon Logo
local moonWrap = New("Frame", {
    Size                   = UDim2.fromOffset(28, 28),
    Position               = UDim2.fromOffset(13, 8),
    BackgroundTransparency = 1,
    ZIndex                 = 5,
    Parent                 = titleBar,
})
do
    local lit = New("Frame", {
        Size             = UDim2.fromScale(1, 1),
        BackgroundColor3 = T.PurpleHi,
        BorderSizePixel  = 0,
        ZIndex           = 5,
        Parent           = moonWrap,
    })
    corner(99, lit)

    -- The offset shadow circle creates the crescent shape
    local shadow = New("Frame", {
        Size             = UDim2.fromOffset(23, 23),
        Position         = UDim2.fromOffset(9, -2),
        BackgroundColor3 = Color3.fromRGB(22, 16, 44),
        BorderSizePixel  = 0,
        ZIndex           = 6,
        Parent           = moonWrap,
    })
    corner(99, shadow)

    -- Pixel stars around the moon
    for _, s in ipairs({ {26,1,3,0.10}, {23,13,2,0.30}, {29,8,2,0.20} }) do
        local dot = New("Frame", {
            Size             = UDim2.fromOffset(s[3], s[3]),
            Position         = UDim2.fromOffset(s[1], s[2]),
            BackgroundColor3 = T.PurpleHi,
            BackgroundTransparency = s[4],
            BorderSizePixel  = 0,
            ZIndex           = 7,
            Parent           = moonWrap,
        })
        corner(99, dot)
    end
end

New("TextLabel", {
    Text             = "OVERTURN",
    Font             = T.FontBold,
    TextSize         = 13,
    TextColor3       = T.Text,
    TextXAlignment   = Enum.TextXAlignment.Left,
    Size             = UDim2.fromOffset(100, 20),
    Position         = UDim2.fromOffset(48, 7),
    BackgroundTransparency = 1,
    ZIndex           = 5,
    Parent           = titleBar,
})
New("TextLabel", {
    Text             = "v" .. CFG.Version,
    Font             = T.FontSemi,
    TextSize         = 9,
    TextColor3       = T.TextMuted,
    TextXAlignment   = Enum.TextXAlignment.Left,
    Size             = UDim2.fromOffset(48, 13),
    Position         = UDim2.fromOffset(118, 17),
    BackgroundTransparency = 1,
    ZIndex           = 5,
    Parent           = titleBar,
})

-- ── Control buttons
local ctrlRow = New("Frame", {
    Size             = UDim2.fromOffset(96, 26),
    Position         = UDim2.new(1, -104, 0, 9),
    BackgroundTransparency = 1,
    ZIndex           = 5,
    Parent           = titleBar,
})

local function mkCtrlBtn(x, bg, icon, iconCol)
    local wrap = New("Frame", {
        Size             = UDim2.fromOffset(26, 26),
        Position         = UDim2.fromOffset(x, 0),
        BackgroundColor3 = bg,
        BackgroundTransparency = 0.35,
        ZIndex           = 5,
        Parent           = ctrlRow,
    })
    corner(99, wrap)
    local lbl = New("TextLabel", {
        Text             = icon,
        Font             = T.FontBold,
        TextSize         = 10,
        TextColor3       = iconCol or T.TextSub,
        Size             = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex           = 6,
        Parent           = wrap,
    })
    local btn = New("TextButton", {
        Text             = "",
        Size             = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        AutoButtonColor  = false,
        ZIndex           = 7,
        Parent           = wrap,
    })
    btn.MouseEnter:Connect(function() tw(wrap, { BackgroundTransparency = 0    }, 0.08) end)
    btn.MouseLeave:Connect(function() tw(wrap, { BackgroundTransparency = 0.35 }, 0.10) end)
    return btn, wrap, lbl
end

local pauseBtn, pauseBg, pauseLbl = mkCtrlBtn( 0, T.PurpleDim,                     "⏸", T.PurpleHi)
local miniBtn                     = (mkCtrlBtn(34, T.SurfaceHigh,                   "─",  T.TextSub))
local closeBtn                    = (mkCtrlBtn(68, Color3.fromRGB(130, 35, 35),     "✕",  T.Red))

New("Frame", {
    Size             = UDim2.new(1, -24, 0, 1),
    Position         = UDim2.fromOffset(12, 44),
    BackgroundColor3 = T.BorderSub,
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = win,
})

-- ─────────────────────────────────────────────────────────────
-- §14  TAB BAR
-- src/ui/tabs.lua
-- ─────────────────────────────────────────────────────────────
local tabBar = New("Frame", {
    Size                   = UDim2.new(1, -24, 0, 32),
    Position               = UDim2.fromOffset(12, 52),
    BackgroundTransparency = 1,
    ZIndex                 = 3,
    Parent                 = win,
})
New("UIListLayout", {
    FillDirection     = Enum.FillDirection.Horizontal,
    Padding           = UDim.new(0, 3),
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Parent            = tabBar,
})

local TABS = {
    { id = "ALL",        label = "All"        },
    { id = "REMOTES",    label = "Events"     },
    { id = "FUNCTIONS",  label = "Functions"  },
    { id = "UNRELIABLE", label = "Unreliable" },
    { id = "SPAM",       label = "Spam"       },
    { id = "BLOCKED",    label = "Blocked"    },
}

local tabWidgets = {}   -- [id] = { btn, indicator, badge? }
local customTabs = {}   -- plugin-injected tabs

local function buildTabWidget(def, parent)
    local active = S.tab == def.id
    local btn = New("TextButton", {
        Name             = def.id,
        Size             = UDim2.fromOffset(0, 28),
        AutomaticSize    = Enum.AutomaticSize.X,
        BackgroundColor3 = active and T.PurpleBg or T.Surface,
        BackgroundTransparency = active and 0 or 0.55,
        Text             = def.label,
        Font             = T.Font,
        TextSize         = 11,
        TextColor3       = active and T.PurpleHi or T.TextSub,
        AutoButtonColor  = false,
        ZIndex           = 3,
        Parent           = parent or tabBar,
    })
    corner(6, btn)
    pad(10, 10, 0, 0, btn)

    local indicator = New("Frame", {
        Size             = UDim2.new(1, -12, 0, 2),
        Position         = UDim2.new(0, 6, 1, -4),
        BackgroundColor3 = T.Purple,
        BackgroundTransparency = active and 0 or 1,
        BorderSizePixel  = 0,
        ZIndex           = 4,
        Parent           = btn,
    })
    corner(2, indicator)

    -- Count badge (Spam tab only)
    local badge = nil
    if def.id == "SPAM" then
        badge = New("TextLabel", {
            Text             = "0",
            Font             = T.FontBold,
            TextSize         = 7,
            TextColor3       = Color3.new(1, 1, 1),
            Size             = UDim2.fromOffset(14, 11),
            Position         = UDim2.new(1, -2, 0, -3),
            BackgroundColor3 = T.Orange,
            ZIndex           = 5,
            Visible          = false,
            Parent           = btn,
        })
        corner(99, badge)
    end

    return { btn = btn, indicator = indicator, badge = badge }
end

for _, def in ipairs(TABS) do
    tabWidgets[def.id] = buildTabWidget(def)
end

local function switchTab(id)
    if S.tab == id then return end
    local prev = tabWidgets[S.tab] or customTabs[S.tab]
    if prev then
        tw(prev.btn,       { BackgroundTransparency = 0.55, TextColor3 = T.TextSub }, 0.12)
        tw(prev.indicator, { BackgroundTransparency = 1    }, 0.12)
    end
    S.tab       = id
    S.dirtyFull = true
    local next = tabWidgets[id] or customTabs[id]
    if next then
        next.btn.BackgroundColor3 = T.PurpleBg
        tw(next.btn,       { BackgroundTransparency = 0,   TextColor3 = T.PurpleHi }, 0.12)
        tw(next.indicator, { BackgroundTransparency = 0    }, 0.12)
    end
end

for _, def in ipairs(TABS) do
    local w = tabWidgets[def.id]
    w.btn.MouseButton1Click:Connect(function() switchTab(def.id) end)
    w.btn.MouseEnter:Connect(function()
        if S.tab ~= def.id then tw(w.btn, { TextColor3 = T.Text    }, 0.08) end
    end)
    w.btn.MouseLeave:Connect(function()
        if S.tab ~= def.id then tw(w.btn, { TextColor3 = T.TextSub }, 0.10) end
    end)
end

local function updateSpamBadge()
    local w = tabWidgets["SPAM"]
    if not (w and w.badge) then return end
    local n = Spam._flagCount
    w.badge.Text    = tostring(n)
    w.badge.Visible = n > 0
end
Ev.onSpam.Event:Connect(function() updateSpamBadge() end)

-- ─────────────────────────────────────────────────────────────
-- §15  SEARCH & ACTION BAR
-- src/ui/search.lua
-- ─────────────────────────────────────────────────────────────
local searchRow = New("Frame", {
    Size                   = UDim2.new(1, -24, 0, 30),
    Position               = UDim2.fromOffset(12, 92),
    BackgroundTransparency = 1,
    ZIndex                 = 3,
    Parent                 = win,
})

local searchWrap = New("Frame", {
    Size             = UDim2.new(1, -114, 1, 0),
    BackgroundColor3 = T.Elevated,
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = searchRow,
})
corner(6, searchWrap)
stroke(1, T.BorderSub, searchWrap)

New("TextLabel", {
    Text             = "⌕",
    Font             = T.Font,
    TextSize         = 15,
    TextColor3       = T.TextMuted,
    Size             = UDim2.fromOffset(26, 30),
    BackgroundTransparency = 1,
    ZIndex           = 4,
    Parent           = searchWrap,
})
local searchBox = New("TextBox", {
    PlaceholderText    = "Filter by name or path…",
    PlaceholderColor3  = T.TextMuted,
    Text               = "",
    Font               = T.Font,
    TextSize           = 11,
    TextColor3         = T.Text,
    TextXAlignment     = Enum.TextXAlignment.Left,
    Size               = UDim2.new(1, -30, 1, 0),
    Position           = UDim2.fromOffset(26, 0),
    BackgroundTransparency = 1,
    ClearTextOnFocus   = false,
    ZIndex             = 4,
    Parent             = searchWrap,
})

local function mkActionBtn(label, xFromRight)
    local b = New("TextButton", {
        Text             = label,
        Font             = T.Font,
        TextSize         = 11,
        TextColor3       = T.TextSub,
        Size             = UDim2.fromOffset(54, 30),
        Position         = UDim2.new(1, xFromRight, 0, 0),
        BackgroundColor3 = T.Elevated,
        AutoButtonColor  = false,
        ZIndex           = 3,
        Parent           = searchRow,
    })
    corner(6, b)
    stroke(1, T.BorderSub, b)
    b.MouseEnter:Connect(function() tw(b, { TextColor3 = T.Text    }, 0.08) end)
    b.MouseLeave:Connect(function() tw(b, { TextColor3 = T.TextSub }, 0.10) end)
    return b
end

local clearBtn  = mkActionBtn("Clear",  -110)
local exportBtn = mkActionBtn("Export",  -54)

-- ─────────────────────────────────────────────────────────────
-- §16  LOG LIST  (incremental row management)
-- src/ui/loglist.lua
-- ─────────────────────────────────────────────────────────────

-- Forward declaration — assigned in §18 (Context Menu)
local showCtx

local logWrap = New("Frame", {
    Size             = UDim2.new(1, -24, 1, -166),
    Position         = UDim2.fromOffset(12, 130),
    BackgroundColor3 = T.Bg,
    BorderSizePixel  = 0,
    ClipsDescendants = true,
    ZIndex           = 2,
    Parent           = win,
})
corner(8, logWrap)
stroke(1, T.BorderSub, logWrap)

local logScroll = New("ScrollingFrame", {
    Size                   = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    ScrollBarThickness     = 3,
    ScrollBarImageColor3   = T.Scrollbar,
    ScrollBarImageTransparency = 0.15,
    CanvasSize             = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize    = Enum.AutomaticSize.Y,
    ZIndex                 = 2,
    Parent                 = logWrap,
})
New("UIListLayout", {
    Padding   = UDim.new(0, 2),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent    = logScroll,
})
pad(4, 4, 4, 4, logScroll)

local emptyLabel = New("TextLabel", {
    Text             = "No remotes captured yet\nFire a remote and it will appear here",
    Font             = T.FontSemi,
    TextSize         = 12,
    TextColor3       = T.TextMuted,
    TextXAlignment   = Enum.TextXAlignment.Center,
    Size             = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex           = 3,
    Visible          = true,
    Parent           = logWrap,
})

local TYPE_META = {
    RemoteEvent           = { label = "RE",  color = T.BadgeRE  },
    RemoteFunction        = { label = "RF",  color = T.BadgeRF  },
    UnreliableRemoteEvent = { label = "URE", color = T.BadgeURE },
    ReturnValue           = { label = "RET", color = T.BadgeRet },
}

local function buildRow(entry, order)
    local meta   = TYPE_META[entry.type] or { label = "?", color = T.TextMuted }
    local isSpam = entry.spam
        or (Spam._records[entry.path] and Spam._records[entry.path].flagged)

    local row = New("Frame", {
        Name             = tostring(entry.id),
        Size             = UDim2.new(1, 0, 0, CFG.LogH),
        BackgroundColor3 = T.SurfaceAlt,
        BackgroundTransparency = 0.5,
        BorderSizePixel  = 0,
        LayoutOrder      = order,
        ZIndex           = 3,
        Parent           = logScroll,
    })
    corner(6, row)

    local hov = New("Frame", {
        Size             = UDim2.fromScale(1, 1),
        BackgroundColor3 = isSpam and T.Orange or T.Purple,
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        ZIndex           = 3,
        Parent           = row,
    })
    corner(6, hov)

    -- Left accent stripe (colour reflects type or spam state)
    local accentColor = isSpam and T.BadgeSpam or meta.color
    local acc = New("Frame", {
        Size             = UDim2.new(0, 3, 1, -14),
        Position         = UDim2.fromOffset(7, 7),
        BackgroundColor3 = accentColor,
        BorderSizePixel  = 0,
        ZIndex           = 4,
        Parent           = row,
    })
    corner(2, acc)

    -- Type / spam badge
    local badgeLabel = isSpam and "SPAM" or meta.label
    local badgeColor = isSpam and T.BadgeSpam or meta.color
    local pill = New("Frame", {
        Size             = UDim2.fromOffset(isSpam and 38 or 34, 16),
        Position         = UDim2.fromOffset(18, 12),
        BackgroundColor3 = badgeColor,
        ZIndex           = 4,
        Parent           = row,
    })
    corner(4, pill)
    New("TextLabel", {
        Text             = badgeLabel,
        Font             = T.FontBold,
        TextSize         = 8,
        TextColor3       = Color3.new(1, 1, 1),
        Size             = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex           = 5,
        Parent           = pill,
    })

    New("TextLabel", {
        Text             = entry.name,
        Font             = T.FontBold,
        TextSize         = 11,
        TextColor3       = T.Text,
        TextXAlignment   = Enum.TextXAlignment.Left,
        TextTruncate     = Enum.TextTruncate.AtEnd,
        Size             = UDim2.new(0.28, 0, 0, 16),
        Position         = UDim2.fromOffset(62, 5),
        BackgroundTransparency = 1,
        ZIndex           = 4,
        Parent           = row,
    })

    New("TextLabel", {
        Text             = entry.path,
        Font             = T.FontMono,
        TextSize         = 8,
        TextColor3       = T.TextMuted,
        TextXAlignment   = Enum.TextXAlignment.Left,
        TextTruncate     = Enum.TextTruncate.AtEnd,
        Size             = UDim2.new(0.5, 0, 0, 11),
        Position         = UDim2.fromOffset(62, 23),
        BackgroundTransparency = 1,
        ZIndex           = 4,
        Parent           = row,
    })

    local preview = argsStr(entry.args)
    if #preview > 60 then preview = preview:sub(1, 57) .. "…" end
    New("TextLabel", {
        Text             = #entry.args > 0 and preview or "—",
        Font             = T.FontMono,
        TextSize         = 9,
        TextColor3       = #entry.args > 0 and T.TextCode or T.TextMuted,
        TextXAlignment   = Enum.TextXAlignment.Left,
        TextTruncate     = Enum.TextTruncate.AtEnd,
        Size             = UDim2.new(1, -310, 1, -8),
        Position         = UDim2.fromOffset(238, 4),
        BackgroundTransparency = 1,
        ZIndex           = 4,
        Parent           = row,
    })

    local wallTime = os.time() - (os.clock() - entry.time)
    New("TextLabel", {
        Text             = os.date("%H:%M:%S", math.floor(wallTime)),
        Font             = T.FontSemi,
        TextSize         = 9,
        TextColor3       = T.TextMuted,
        TextXAlignment   = Enum.TextXAlignment.Right,
        Size             = UDim2.fromOffset(60, CFG.LogH),
        Position         = UDim2.new(1, -66, 0, 0),
        BackgroundTransparency = 1,
        ZIndex           = 4,
        Parent           = row,
    })

    if S.ignored[entry.path] then
        local ig = New("TextLabel", {
            Text             = "ignored",
            Font             = T.FontSemi,
            TextSize         = 7,
            TextColor3       = T.TextMuted,
            Size             = UDim2.fromOffset(44, 13),
            Position         = UDim2.new(1, -134, 0.5, -6.5),
            BackgroundColor3 = T.SurfaceHigh,
            BorderSizePixel  = 0,
            ZIndex           = 4,
            Parent           = row,
        })
        corner(4, ig)
    end

    local clk = New("TextButton", {
        Text             = "",
        Size             = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        AutoButtonColor  = false,
        ZIndex           = 8,
        Parent           = row,
    })

    clk.MouseEnter:Connect(function() tw(hov, { BackgroundTransparency = 0.91 }, 0.08) end)
    clk.MouseLeave:Connect(function() tw(hov, { BackgroundTransparency = 1    }, 0.10) end)
    clk.MouseButton1Click:Connect(function()
        clip(toScript(entry))
        tw(hov, { BackgroundTransparency = 0.75 }, 0.05)
        task.delay(0.15, function() tw(hov, { BackgroundTransparency = 1 }, 0.20) end)
    end)
    clk.MouseButton2Click:Connect(function()
        local m = lp:GetMouse()
        showCtx(entry, Vector2.new(m.X, m.Y))
    end)

    row.BackgroundTransparency = 1
    task.spawn(function() tw(row, { BackgroundTransparency = 0.5 }, 0.13) end)

    return row
end

-- Determines whether an entry matches the current tab + search query
local function passesFilter(entry)
    local tab = S.tab
    local ok  = false

    if tab == "ALL" then
        ok = not S.ignored[entry.path]
            and not (entry.spam and CFG.Spam.action == "hide")
    elseif tab == "REMOTES" then
        ok = entry.type == "RemoteEvent" and not S.ignored[entry.path]
    elseif tab == "FUNCTIONS" then
        ok = (entry.type == "RemoteFunction" or entry.type == "ReturnValue")
            and not S.ignored[entry.path]
    elseif tab == "UNRELIABLE" then
        ok = entry.type == "UnreliableRemoteEvent" and not S.ignored[entry.path]
    elseif tab == "SPAM" then
        local rec = Spam._records[entry.path]
        ok = entry.spam or (rec and rec.flagged) or false
    elseif tab == "BLOCKED" then
        ok = (S.blocked[entry.path] or S.ignored[entry.path]) == true
    else
        -- Plugin-added tab
        local ct = customTabs[tab]
        ok = ct and ct.filter and ct.filter(entry) or false
    end

    if not ok then return false end

    local q = S.query
    if q == "" then return true end
    q = q:lower()
    return entry.path:lower():find(q, 1, true) ~= nil
        or entry.name:lower():find(q, 1, true) ~= nil
end

-- Full rebuild: destroy all rows, recreate matching entries from scratch
local function rebuildAll()
    for _, r in ipairs(S.activeRows) do
        if r.frame and r.frame.Parent then r.frame:Destroy() end
    end
    table.clear(S.activeRows)
    S.rowCount    = 0
    S.rowOrderCtr = 2^31

    local shown = 0
    for _, e in ipairs(S.logs) do
        if shown >= CFG.MaxVisible then break end
        if passesFilter(e) then
            shown          += 1
            S.rowOrderCtr  -= 1
            S.activeRows[shown] = { entry = e, frame = buildRow(e, S.rowOrderCtr) }
        end
    end
    S.rowCount     = shown
    emptyLabel.Visible = shown == 0
end

-- Prepend a single entry without rebuilding the whole list.
-- O(1) row creation regardless of total log count.
local function prependEntry(entry)
    if not passesFilter(entry) then return end

    S.rowOrderCtr -= 1
    local frame = buildRow(entry, S.rowOrderCtr)

    table.insert(S.activeRows, 1, { entry = entry, frame = frame })
    S.rowCount += 1

    -- Trim oldest row when over the visible cap
    if S.rowCount > CFG.MaxVisible then
        local tail = table.remove(S.activeRows)
        if tail and tail.frame and tail.frame.Parent then
            tail.frame:Destroy()
        end
        S.rowCount = CFG.MaxVisible
    end

    emptyLabel.Visible = false
end

-- ─────────────────────────────────────────────────────────────
-- §17  STATUS BAR
-- src/ui/statusbar.lua
-- ─────────────────────────────────────────────────────────────
local statusBar = New("Frame", {
    Size                   = UDim2.new(1, -24, 0, 26),
    Position               = UDim2.new(0, 12, 1, -30),
    BackgroundTransparency = 1,
    ZIndex                 = 3,
    Parent                 = win,
})
New("Frame", {
    Size             = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = T.BorderSub,
    BorderSizePixel  = 0,
    ZIndex           = 3,
    Parent           = statusBar,
})

local countLabel = New("TextLabel", {
    Text             = "0 remotes",
    Font             = T.FontSemi,
    TextSize         = 10,
    TextColor3       = T.TextMuted,
    TextXAlignment   = Enum.TextXAlignment.Left,
    Size             = UDim2.fromOffset(280, 26),
    BackgroundTransparency = 1,
    ZIndex           = 3,
    Parent           = statusBar,
})

local livePill = New("Frame", {
    Size             = UDim2.fromOffset(70, 18),
    Position         = UDim2.new(1, -72, 0.5, -9),
    BackgroundColor3 = T.PurpleBg,
    ZIndex           = 3,
    Parent           = statusBar,
})
corner(99, livePill)

local liveDot = New("Frame", {
    Size             = UDim2.fromOffset(5, 5),
    Position         = UDim2.fromOffset(6, 6.5),
    BackgroundColor3 = T.Green,
    BorderSizePixel  = 0,
    ZIndex           = 4,
    Parent           = livePill,
})
corner(99, liveDot)

local liveText = New("TextLabel", {
    Text             = "LIVE",
    Font             = T.FontBold,
    TextSize         = 9,
    TextColor3       = T.Green,
    Size             = UDim2.new(1, -18, 1, 0),
    Position         = UDim2.fromOffset(15, 0),
    BackgroundTransparency = 1,
    ZIndex           = 4,
    Parent           = livePill,
})

local function updateCountLabel()
    countLabel.Text = ("%d shown · %d total"):format(S.rowCount, S.total)
end

-- ─────────────────────────────────────────────────────────────
-- §18  CONTEXT MENU
-- src/ui/ctxmenu.lua
-- ─────────────────────────────────────────────────────────────
local ctxMenu = New("Frame", {
    Name             = "ContextMenu",
    Size             = UDim2.fromOffset(196, 0),
    AutomaticSize    = Enum.AutomaticSize.Y,
    BackgroundColor3 = T.Elevated,
    Visible          = false,
    ZIndex           = 20,
    Parent           = gui,
})
corner(8, ctxMenu)
stroke(1, T.Border, ctxMenu)
New("UIListLayout", { Parent = ctxMenu })
pad(0, 0, 4, 4, ctxMenu)

New("ImageLabel", {
    Size                   = UDim2.new(1, 24, 1, 24),
    Position               = UDim2.fromOffset(-12, -12),
    BackgroundTransparency = 1,
    Image                  = "rbxassetid://6014261993",
    ImageColor3            = Color3.new(0, 0, 0),
    ImageTransparency      = 0.65,
    ZIndex                 = 19,
    Parent                 = ctxMenu,
})

local CTX = {
    { id = "copy_script", label = "Copy as Script"      },
    { id = "copy_path",   label = "Copy Path"           },
    { id = "copy_args",   label = "Copy Arguments"      },
    { sep = true },
    { id = "ignore",      label = "Ignore Remote"       },
    { id = "block",       label = "Block Remote"        },
    { id = "spam_wl",     label = "Whitelist (no spam)" },
    { sep = true },
    { id = "unignore",    label = "Un-ignore"           },
    { id = "unblock",     label = "Un-block"            },
    { id = "spam_reset",  label = "Reset Spam Stats"    },
}

local ctxBtns  = {}
local ctxEntry = nil

for _, def in ipairs(CTX) do
    if def.sep then
        New("Frame", {
            Size             = UDim2.new(1, -16, 0, 1),
            BackgroundColor3 = T.BorderSub,
            BorderSizePixel  = 0,
            ZIndex           = 21,
            Parent           = ctxMenu,
        })
    else
        local b = New("TextButton", {
            Name             = def.id,
            Text             = def.label,
            Font             = T.Font,
            TextSize         = 11,
            TextColor3       = T.TextSub,
            TextXAlignment   = Enum.TextXAlignment.Left,
            Size             = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = T.Purple,
            BackgroundTransparency = 1,
            AutoButtonColor  = false,
            ZIndex           = 21,
            Parent           = ctxMenu,
        })
        pad(12, 8, 0, 0, b)
        b.MouseEnter:Connect(function()
            tw(b, { BackgroundTransparency = 0.84, TextColor3 = T.Text    }, 0.07)
        end)
        b.MouseLeave:Connect(function()
            tw(b, { BackgroundTransparency = 1,    TextColor3 = T.TextSub }, 0.10)
        end)
        ctxBtns[def.id] = b
    end
end

-- Now assign the forward-declared showCtx
showCtx = function(entry, pos)
    ctxEntry = entry
    local cvp = workspace.CurrentCamera.ViewportSize
    ctxMenu.Position = UDim2.fromOffset(
        math.min(pos.X + 2, cvp.X - 204),
        math.min(pos.Y + 2, cvp.Y - 248)
    )
    ctxMenu.Visible = true
end

local function hideCtx()
    ctxMenu.Visible = false
    ctxEntry = nil
end

local function handleCtx(id)
    local e = ctxEntry
    hideCtx()
    if not e then return end

    if     id == "copy_script" then clip(toScript(e))
    elseif id == "copy_path"   then clip(e.path)
    elseif id == "copy_args"   then clip(argsStr(e.args))
    elseif id == "ignore"      then
        S.ignored[e.path] = true
        S.dirtyFull = true
        Ev.onIgnore:Fire(e.path)
    elseif id == "block"       then
        S.blocked[e.path] = true
        S.dirtyFull = true
        Ev.onBlock:Fire(e.path)
    elseif id == "unignore"    then S.ignored[e.path] = nil;  S.dirtyFull = true
    elseif id == "unblock"     then S.blocked[e.path] = nil;  S.dirtyFull = true
    elseif id == "spam_wl"     then CFG.Spam.whitelist[e.path] = true
    elseif id == "spam_reset"  then
        Spam._records[e.path] = nil
        for i, p in ipairs(Spam._trackedPaths) do
            if p == e.path then table.remove(Spam._trackedPaths, i); break end
        end
        S.dirtyFull = true
    end
end

for id, b in pairs(ctxBtns) do
    b.MouseButton1Click:Connect(function() handleCtx(id) end)
end
UserInputService.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 and ctxMenu.Visible then
        hideCtx()
    end
end)

-- ─────────────────────────────────────────────────────────────
-- §19  TOAST NOTIFICATIONS
-- src/ui/toast.lua
-- ─────────────────────────────────────────────────────────────
local toastQueue  = {}
local toastBusy   = false

local function showToast(text, dur, col)
    table.insert(toastQueue, { text = text, dur = dur or 2.2, col = col or T.Purple })
    if toastBusy then return end
    toastBusy = true

    task.spawn(function()
        while #toastQueue > 0 do
            local item = table.remove(toastQueue, 1)
            local t = New("Frame", {
                Size             = UDim2.fromOffset(0, 32),
                AutomaticSize    = Enum.AutomaticSize.X,
                Position         = UDim2.new(0.5, 0, 1, 50),
                AnchorPoint      = Vector2.new(0.5, 1),
                BackgroundColor3 = item.col,
                BackgroundTransparency = 0.12,
                ZIndex           = 30,
                Parent           = win,
            })
            corner(8, t)
            pad(14, 14, 0, 0, t)
            New("TextLabel", {
                Text             = item.text,
                Font             = T.FontBold,
                TextSize         = 11,
                TextColor3       = Color3.new(1, 1, 1),
                Size             = UDim2.fromOffset(0, 32),
                AutomaticSize    = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                ZIndex           = 31,
                Parent           = t,
            })
            tw(t, { Position = UDim2.new(0.5, 0, 1, -10) }, 0.22,
                Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            task.wait(item.dur)
            tw(t, { Position = UDim2.new(0.5, 0, 1, 50), BackgroundTransparency = 1 }, 0.18)
            task.wait(0.22)
            t:Destroy()
        end
        toastBusy = false
    end)
end

-- ─────────────────────────────────────────────────────────────
-- §20  INTERACTIONS
-- src/ui/interactions.lua
-- ─────────────────────────────────────────────────────────────

-- New log entry → incremental prepend (O(1), no rebuild)
Ev.onLog.Event:Connect(function(entry)
    prependEntry(entry)
    updateCountLabel()
end)

-- Spam flag → toast warning (once per remote)
do
    local notified = {}
    Ev.onSpam.Event:Connect(function(path)
        if notified[path] then return end
        notified[path] = true
        showToast("Spam detected: " .. path:match("[^.]+$"), 3, T.Orange)
        task.delay(15, function() notified[path] = nil end)
    end)
end

-- Throttled full rebuild on filter changes
RunService.Heartbeat:Connect(function()
    if not S.dirtyFull then return end
    local now = tick()
    if now - S.lastRebuild < CFG.RebuildMs / 1000 then return end
    S.lastRebuild = now
    S.dirtyFull   = false
    rebuildAll()
    updateCountLabel()
end)

-- Pause / resume
local function setPaused(v)
    S.paused = v
    if S.paused then
        tw(liveDot,  { BackgroundColor3 = T.Red },                      0.15)
        tw(liveText, { TextColor3       = T.Red },                      0.15)
        tw(livePill, { BackgroundColor3 = Color3.fromRGB(44, 12, 12) }, 0.15)
        liveText.Text = "PAUSED"
        pauseLbl.Text = "▶"
        tw(pauseBg, { BackgroundColor3 = Color3.fromRGB(100, 28, 28) }, 0.12)
    else
        tw(liveDot,  { BackgroundColor3 = T.Green    }, 0.15)
        tw(liveText, { TextColor3       = T.Green    }, 0.15)
        tw(livePill, { BackgroundColor3 = T.PurpleBg }, 0.15)
        liveText.Text = "LIVE"
        pauseLbl.Text = "⏸"
        tw(pauseBg, { BackgroundColor3 = T.PurpleDim }, 0.12)
    end
    Ev.onPause:Fire(v)
end
pauseBtn.MouseButton1Click:Connect(function() setPaused(not S.paused) end)

-- Clear
local function clearLogs()
    S.logs  = {}
    S.total = 0
    for _, r in ipairs(S.activeRows) do
        if r.frame and r.frame.Parent then r.frame:Destroy() end
    end
    table.clear(S.activeRows)
    S.rowCount         = 0
    emptyLabel.Visible = true
    updateCountLabel()
    Ev.onClear:Fire()
end

clearBtn.MouseButton1Click:Connect(function()
    clearLogs()
    tw(clearBtn, { TextColor3 = T.Red }, 0.06)
    task.delay(0.7, function() tw(clearBtn, { TextColor3 = T.TextSub }, 0.2) end)
end)

-- Export
local function exportLogs(fmt)
    fmt = fmt or "lua"
    if fmt == "json" then
        local parts = {}
        for _, e in ipairs(S.logs) do
            parts[#parts + 1] = ('  {"id":%d,"type":"%s","path":"%s","name":"%s","args":[%s]}')
                :format(e.id, e.type,
                    e.path:gsub('"', '\\"'),
                    e.name:gsub('"', '\\"'),
                    argsStr(e.args))
        end
        return '[\n' .. table.concat(parts, ',\n') .. '\n]'
    end
    -- Default: Lua
    local parts = {}
    for _, e in ipairs(S.logs) do
        parts[#parts + 1] = ("-- [%s]  %s\n%s"):format(e.type, e.path, toScript(e))
    end
    return table.concat(parts, "\n\n")
end

exportBtn.MouseButton1Click:Connect(function()
    clip(exportLogs("lua"))
    showToast("Exported " .. #S.logs .. " logs", 2.2)
    tw(exportBtn, { TextColor3 = T.Green }, 0.06)
    task.delay(0.9, function() tw(exportBtn, { TextColor3 = T.TextSub }, 0.2) end)
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    S.query     = searchBox.Text
    S.dirtyFull = true
end)

-- Minimize
local fullSize  = UDim2.fromOffset(CFG.WinW, CFG.WinH)
local miniSize  = UDim2.fromOffset(CFG.WinW, 44)
local minimized = false
miniBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    tw(win, { Size = minimized and miniSize or fullSize },
        CFG.AnimTime + 0.05, Enum.EasingStyle.Quart)
end)

-- Close
closeBtn.MouseButton1Click:Connect(function()
    tw(win, { Size = UDim2.fromOffset(CFG.WinW, 0), BackgroundTransparency = 1 }, 0.20)
    task.delay(0.25, function()
        destroyHooks()
        for _, be in pairs(Ev) do pcall(function() be:Destroy() end) end
        gui:Destroy()
        _G.__Overturn = nil
    end)
end)

-- Drag (uses pixel position throughout so delta arithmetic is exact)
do
    local dragging, dragStart, winStart = false, nil, nil
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            winStart  = win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            win.Position = UDim2.fromOffset(
                winStart.X.Offset + d.X,
                winStart.Y.Offset + d.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- §21  PUBLIC API
-- src/api.lua
-- ─────────────────────────────────────────────────────────────
local plugins = {}

local function addCustomTab(def)
    assert(type(def.id)    == "string",   "tab id must be a string")
    assert(type(def.label) == "string",   "tab label must be a string")
    assert(type(def.filter) == "function","tab filter must be a function")
    if tabWidgets[def.id] or customTabs[def.id] then return end
    local w = buildTabWidget(def)
    customTabs[def.id] = w
    w.btn.MouseButton1Click:Connect(function() switchTab(def.id) end)
    w.btn.MouseEnter:Connect(function()
        if S.tab ~= def.id then tw(w.btn, { TextColor3 = T.Text    }, 0.08) end
    end)
    w.btn.MouseLeave:Connect(function()
        if S.tab ~= def.id then tw(w.btn, { TextColor3 = T.TextSub }, 0.10) end
    end)
end

local function registerPlugin(plugin)
    assert(type(plugin)         == "table",  "plugin must be a table")
    assert(type(plugin.Name)    == "string", "plugin.Name required")
    assert(type(plugin.Version) == "string", "plugin.Version required")

    if type(plugin.OnLog) == "function" then
        Ev.onLog.Event:Connect(function(entry)
            task.spawn(plugin.OnLog, entry)
        end)
    end

    if type(plugin.OnInit) == "function" then
        task.spawn(plugin.OnInit, {
            -- State (read-only by convention)
            logs     = S.logs,
            ignored  = S.ignored,
            blocked  = S.blocked,
            spam     = Spam,
            -- Theme & config (writable)
            theme    = T,
            cfg      = CFG,
            -- UI
            gui      = gui,
            window   = win,
            toast    = showToast,
            addTab   = addCustomTab,
            -- Events
            onLog    = Ev.onLog.Event,
            onSpam   = Ev.onSpam.Event,
            onBlock  = Ev.onBlock.Event,
            onIgnore = Ev.onIgnore.Event,
            onClear  = Ev.onClear.Event,
            onPause  = Ev.onPause.Event,
            -- Injection
            addLog   = addEntry,
        })
    end

    plugins[#plugins + 1] = { name = plugin.Name, version = plugin.Version }
    print(("[Overturn] plugin: %s v%s"):format(plugin.Name, plugin.Version))
    return true
end

_G.__Overturn = {
    Version = CFG.Version,
    _gui    = gui,
    _window = win,
    _theme  = T,
    _cfg    = CFG,

    -- ── Event streams (RBXScriptSignal — use :Connect())
    Events = {
        OnLog    = Ev.onLog.Event,
        OnSpam   = Ev.onSpam.Event,
        OnBlock  = Ev.onBlock.Event,
        OnIgnore = Ev.onIgnore.Event,
        OnClear  = Ev.onClear.Event,
        OnPause  = Ev.onPause.Event,
    },

    -- ── Log management
    Logs = {
        Get   = function() return S.logs end,
        Count = function() return S.total end,
        Find  = function(pred)
            assert(type(pred) == "function", "predicate must be a function")
            local r = {}
            for _, e in ipairs(S.logs) do
                if pred(e) then r[#r + 1] = e end
            end
            return r
        end,
        Clear  = clearLogs,
        Export = exportLogs,  -- exportLogs(fmt?: "lua" | "json")
    },

    -- ── Remote management
    Remotes = {
        GetAll = function()
            local paths = {}
            for p in pairs(Spam._records) do paths[#paths + 1] = p end
            return paths
        end,
        GetStats = function(path)
            local rec = Spam._records[path]
            if not rec then return nil end
            return {
                total   = rec.total,
                dropped = rec.dropped,
                flagged = rec.flagged,
                rate    = #rec.times,
            }
        end,
        Ignore    = function(p) S.ignored[p] = true;  S.dirtyFull = true; Ev.onIgnore:Fire(p) end,
        Block     = function(p) S.blocked[p] = true;  S.dirtyFull = true; Ev.onBlock:Fire(p)  end,
        Unignore  = function(p) S.ignored[p] = nil;   S.dirtyFull = true end,
        Unblock   = function(p) S.blocked[p] = nil;   S.dirtyFull = true end,
        IsIgnored = function(p) return S.ignored[p] == true end,
        IsBlocked = function(p) return S.blocked[p] == true end,
    },

    -- ── Anti-spam control
    Spam = {
        GetConfig = function() return CFG.Spam end,
        SetConfig = function(t)
            assert(type(t) == "table", "config must be a table")
            for k, v in pairs(t) do CFG.Spam[k] = v end
        end,
        GetFlagged = function()
            local r = {}
            for p, rec in pairs(Spam._records) do
                if rec.flagged then r[#r + 1] = p end
            end
            return r
        end,
        GetRecord  = function(path) return Spam._records[path] end,
        Whitelist  = function(path, on)
            CFG.Spam.whitelist[path] = on ~= false and true or nil
        end,
        Reset      = function(path)
            if path then
                local rec = Spam._records[path]
                if rec and rec.flagged then
                    Spam._flagCount = math.max(0, Spam._flagCount - 1)
                end
                Spam._records[path] = nil
                for i, p in ipairs(Spam._trackedPaths) do
                    if p == path then table.remove(Spam._trackedPaths, i); break end
                end
            else
                Spam._records      = {}
                Spam._trackedPaths = {}
                Spam._flagCount    = 0
            end
            updateSpamBadge()
            S.dirtyFull = true
        end,
        IsEnabled  = function() return CFG.Spam.enabled end,
        Enable     = function() CFG.Spam.enabled = true  end,
        Disable    = function() CFG.Spam.enabled = false end,
    },

    -- ── UI utilities
    UI = {
        Notify   = showToast,  -- showToast(text, dur?, color?)
        AddTab   = addCustomTab,
        SetTheme = function(t)
            assert(type(t) == "table", "theme must be a table")
            for k, v in pairs(t) do T[k] = v end
        end,
        Show     = function() win.Visible = true  end,
        Hide     = function() win.Visible = false end,
    },

    -- ── Plugin system
    RegisterPlugin = registerPlugin,
    GetPlugins     = function() return plugins end,

    -- ── Core
    SetPaused = setPaused,
    IsPaused  = function() return S.paused end,
    IsHooked  = function() return S.hooked end,
    Inject    = addEntry,
}

-- ─────────────────────────────────────────────────────────────
-- §22  BOOT
-- ─────────────────────────────────────────────────────────────
initHooks()

win.Size                   = UDim2.fromOffset(CFG.WinW, 8)
win.BackgroundTransparency = 1
tw(win, { Size = fullSize, BackgroundTransparency = 0 }, 0.28,
    Enum.EasingStyle.Back, Enum.EasingDirection.Out)

print(("[Overturn] v%s ready · hooked=%s · left-click=copy · right-click=menu")
    :format(CFG.Version, tostring(S.hooked)))
