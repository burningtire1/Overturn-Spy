--[[
    @module  Title Bar
    @file    src/ui/titlebar.lua
    @desc    Builds the 40px title bar with:
               • Purple crescent moon logo (pure-GUI, no images needed)
               • "Overturn" wordmark + version
               • Window control buttons: minimise, close
               • Drag handling (mouse down on title bar)
               • LIVE/PAUSED status pill (updated by statusbar module)

    Returns: { bar, dragZone, pillText, pillDot }
]]

local UIS = game:GetService("UserInputService")

local function buildTitleBar(win, bg, onClose, onMinimise)
    -- Title bar root
    local bar = frame(win, {
        Name             = "TitleBar",
        Size             = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = T.Surface,
        ZIndex           = 4,
    })
    corner(bar, 12)
    -- Clip bottom corners so the bar blends into content below
    frame(bar, {
        Name             = "CornerClip",
        Size             = UDim2.new(1, 0, 0, 12),
        Position         = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = T.Surface,
        ZIndex           = 3,
    })
    stroke(bar, T.BorderSub, 1)

    -- Moon logo ─────────────────────────────────────────────────
    local moonBase = frame(bar, {
        Name             = "Moon",
        Size             = UDim2.fromOffset(26, 26),
        Position         = UDim2.fromOffset(10, 7),
        BackgroundColor3 = T.Purple,
        ZIndex           = 5,
    })
    mk("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = moonBase })

    -- The "bite" circle that creates the crescent shape
    local bite = frame(bar, {
        Name             = "MoonBite",
        Size             = UDim2.fromOffset(20, 20),
        Position         = UDim2.fromOffset(19, 4),
        BackgroundColor3 = T.Surface,   -- matches bar so it masks the circle
        ZIndex           = 6,
    })
    mk("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = bite })

    -- Soft glow halo behind moon
    local moonGlow = frame(bar, {
        Name             = "MoonGlow",
        Size             = UDim2.fromOffset(34, 34),
        Position         = UDim2.fromOffset(6, 3),
        BackgroundColor3 = T.Purple,
        BackgroundTransparency = 0.72,
        ZIndex           = 4,
    })
    mk("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = moonGlow })

    -- Wordmark
    label(bar, "Overturn", {
        Name       = "Title",
        Size       = UDim2.fromOffset(110, 30),
        Position   = UDim2.fromOffset(42, 5),
        Font       = T.FontBold,
        TextSize   = 16,
        TextColor3 = T.Text,
        ZIndex     = 5,
    })
    label(bar, "v" .. CFG.Version, {
        Name       = "Ver",
        Size       = UDim2.fromOffset(50, 30),
        Position   = UDim2.fromOffset(148, 5),
        TextColor3 = T.TextMuted,
        TextSize   = 11,
        ZIndex     = 5,
    })

    -- LIVE / PAUSED pill
    local pill = frame(bar, {
        Name             = "Pill",
        Size             = UDim2.fromOffset(64, 20),
        Position         = UDim2.fromOffset(210, 10),
        BackgroundColor3 = T.PurpleBg,
        ZIndex           = 5,
    })
    corner(pill, 10)
    stroke(pill, T.PurpleDim, 1)

    local pillDot = frame(pill, {
        Name             = "Dot",
        Size             = UDim2.fromOffset(7, 7),
        Position         = UDim2.fromOffset(8, 6),
        BackgroundColor3 = T.Green,
        ZIndex           = 6,
    })
    mk("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = pillDot })

    local pillText = label(pill, "LIVE", {
        Name       = "Lbl",
        Size       = UDim2.new(1, -20, 1, 0),
        Position   = UDim2.fromOffset(18, 0),
        TextColor3 = T.Green,
        TextSize   = 11,
        Font       = T.FontBold,
        ZIndex     = 6,
    })

    -- Window control buttons (right side)
    local function mkWinBtn(label_text, xOff, clrHov, action)
        local b = btn(bar, label_text, {
            Size             = UDim2.fromOffset(28, 22),
            Position         = UDim2.new(1, xOff, 0, 9),
            BackgroundColor3 = T.SurfaceAlt,
            TextColor3       = T.TextSub,
            TextSize         = 14,
            Font             = T.FontBold,
            ZIndex           = 5,
        })
        corner(b, 5)
        b.MouseEnter:Connect(function()
            tween(b, TweenInfo.new(0.1), { BackgroundColor3 = clrHov, TextColor3 = T.Text })
        end)
        b.MouseLeave:Connect(function()
            tween(b, TweenInfo.new(0.1), { BackgroundColor3 = T.SurfaceAlt, TextColor3 = T.TextSub })
        end)
        b.MouseButton1Click:Connect(action)
        return b
    end

    mkWinBtn("✕", -36, T.Red,    onClose)
    mkWinBtn("–", -70, T.Orange, onMinimise)

    -- Drag zone: full title bar minus the right 80px (buttons)
    local dragZone = btn(bar, "", {
        Name             = "DragZone",
        Size             = UDim2.new(1, -80, 1, 0),
        BackgroundTransparency = 1,
        ZIndex           = 7,
    })

    -- Drag state
    local dragging, dragStart, winStart = false, nil, nil
    dragZone.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = true
        dragStart = inp.Position
        winStart  = bg.Position
    end)
    dragZone.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = inp.Position - dragStart
        local np    = UDim2.fromOffset(
            winStart.X.Offset + delta.X,
            winStart.Y.Offset + delta.Y)
        bg.Position  = np
        win.Position = np
    end)

    return { bar = bar, pillText = pillText, pillDot = pillDot }
end

return buildTitleBar
