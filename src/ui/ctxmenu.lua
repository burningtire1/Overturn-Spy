--[[
    @module  Context Menu
    @file    src/ui/ctxmenu.lua
    @desc    Right-click context menu shown on log rows.

    Actions available:
        Copy Path          — setclipboard with remote path
        Copy as Script     — setclipboard with toScript(entry) output
        Copy Args          — setclipboard with argsStr(args)
        Block Remote       — add path to S.blocked (prevents pass-through)
        Ignore Remote      — add path to S.ignored (hidden from All tab)
        Whitelist (Spam)   — add path to CFG.Spam.whitelist
        Clear Spam Record  — delete Spam._records[path]

    Returns: { showCtx, hideCtx }
        showCtx(entry, screenPos)  — open menu at screen position
        hideCtx()                  — close menu
]]

local UIS = game:GetService("UserInputService")

local function buildContextMenu(gui)
    local menu = frame(gui, {
        Name             = "CtxMenu",
        Size             = UDim2.fromOffset(192, 8),   -- grows with items
        BackgroundColor3 = T.Elevated,
        Visible          = false,
        ZIndex           = 20,
    })
    corner(menu, 8)
    stroke(menu, T.Border, 1)
    pad(menu, 4, 0, 4)

    local itemLayout = mk("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 1),
        Parent    = menu,
    })
    mk("UISizeConstraint", { MaxSize = Vector2.new(192, 9999), Parent = menu })

    local autoSize = mk("UIListLayout", { Parent = Instance.new("Frame") }) -- dummy
    itemLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        menu.Size = UDim2.fromOffset(192, itemLayout.AbsoluteContentSize.Y + 8)
    end)

    local function clearItems()
        for _, c in ipairs(menu:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
    end

    local function addItem(label_text, icon, action, order, danger)
        local item = btn(menu, "", {
            Name             = "Item_" .. order,
            Size             = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = T.Elevated,
            BackgroundTransparency = 1,
            LayoutOrder      = order,
            ZIndex           = 21,
        })
        corner(item, 5)
        pad(item, 0, 8, 0)

        label(item, icon, {
            Size       = UDim2.fromOffset(18, 30),
            TextColor3 = danger and T.Red or T.TextSub,
            TextSize   = 13,
            ZIndex     = 22,
        })
        label(item, label_text, {
            Size       = UDim2.new(1, -26, 1, 0),
            Position   = UDim2.fromOffset(22, 0),
            TextColor3 = danger and T.Red or T.Text,
            TextSize   = 13,
            ZIndex     = 22,
        })

        item.MouseEnter:Connect(function()
            tween(item, TweenInfo.new(0.08), {
                BackgroundTransparency = 0,
                BackgroundColor3       = danger and Color3.fromRGB(40,10,10) or T.SurfaceHigh,
            })
        end)
        item.MouseLeave:Connect(function()
            tween(item, TweenInfo.new(0.08), { BackgroundTransparency = 1 })
        end)
        item.MouseButton1Click:Connect(function()
            hideCtx()
            action()
        end)
        return item
    end

    local function showCtx(entry, pos)
        clearItems()

        local isBlocked   = S.blocked[entry.path]
        local isIgnored   = S.ignored[entry.path]
        local isWhitelisted = CFG.Spam.whitelist[entry.path]

        addItem("Copy Path",       "📋", function() setclipboard(entry.path)           end, 1)
        addItem("Copy as Script",  "📜", function() setclipboard(toScript(entry))       end, 2)
        addItem("Copy Args",       "📦", function() setclipboard(argsStr(entry.args))   end, 3)

        -- Separator
        frame(menu, { Size = UDim2.new(1, -16, 0, 1),
            BackgroundColor3 = T.BorderSub, LayoutOrder = 4 })

        if isBlocked then
            addItem("Unblock Remote",  "✅", function()
                S.blocked[entry.path] = nil
                S.dirtyFull = true
            end, 5)
        else
            addItem("Block Remote",    "🚫", function()
                S.blocked[entry.path] = true
                S.dirtyFull = true
            end, 5, true)
        end

        if isIgnored then
            addItem("Unignore Remote", "👁",  function()
                S.ignored[entry.path] = nil
                S.dirtyFull = true
            end, 6)
        else
            addItem("Ignore Remote",   "🙈", function()
                S.ignored[entry.path] = true
                S.dirtyFull = true
            end, 6)
        end

        -- Separator
        frame(menu, { Size = UDim2.new(1, -16, 0, 1),
            BackgroundColor3 = T.BorderSub, LayoutOrder = 7 })

        if isWhitelisted then
            addItem("Remove Whitelist","⚪", function()
                CFG.Spam.whitelist[entry.path] = nil
            end, 8)
        else
            addItem("Spam Whitelist",  "⭐", function()
                CFG.Spam.whitelist[entry.path] = true
                local r = Spam._records[entry.path]
                if r and r.flagged then
                    r.flagged       = false
                    Spam._flagCount = math.max(0, Spam._flagCount - 1)
                end
            end, 8)
        end

        addItem("Clear Spam Record","🗑️", function()
            Spam._records[entry.path]      = nil
            local idx = table.find(Spam._trackedPaths, entry.path)
            if idx then table.remove(Spam._trackedPaths, idx) end
        end, 9, true)

        -- Position menu, clamp to viewport
        local vp = workspace.CurrentCamera.ViewportSize
        local mx = math.min(pos.X, vp.X - 200)
        local my = math.min(pos.Y, vp.Y - (menu.AbsoluteSize.Y + 10))
        menu.Position = UDim2.fromOffset(mx, my)
        menu.Visible  = true

        -- Animate: fade + slight slide up
        menu.BackgroundTransparency = 1
        menu.Position = UDim2.fromOffset(mx, my + 6)
        tween(menu, TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0,
            Position = UDim2.fromOffset(mx, my),
        })
    end

    local function hideCtx()
        menu.Visible = false
    end

    -- Dismiss on click outside
    UIS.InputBegan:Connect(function(inp)
        if not menu.Visible then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.MouseButton2 then
            local mp  = inp.Position
            local ap  = menu.AbsolutePosition
            local as  = menu.AbsoluteSize
            local hit = mp.X >= ap.X and mp.X <= ap.X + as.X
                     and mp.Y >= ap.Y and mp.Y <= ap.Y + as.Y
            if not hit then hideCtx() end
        end
    end)

    return { showCtx = showCtx, hideCtx = hideCtx, menu = menu }
end

return buildContextMenu
