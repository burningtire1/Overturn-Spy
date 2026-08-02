--[[
    @module  Interactions
    @file    src/ui/interactions.lua
    @desc    Wires the main Heartbeat loop that drives two-mode rendering:

             • If S.dirty (new single entry):  call prependEntry(latest)
             • If S.dirtyFull (tab/filter changed): call rebuildAll() after
               throttle (CFG.RebuildMs ms since last rebuild)

             Also updates the status bar counts each Heartbeat.

             Additionally wires:
               • Minimise / restore animation
               • Clear-all logs action
               • Pause / resume toggle
               • Pill LIVE / PAUSED updates

    Returns: { connections }  — array of RBXScriptConnections to disconnect on cleanup
]]

local RS = game:GetService("RunService")

local function wireInteractions(S, ui)
    local conns   = {}
    local minimised = false

    -- Heartbeat — drives rendering + status bar
    local hb = RS.Heartbeat:Connect(function()
        -- Status bar refresh (every frame is fine — just label text)
        ui.statusBar.updateCounts(
            S.visCount, S.totalCount, S.spamCount, Spam._flagCount)

        -- Two-mode dirty handling
        if S.dirtyFull then
            local now = os.clock()
            if now - S.lastRebuild >= CFG.RebuildMs / 1000 then
                S.dirtyFull = false
                S.dirty     = false
                ui.logList.rebuildAll()
                ui.search.setCount(S.visCount)
            end
        elseif S.dirty then
            S.dirty = false
            local newest = S.logs[1]
            if newest then
                ui.logList.prependEntry(newest)
                ui.search.setCount(S.visCount)
            end
        end
    end)
    conns[#conns + 1] = hb

    -- Pill reflect pause state
    local function updatePill()
        if S.paused then
            tween(ui.titleBar.pillDot,  TweenInfo.new(0.15), { BackgroundColor3 = T.Orange })
            tween(ui.titleBar.pillText, TweenInfo.new(0.15), { TextColor3       = T.Orange })
            ui.titleBar.pillText.Text = "PAUSED"
        else
            tween(ui.titleBar.pillDot,  TweenInfo.new(0.15), { BackgroundColor3 = T.Green  })
            tween(ui.titleBar.pillText, TweenInfo.new(0.15), { TextColor3       = T.Green  })
            ui.titleBar.pillText.Text = "LIVE"
        end
        ui.statusBar.setPaused(S.paused)
    end

    -- Toggle pause
    local function onToggle()
        S.paused = not S.paused
        updatePill()
        ui.toast(S.paused and "Spy paused — no new entries" or "Spy resumed", S.paused and "warn" or "success")
    end

    -- Clear all
    local function onClear()
        for _, e in ipairs(S.logs) do
            if e.row and e.row.Parent then e.row:Destroy() end
        end
        S.logs         = {}
        S.activeRows   = {}
        S.visCount     = 0
        S.totalCount   = 0
        S.spamCount    = 0
        ui.search.setCount(0)
        ui.toast("Log cleared", "info")
    end

    -- Minimise / restore
    local function onMinimise()
        minimised = not minimised
        if minimised then
            tween(ui.bg, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
                { Size = UDim2.fromOffset(CFG.WinW, 40) })
            ui.win.inner.Visible   = false
            ui.statusBarFrame.Visible = false
        else
            ui.win.inner.Visible   = true
            ui.statusBarFrame.Visible = true
            tween(ui.bg, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Size = UDim2.fromOffset(CFG.WinW, CFG.WinH) })
        end
    end

    -- Close
    local function onClose()
        tween(ui.bg, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            { BackgroundTransparency = 1, Size = UDim2.fromOffset(CFG.WinW * 0.9, CFG.WinH * 0.9) })
        task.delay(0.16, function()
            Hooks.remove()
            if ui.gui and ui.gui.Parent then ui.gui:Destroy() end
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        end)
    end

    return {
        onToggle    = onToggle,
        onClear     = onClear,
        onMinimise  = onMinimise,
        onClose     = onClose,
        updatePill  = updatePill,
        connections = conns,
    }
end

return wireInteractions
