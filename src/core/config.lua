--[[
    @module  Config
    @file    src/core/config.lua
    @desc    Theme colours and runtime configuration tables.
             Exported as T (theme) and CFG (config).
             Modify CFG.Spam at runtime to tune anti-spam behaviour.
             Modify T values (or use _G.__Overturn.UI.SetTheme) to retheme.
]]

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

    -- Log row badge colours per remote type
    BadgeRE     = Color3.fromRGB(139,  92, 246),   -- RemoteEvent
    BadgeRF     = Color3.fromRGB( 59, 130, 246),   -- RemoteFunction
    BadgeURE    = Color3.fromRGB(234,  88,  12),   -- UnreliableRemoteEvent
    BadgeRet    = Color3.fromRGB( 34, 197,  94),   -- ReturnValue
    BadgeSpam   = Color3.fromRGB(234, 179,   8),   -- Spam-flagged override

    Scrollbar   = Color3.fromRGB(70, 54, 118),

    Font     = Enum.Font.GothamMedium,
    FontBold = Enum.Font.GothamBold,
    FontSemi = Enum.Font.Gotham,
    FontMono = Enum.Font.Code,
}

local CFG = {
    Version    = "2.0.0",
    MaxLogs    = 500,    -- entries kept in S.logs (memory)
    MaxVisible = 100,    -- rows rendered in the scroll frame at once
    AnimTime   = 0.15,   -- default tween duration
    WinW       = 730,
    WinH       = 480,
    LogH       = 40,     -- height of each log row in pixels
    RebuildMs  = 80,     -- min milliseconds between full list rebuilds

    -- Anti-spam — all fields are hot-reloadable at runtime
    Spam = {
        enabled      = true,
        rateWindow   = 2.0,   -- seconds over which call rate is measured
        rateLimit    = 20,    -- calls per rateWindow that triggers flagging
        dedupMs      = 60,    -- drop identical (path + argsHash) within N ms
        action       = "hide",-- "hide" | "block" | "log"
        hysteresis   = 0.6,   -- unflag when rate drops to rateLimit * this
        maxTracked   = 300,   -- LRU eviction cap for per-remote records
        whitelist    = {},    -- [path] = true → never flag
    },
}

return { T = T, CFG = CFG }
