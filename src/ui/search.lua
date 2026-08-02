--[[
    @module  Search Bar
    @file    src/ui/search.lua
    @desc    Builds the search input row with:
               • Text input with debounce (160ms) → sets S.query + S.dirtyFull
               • Clear (✕) button
               • Remote count label (updated by loglist every rebuild)

    Returns: { searchBar, countLabel, setCount(n) }
]]

local function buildSearchBar(inner)
    local bar = frame(inner, {
        Name             = "SearchBar",
        Size             = UDim2.new(1, 0, 0, 36),
        Position         = UDim2.fromOffset(0, 34),  -- below tab bar
        BackgroundColor3 = T.SurfaceAlt,
    })
    pad(bar, 0, 8, 0)
    stroke(bar, T.BorderSub, 1)

    -- Search icon label
    label(bar, "🔍", {
        Name       = "Icon",
        Size       = UDim2.fromOffset(22, 36),
        TextColor3 = T.TextMuted,
        TextSize   = 14,
        ZIndex     = 3,
    })

    local input = mk("TextBox", {
        Name             = "Input",
        Size             = UDim2.new(1, -106, 1, -8),
        Position         = UDim2.fromOffset(26, 4),
        BackgroundTransparency = 1,
        Font             = T.Font,
        TextSize         = 13,
        TextColor3       = T.Text,
        PlaceholderText  = "Search remotes, paths, arguments…",
        PlaceholderColor3 = T.TextMuted,
        ClearTextOnFocus = false,
        TextXAlignment   = Enum.TextXAlignment.Left,
        ZIndex           = 3,
        Parent           = bar,
    })

    local clearBtn = btn(bar, "✕", {
        Name             = "Clear",
        Size             = UDim2.fromOffset(22, 22),
        Position         = UDim2.new(1, -66, 0.5, -11),
        BackgroundColor3 = T.SurfaceHigh,
        TextColor3       = T.TextMuted,
        TextSize         = 12,
        Visible          = false,
        ZIndex           = 3,
    })
    corner(clearBtn, 4)

    local countLabel = label(bar, "0 entries", {
        Name       = "Count",
        Size       = UDim2.fromOffset(70, 36),
        Position   = UDim2.new(1, -72, 0, 0),
        TextColor3 = T.TextMuted,
        TextSize   = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex     = 3,
    })

    -- Debounce timer
    local debounce = nil
    input:GetPropertyChangedSignal("Text"):Connect(function()
        local q = input.Text
        clearBtn.Visible = q ~= ""
        if debounce then task.cancel(debounce) end
        debounce = task.delay(0.16, function()
            S.query     = q:lower()
            S.dirtyFull = true
        end)
    end)

    clearBtn.MouseButton1Click:Connect(function()
        input.Text  = ""
        S.query     = ""
        S.dirtyFull = true
    end)

    local function setCount(n)
        countLabel.Text = n .. (n == 1 and " entry" or " entries")
    end

    return { searchBar = bar, countLabel = countLabel, setCount = setCount }
end

return buildSearchBar
