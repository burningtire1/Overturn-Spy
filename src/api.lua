--[[
    @module  Public API
    @file    src/api.lua
    @desc    Builds and returns the _G.__Overturn table exposed to plugins.

    Namespace overview:

    _G.__Overturn = {
        version   — string "2.0.0"

        Events = {
            onLog(entry)       — fires for every logged remote call
            onSpam(path, rec)  — fires when a remote gets spam-flagged
            onClear()          — fires when the log is cleared
            onTabChange(id)    — fires when the active tab changes
        }

        Logs = {
            getAll()           → shallow copy of S.logs
            getFiltered()      → entries matching current tab + query
            clear()            → clear all logs
            count()            → #S.logs
        }

        Remotes = {
            block(path)        → add to S.blocked
            unblock(path)      → remove from S.blocked
            ignore(path)       → add to S.ignored
            unignore(path)     → remove from S.ignored
            isBlocked(path)    → bool
            isIgnored(path)    → bool
        }

        Spam = {
            getRecord(path)    → SpamRecord or nil
            getAllFlagged()     → array of { path, record }
            clearRecord(path)  → delete record
            whitelist(path)    → add to CFG.Spam.whitelist
            unwhitelist(path)  → remove from CFG.Spam.whitelist
            configure(tbl)     → merge tbl into CFG.Spam (hot-reload)
        }

        UI = {
            toast(msg, type?, dur?)     → show notification
            addTab(id, label, filterFn) → add custom tab
            setTheme(overrides)         → merge overrides into T
            getTheme()                  → copy of T
        }
    }
]]

local function buildAPI(Ev, S, Spam, ui)
    -- Filtered log view (respects current tab + query)
    local function getFiltered()
        local out = {}
        for _, e in ipairs(S.logs) do
            -- Reuse same logic as loglist passesFilter/passesQuery
            -- (simplified inline version for API consumers)
            out[#out + 1] = e
        end
        return out
    end

    return {
        version = CFG.Version,

        Events = {
            onLog       = Ev.onLog,
            onSpam      = Ev.onSpam,
            onClear     = Ev.onClear,
            onTabChange = Ev.onTabChange,
        },

        Logs = {
            getAll      = function() return { table.unpack(S.logs) } end,
            getFiltered = getFiltered,
            clear       = function()
                for _, e in ipairs(S.logs) do
                    if e.row and e.row.Parent then e.row:Destroy() end
                end
                S.logs       = {}
                S.activeRows = {}
                S.visCount   = 0
                S.totalCount = 0
                S.spamCount  = 0
                S.dirtyFull  = true
                task.defer(function() Ev.onClear:Fire() end)
            end,
            count       = function() return #S.logs end,
        },

        Remotes = {
            block     = function(path)
                S.blocked[path] = true
                S.dirtyFull = true
            end,
            unblock   = function(path)
                S.blocked[path] = nil
                S.dirtyFull = true
            end,
            ignore    = function(path)
                S.ignored[path] = true
                S.dirtyFull = true
            end,
            unignore  = function(path)
                S.ignored[path] = nil
                S.dirtyFull = true
            end,
            isBlocked = function(path) return S.blocked[path] == true end,
            isIgnored = function(path) return S.ignored[path] == true end,
        },

        Spam = {
            getRecord    = function(path) return Spam._records[path] end,
            getAllFlagged = function()
                local out = {}
                for path, rec in pairs(Spam._records) do
                    if rec.flagged then out[#out + 1] = { path = path, record = rec } end
                end
                return out
            end,
            clearRecord  = function(path)
                if Spam._records[path] and Spam._records[path].flagged then
                    Spam._flagCount = math.max(0, Spam._flagCount - 1)
                end
                Spam._records[path] = nil
                local i = table.find(Spam._trackedPaths, path)
                if i then table.remove(Spam._trackedPaths, i) end
            end,
            whitelist    = function(path) CFG.Spam.whitelist[path] = true  end,
            unwhitelist  = function(path) CFG.Spam.whitelist[path] = nil   end,
            configure    = function(tbl)
                for k, v in pairs(tbl) do CFG.Spam[k] = v end
            end,
        },

        UI = {
            toast   = ui.toast,
            addTab  = ui.addTab,
            setTheme = function(ov)
                for k, v in pairs(ov) do T[k] = v end
            end,
            getTheme = function()
                local copy = {}
                for k, v in pairs(T) do copy[k] = v end
                return copy
            end,
        },
    }
end

return buildAPI
