--[[
    @module  Log List
    @file    src/ui/loglist.lua
    @desc    The main scrollable list of remote log entries.

    Performance model (two-mode):
        • New entry (S.dirty=true):  prependEntry() — O(1). Creates one row,
          inserts at head of S.activeRows, culls tail beyond CFG.MaxVisible.
          No existing rows are touched.
        • Tab/filter change (S.dirtyFull=true): rebuildAll() — destroys all
          current rows and recreates only entries that pass the current filter.
          Throttled to once every CFG.RebuildMs ms.

    Row layout (40px tall):
        [TYPE BADGE 56px] [PATH text] [ARGS preview] [TIMESTAMP right]

    Returns: { scroll, prependEntry, rebuildAll }
]]

local function buildLogList(inner, onRowClick, onRowRightClick)
    local W, H   = CFG.WinW, CFG.WinH
    local listH  = H - 40 - 34 - 36  -- win - titlebar - tabs - searchbar

    local scroll = mk("ScrollingFrame", {
        Name             = "LogScroll",
        Size             = UDim2.new(1, 0, 0, listH),
        Position         = UDim2.fromOffset(0, 34 + 36),  -- tabs + search
        BackgroundColor3 = T.Bg,
        BorderSizePixel  = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = T.Scrollbar,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize       = UDim2.fromScale(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent           = inner,
    })

    local layout = mk("UIListLayout", {
        SortOrder   = Enum.SortOrder.LayoutOrder,
        Padding     = UDim.new(0, 1),
        Parent      = scroll,
    })

    -- TYPE BADGE colours
    local BADGE_CLR = {
        RemoteEvent            = T.BadgeRE,
        RemoteFunction         = T.BadgeRF,
        UnreliableRemoteEvent  = T.BadgeURE,
        ReturnValue            = T.BadgeRet,
    }
    local BADGE_LBL = {
        RemoteEvent            = " RE ",
        RemoteFunction         = " RF ",
        UnreliableRemoteEvent  = " URE",
        ReturnValue            = " RET",
    }

    -- ── Filter predicate ────────────────────────────────────────────────────
    local function passesFilter(e)
        local tab = S.tab
        if tab == "ALL" then
            if S.ignored[e.path] then return false end
            if e.spam and CFG.Spam.action == "hide" then return false end
            return true
        elseif tab == "REMOTES" then
            return e.type == "RemoteEvent" and not S.ignored[e.path]
        elseif tab == "FUNCTIONS" then
            return (e.type == "RemoteFunction" or e.type == "ReturnValue")
                and not S.ignored[e.path]
        elseif tab == "UNRELIABLE" then
            return e.type == "UnreliableRemoteEvent" and not S.ignored[e.path]
        elseif tab == "SPAM" then
            local rec = Spam._records[e.path]
            return e.spam or (rec and rec.flagged)
        elseif tab == "BLOCKED" then
            return S.blocked[e.path] or S.ignored[e.path]
        else
            local ct = S.customTabs[tab]
            return ct and ct.filter(e) or false
        end
    end

    local function passesQuery(e)
        if S.query == "" then return true end
        local q = S.query
        if e.path:lower():find(q, 1, true) then return true end
        local rec = Spam._records[e.path]
        if rec then
            local argsPreview = argsStr(e.args):lower()
            if argsPreview:find(q, 1, true) then return true end
        end
        return false
    end

    -- ── Build a single row Frame ─────────────────────────────────────────────
    local function buildRow(e)
        local rowClr = T.Surface
        if e.spam then rowClr = Color3.fromRGB(30, 24, 10) end
        if e.blocked then rowClr = Color3.fromRGB(28, 12, 12) end

        local row = frame(scroll, {
            Name             = "Row_" .. e.id,
            Size             = UDim2.new(1, -4, 0, CFG.LogH),
            BackgroundColor3 = rowClr,
            ZIndex           = 2,
            LayoutOrder      = S.rowOrderCtr,
        })
        S.rowOrderCtr -= 1
        corner(row, 5)
        pad(row, 0, 6, 0)

        -- Hover highlight
        row.MouseEnter:Connect(function()
            tween(row, TweenInfo.new(0.08), { BackgroundColor3 = T.SurfaceHigh })
        end)
        row.MouseLeave:Connect(function()
            tween(row, TweenInfo.new(0.08), { BackgroundColor3 = rowClr })
        end)
        row.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                onRowClick(e, row)
            elseif inp.UserInputType == Enum.UserInputType.MouseButton2 then
                onRowRightClick(e, inp.Position)
            end
        end)

        -- Type badge
        local badgeClr = (e.spam and T.BadgeSpam) or BADGE_CLR[e.type] or T.PurpleDim
        local badge = frame(row, {
            Size             = UDim2.fromOffset(40, 22),
            Position         = UDim2.fromOffset(0, 9),
            BackgroundColor3 = badgeClr,
            BackgroundTransparency = 0.25,
            ZIndex           = 3,
        })
        corner(badge, 4)
        label(badge, BADGE_LBL[e.type] or " ?? ", {
            Size       = UDim2.fromScale(1, 1),
            TextColor3 = badgeClr,
            TextSize   = 10,
            Font       = T.FontBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex     = 4,
        })

        -- SPAM badge overlay
        if e.spam then
            local spBadge = frame(row, {
                Size             = UDim2.fromOffset(38, 16),
                Position         = UDim2.fromOffset(44, 12),
                BackgroundColor3 = T.Orange,
                BackgroundTransparency = 0.25,
                ZIndex           = 3,
            })
            corner(spBadge, 3)
            label(spBadge, "SPAM", {
                Size       = UDim2.fromScale(1, 1),
                TextColor3 = T.Orange,
                TextSize   = 9,
                Font       = T.FontBold,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex     = 4,
            })
        end

        local nameOff = e.spam and 86 or 44

        -- Remote name (truncated)
        local parts  = e.path:split(".")
        local name   = parts[#parts] or e.path
        label(row, name, {
            Size       = UDim2.new(0.38, -(nameOff + 8), 1, 0),
            Position   = UDim2.fromOffset(nameOff + 4, 0),
            TextColor3 = T.PurpleHi,
            TextSize   = 13,
            Font       = T.FontBold,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex     = 3,
        })

        -- Args preview
        local preview = argsStr(e.args)
        if #preview > 72 then preview = preview:sub(1, 69) .. "…" end
        label(row, preview ~= "" and "(" .. preview .. ")" or "()", {
            Size       = UDim2.new(0.38, 0, 1, 0),
            Position   = UDim2.new(0.38, -(nameOff) + nameOff + 4, 0, 0),
            TextColor3 = T.TextCode,
            TextSize   = 12,
            Font       = T.FontMono,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex     = 3,
        })

        -- Timestamp (right-aligned)
        local elapsed = string.format("%.2fs", os.clock() - e.timestamp)
        label(row, elapsed, {
            Size       = UDim2.fromOffset(58, CFG.LogH),
            Position   = UDim2.new(1, -62, 0, 0),
            TextColor3 = T.TextMuted,
            TextSize   = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex     = 3,
        })

        -- Slide-in animation
        row.BackgroundTransparency = 1
        tween(row, TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { BackgroundTransparency = 0 })

        e.row = row
        return row
    end

    -- ── Prepend a single entry (O(1)) ────────────────────────────────────────
    local function prependEntry(e)
        if not passesFilter(e) or not passesQuery(e) then return end

        local row = buildRow(e)
        table.insert(S.activeRows, 1, row)

        -- Evict tail row if we're over the visible cap
        if #S.activeRows > CFG.MaxVisible then
            local evicted = table.remove(S.activeRows)
            evicted:Destroy()
            -- Unlink the row from its entry to avoid double-destroy
            for _, entry in ipairs(S.logs) do
                if entry.row == evicted then
                    entry.row = nil
                    break
                end
            end
        end

        S.visCount = math.min(S.visCount + 1, CFG.MaxVisible)
    end

    -- ── Full rebuild (tab/filter change) ─────────────────────────────────────
    local function rebuildAll()
        -- Destroy existing rows
        for _, r in ipairs(S.activeRows) do
            if r and r.Parent then r:Destroy() end
        end
        S.activeRows = {}

        -- Detach row refs from entries
        for _, e in ipairs(S.logs) do e.row = nil end

        local count = 0
        for i = #S.logs, 1, -1 do   -- oldest first so newest ends up at top
            local e = S.logs[i]
            if passesFilter(e) and passesQuery(e) then
                if count < CFG.MaxVisible then
                    buildRow(e)
                    table.insert(S.activeRows, 1, e.row)
                    count += 1
                end
            end
        end
        S.visCount = count
        S.lastRebuild = os.clock()
    end

    return { scroll = scroll, prependEntry = prependEntry, rebuildAll = rebuildAll }
end

return buildLogList
