--[[
    @module  Toast Notifications
    @file    src/ui/toast.lua
    @desc    Non-blocking notification banners that slide in from the top-right
             of the window and auto-dismiss after a configurable duration.

    Types (map to colour):
        "info"    — Purple accent  (default)
        "success" — Green
        "warn"    — Orange
        "error"   — Red

    Public:
        toast(message, type?, duration?)
            message   string  — text to display
            type      string  — "info" | "success" | "warn" | "error"
            duration  number  — seconds before auto-dismiss (default 3)
]]

local TYPE_CLR = {
    info    = { bg = Color3.fromRGB(50, 30, 100), accent = T.Purple  },
    success = { bg = Color3.fromRGB(10, 40, 22),  accent = T.Green   },
    warn    = { bg = Color3.fromRGB(50, 30,  5),  accent = T.Orange  },
    error   = { bg = Color3.fromRGB(50, 10, 10),  accent = T.Red     },
}

local TOAST_GAP   = 44
local TOAST_W     = 230
local TOAST_H     = 36
local toastStack  = {}

local function buildToast(gui)
    local container = frame(gui, {
        Name             = "ToastContainer",
        Size             = UDim2.fromOffset(TOAST_W, 600),
        Position         = UDim2.new(1, -(TOAST_W + 8), 0, 48),
        BackgroundTransparency = 1,
        ZIndex           = 30,
    })

    local function repositionStack()
        for i, t in ipairs(toastStack) do
            local targetY = (i - 1) * TOAST_GAP
            tween(t, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Position = UDim2.fromOffset(0, targetY) })
        end
    end

    local function toast(message, ttype, duration)
        ttype    = ttype    or "info"
        duration = duration or 3

        local clrs   = TYPE_CLR[ttype] or TYPE_CLR.info
        local startY = #toastStack * TOAST_GAP

        local t = frame(container, {
            Name             = "Toast",
            Size             = UDim2.fromOffset(TOAST_W, TOAST_H),
            Position         = UDim2.fromOffset(TOAST_W + 12, startY),
            BackgroundColor3 = clrs.bg,
            BackgroundTransparency = 0.1,
            ZIndex           = 31,
        })
        corner(t, 7)
        stroke(t, clrs.accent, 1)

        -- Accent left strip
        frame(t, {
            Size             = UDim2.fromOffset(3, TOAST_H - 10),
            Position         = UDim2.fromOffset(5, 5),
            BackgroundColor3 = clrs.accent,
            ZIndex           = 32,
        })

        label(t, message, {
            Size       = UDim2.new(1, -16, 1, 0),
            Position   = UDim2.fromOffset(12, 0),
            TextColor3 = T.Text,
            TextSize   = 12,
            Font       = T.Font,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex     = 32,
        })

        table.insert(toastStack, t)

        -- Slide in
        tween(t, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Position = UDim2.fromOffset(0, startY) })

        -- Auto-dismiss
        task.delay(duration, function()
            local idx = table.find(toastStack, t)
            if idx then table.remove(toastStack, idx) end
            tween(t, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
                { Position = UDim2.fromOffset(TOAST_W + 12, t.Position.Y.Offset),
                  BackgroundTransparency = 1 })
            task.delay(0.2, function() if t.Parent then t:Destroy() end end)
            repositionStack()
        end)
    end

    return toast
end

return buildToast
