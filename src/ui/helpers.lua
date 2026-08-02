--[[
    @module  UI Helpers
    @file    src/ui/helpers.lua
    @desc    Tiny factory functions for creating common GUI instances.
             All functions return the newly created instance.

    Functions:
        mk(cls, props)               — Create any Instance with props table
        frame(parent, props)         — UICorner-less frame shortcut
        label(parent, text, props)   — TextLabel shortcut
        btn(parent, text, props)     — TextButton shortcut
        corner(parent, radius)       — UICorner shortcut
        pad(parent, all, lr, tb)     — UIPadding shortcut
        stroke(parent, clr, thick)   — UIStroke shortcut
        gradient(parent, clr0, clr1, rot) — UIGradient shortcut
        tween(inst, info, goals)     — TweenService:Create shortcut
        spring(inst, goals, d, f)    — TweenInfo spring approximation
]]

local TS = game:GetService("TweenService")

local function mk(cls, props)
    local inst = Instance.new(cls)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function frame(parent, props)
    local p = props or {}
    p.BackgroundColor3 = p.BackgroundColor3 or Color3.fromRGB(0,0,0)
    p.BorderSizePixel  = p.BorderSizePixel  or 0
    p.Parent           = parent
    return mk("Frame", p)
end

local function label(parent, text, props)
    local p = props or {}
    p.Text             = text
    p.BackgroundTransparency = p.BackgroundTransparency or 1
    p.BorderSizePixel  = p.BorderSizePixel  or 0
    p.TextXAlignment   = p.TextXAlignment   or Enum.TextXAlignment.Left
    p.Font             = p.Font             or T.Font
    p.TextSize         = p.TextSize         or 13
    p.TextColor3       = p.TextColor3       or T.Text
    p.Parent           = parent
    return mk("TextLabel", p)
end

local function btn(parent, text, props)
    local p = props or {}
    p.Text             = text
    p.BackgroundColor3 = p.BackgroundColor3 or T.SurfaceHigh
    p.BorderSizePixel  = 0
    p.Font             = p.Font             or T.Font
    p.TextSize         = p.TextSize         or 13
    p.TextColor3       = p.TextColor3       or T.Text
    p.AutoButtonColor  = false
    p.Parent           = parent
    return mk("TextButton", p)
end

local function corner(parent, radius)
    return mk("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

local function pad(parent, all, lr, tb)
    local a = all or 0
    return mk("UIPadding", {
        PaddingTop    = UDim.new(0, tb  or a),
        PaddingBottom = UDim.new(0, tb  or a),
        PaddingLeft   = UDim.new(0, lr  or a),
        PaddingRight  = UDim.new(0, lr  or a),
        Parent        = parent,
    })
end

local function stroke(parent, clr, thick)
    return mk("UIStroke", {
        Color     = clr   or T.Border,
        Thickness = thick or 1,
        Parent    = parent,
    })
end

local function gradient(parent, clr0, clr1, rot)
    return mk("UIGradient", {
        Color    = ColorSequence.new(clr0, clr1),
        Rotation = rot or 90,
        Parent   = parent,
    })
end

local function tween(inst, info, goals)
    local tw = TS:Create(inst, info, goals)
    if type(tw) ~= "string" and tw then
        tw:Play()
    end
    return tw
end

local function spring(inst, goals, dur, fill)
    local info = TweenInfo.new(dur or CFG.AnimTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    return tween(inst, info, goals)
end

return {
    mk = mk, frame = frame, label = label, btn = btn,
    corner = corner, pad = pad, stroke = stroke, gradient = gradient,
    tween = tween, spring = spring,
}
