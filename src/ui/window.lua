--[[
    @module  Window
    @file    src/ui/window.lua
    @desc    Builds the root ScreenGui + Window Frame.
             Returns { gui, win, bg, inner } where:
               gui   — ScreenGui hosted in CoreGui / gethui()
               win   — the main draggable window frame
               bg    — decorative radial-gradient background panel
               inner — content area inside the window (below the title bar)

    The window is centred on first open using purely-offset position so
    drag arithmetic is always exact (no Scale component to compensate for).
    Animated with a scale + fade-in spring on open.
]]

local function buildWindow()
    local host = (pcall(gethui) and gethui()) or game:GetService("CoreGui")

    -- Clean up any previous instance
    local existing = host:FindFirstChild("OverturnSpy")
    if existing then existing:Destroy() end

    local gui = mk("ScreenGui", {
        Name             = "OverturnSpy",
        ResetOnSpawn     = false,
        ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset   = true,
        Parent           = host,
    })

    local vp = workspace.CurrentCamera.ViewportSize
    local W, H = CFG.WinW, CFG.WinH
    local ox   = math.floor((vp.X - W) / 2)
    local oy   = math.floor((vp.Y - H) / 2)

    -- Decorative blurred background canvas
    local bg = frame(gui, {
        Name             = "BG",
        Size             = UDim2.fromOffset(W, H),
        Position         = UDim2.fromOffset(ox, oy),
        BackgroundColor3 = T.Bg,
        BackgroundTransparency = 0,
    })
    corner(bg, 12)
    gradient(bg,
        Color3.fromRGB(18, 14, 36),
        Color3.fromRGB(10,  9, 16),
        135)
    mk("UIStroke", { Color = T.Border, Thickness = 1.2, Parent = bg })

    -- Inner subtle noise overlay (faked with a second gradient at low opacity)
    local noise = frame(bg, {
        Name             = "Noise",
        Size             = UDim2.fromScale(1, 1),
        BackgroundColor3 = T.PurpleBg,
        BackgroundTransparency = 0.94,
    })
    corner(noise, 12)

    -- Soft glow in the upper-left corner
    local glow = frame(bg, {
        Name             = "Glow",
        Size             = UDim2.fromOffset(320, 180),
        Position         = UDim2.fromOffset(-40, -40),
        BackgroundColor3 = T.Purple,
        BackgroundTransparency = 0.82,
    })
    mk("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = glow })

    -- Main window frame (sits on top of bg decorations)
    local win = frame(gui, {
        Name             = "Win",
        Size             = UDim2.fromOffset(W, H),
        Position         = UDim2.fromOffset(ox, oy),
        BackgroundTransparency = 1,
        ZIndex           = 2,
    })

    -- Content area (everything below the 40px title bar)
    local inner = frame(win, {
        Name             = "Inner",
        Size             = UDim2.new(1, 0, 1, -40),
        Position         = UDim2.fromOffset(0, 40),
        BackgroundTransparency = 1,
    })

    -- Animate open: scale spring from 0.92 → 1 + transparency 1 → 0
    bg.BackgroundTransparency = 1
    tween(bg,
        TweenInfo.new(CFG.AnimTime * 1.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0 })

    return { gui = gui, win = win, bg = bg, inner = inner }
end

return buildWindow
