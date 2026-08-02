--[[
    @module  Status Bar
    @file    src/ui/statusbar.lua
    @desc    Bottom status bar showing:
               • Live entry counter (updates every heartbeat)
               • Spam drop counter
               • Flagged remote count badge
               • Clear-all button
               • Start / Pause toggle button

    Returns: { bar, updateCounts(vis, total, spam, flagged), setPaused(bool) }
]]

local function buildStatusBar(inner, win, onClear, onToggle)
    local H = CFG.WinH
    local bar = frame(win, {
        Name             = "StatusBar",
        Size             = UDim2.new(1, 0, 0, 28),
        Position         = UDim2.fromOffset(0, H - 28),
        BackgroundColor3 = T.Surface,
        ZIndex           = 3,
    })
    -- Round only bottom corners
    corner(bar, 12)
    frame(bar, {
        Size             = UDim2.new(1, 0, 0, 12),
        BackgroundColor3 = T.Surface,
        ZIndex           = 2,
    })
    stroke(bar, T.BorderSub, 1)
    pad(bar, 0, 8, 0)

    -- Stats labels
    local visLbl = label(bar, "0 visible", {
        Size       = UDim2.fromOffset(80, 28),
        TextColor3 = T.TextMuted,
        TextSize   = 11,
        ZIndex     = 4,
    })
    local totalLbl = label(bar, "/ 0 total", {
        Size       = UDim2.fromOffset(70, 28),
        Position   = UDim2.fromOffset(82, 0),
        TextColor3 = T.TextMuted,
        TextSize   = 11,
        ZIndex     = 4,
    })
    local spamLbl = label(bar, "0 spam", {
        Size       = UDim2.fromOffset(60, 28),
        Position   = UDim2.fromOffset(154, 0),
        TextColor3 = T.Orange,
        TextSize   = 11,
        ZIndex     = 4,
    })

    -- Flagged-remotes badge
    local flagBadge = frame(bar, {
        Name             = "FlagBadge",
        Size             = UDim2.fromOffset(22, 17),
        Position         = UDim2.fromOffset(216, 5),
        BackgroundColor3 = T.Red,
        BackgroundTransparency = 0.3,
        Visible          = false,
        ZIndex           = 4,
    })
    corner(flagBadge, 4)
    local flagLbl = label(flagBadge, "0", {
        Size       = UDim2.fromScale(1, 1),
        TextColor3 = T.Text,
        TextSize   = 10,
        Font       = T.FontBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex     = 5,
    })

    -- Buttons (right side)
    local function mkSBtn(text, xOff, clr, action)
        local b = btn(bar, text, {
            Size             = UDim2.fromOffset(54, 20),
            Position         = UDim2.new(1, xOff, 0.5, -10),
            BackgroundColor3 = T.SurfaceHigh,
            TextColor3       = clr,
            TextSize         = 11,
            Font             = T.FontBold,
            ZIndex           = 4,
        })
        corner(b, 5)
        b.MouseEnter:Connect(function()
            tween(b, TweenInfo.new(0.1), { BackgroundColor3 = T.SurfaceAlt })
        end)
        b.MouseLeave:Connect(function()
            tween(b, TweenInfo.new(0.1), { BackgroundColor3 = T.SurfaceHigh })
        end)
        b.MouseButton1Click:Connect(action)
        return b
    end

    local clearBtn  = mkSBtn("Clear", -118, T.TextSub, onClear)
    local toggleBtn = mkSBtn("Pause", -60,  T.Orange,  onToggle)

    local function updateCounts(vis, total, spam, flagged)
        visLbl.Text   = vis   .. " visible"
        totalLbl.Text = "/ "  .. total .. " total"
        spamLbl.Text  = spam  .. " spam"
        flagBadge.Visible = flagged > 0
        if flagged > 0 then
            flagLbl.Text = tostring(flagged)
        end
    end

    local function setPaused(p)
        if p then
            toggleBtn.Text      = "Resume"
            toggleBtn.TextColor3 = T.Green
        else
            toggleBtn.Text      = "Pause"
            toggleBtn.TextColor3 = T.Orange
        end
    end

    return { bar = bar, updateCounts = updateCounts, setPaused = setPaused }
end

return buildStatusBar
