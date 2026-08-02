--[[
    @module  Tabs
    @file    src/ui/tabs.lua
    @desc    Builds the horizontal tab strip and wires tab selection.
             Tabs are registered at startup and can also be added by plugins
             via _G.__Overturn.UI.addTab(id, label, filterFn).

    Built-in tabs (in order):
        ALL          — all non-ignored entries (hides spam if action=="hide")
        REMOTES      — RemoteEvent only
        FUNCTIONS    — RemoteFunction + ReturnValue
        UNRELIABLE   — UnreliableRemoteEvent only
        SPAM         — entries marked spam or from currently flagged remotes
        BLOCKED      — explicitly blocked / ignored paths

    Returns: { tabBar, selectTab, addTab }
        selectTab(id)  — programmatically switch to a tab (animates indicator)
        addTab(id, label, filter) — register a new tab (plugin API)
]]

local BUILT_IN = {
    { id = "ALL",        label = "All"        },
    { id = "REMOTES",    label = "Remotes"    },
    { id = "FUNCTIONS",  label = "Functions"  },
    { id = "UNRELIABLE", label = "Unreliable" },
    { id = "SPAM",       label = "Spam"       },
    { id = "BLOCKED",    label = "Blocked"    },
}

local function buildTabs(inner, onTabSelect)
    local tabBar = frame(inner, {
        Name             = "TabBar",
        Size             = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = T.Surface,
    })
    pad(tabBar, 0, 6, 0)
    mk("UIListLayout", {
        FillDirection  = Enum.FillDirection.Horizontal,
        Padding        = UDim.new(0, 2),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent         = tabBar,
    })
    stroke(tabBar, T.BorderSub, 1)

    -- Active tab underline indicator (slides to selected tab)
    local indicator = frame(tabBar, {
        Name             = "Indicator",
        Size             = UDim2.fromOffset(60, 2),
        Position         = UDim2.fromOffset(6, 31),
        BackgroundColor3 = T.Purple,
        ZIndex           = 6,
    })
    corner(indicator, 2)
    -- Remove from ListLayout flow
    indicator.LayoutOrder = 999

    local tabs   = {}   -- { id, btn, label }
    local active = nil

    local function selectTab(id)
        for _, t in ipairs(tabs) do
            local isSel = t.id == id
            tween(t.btn, TweenInfo.new(0.12), {
                BackgroundColor3 = isSel and T.SurfaceHigh or Color3.fromRGB(0,0,0),
                BackgroundTransparency = isSel and 0 or 1,
            })
            tween(t.lbl, TweenInfo.new(0.12), {
                TextColor3 = isSel and T.PurpleHi or T.TextSub,
            })
            if isSel then
                -- Slide indicator
                tween(indicator,
                    TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                    { Position = UDim2.fromOffset(t.btn.AbsolutePosition.X - tabBar.AbsolutePosition.X, 31),
                      Size     = UDim2.fromOffset(t.btn.AbsoluteSize.X, 2) })
            end
        end
        active   = id
        S.tab    = id
        S.dirtyFull = true
        onTabSelect(id)
    end

    local function addTab(id, labelText, _filterFn)
        local b = btn(tabBar, "", {
            Name             = "Tab_" .. id,
            Size             = UDim2.fromOffset(0, 28),
            AutomaticSize    = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            ZIndex           = 5,
            LayoutOrder      = #tabs + 1,
        })
        pad(b, 0, 10, 0)
        corner(b, 6)

        local lbl = label(b, labelText, {
            Size       = UDim2.fromScale(1, 1),
            TextColor3 = T.TextSub,
            TextSize   = 13,
            Font       = T.FontSemi,
            ZIndex     = 5,
        })

        b.MouseEnter:Connect(function()
            if S.tab ~= id then
                tween(b, TweenInfo.new(0.1), { BackgroundTransparency = 0.6, BackgroundColor3 = T.SurfaceAlt })
            end
        end)
        b.MouseLeave:Connect(function()
            if S.tab ~= id then
                tween(b, TweenInfo.new(0.1), { BackgroundTransparency = 1 })
            end
        end)
        b.MouseButton1Click:Connect(function() selectTab(id) end)

        tabs[#tabs + 1] = { id = id, btn = b, lbl = lbl, filter = _filterFn }

        -- Register in S.customTabs if not a built-in
        if _filterFn then
            S.customTabs[id] = { label = labelText, filter = _filterFn }
        end
    end

    for _, t in ipairs(BUILT_IN) do
        addTab(t.id, t.label, nil)
    end

    -- Default select ALL
    task.defer(function() selectTab("ALL") end)

    return {
        tabBar    = tabBar,
        selectTab = selectTab,
        addTab    = addTab,
    }
end

return buildTabs
