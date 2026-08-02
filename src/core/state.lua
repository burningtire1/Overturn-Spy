--[[
    @module  State
    @file    src/core/state.lua
    @desc    Shared runtime state table — single source of truth passed between
             all subsystems via the S upvalue in the bundled script.

    Fields:
        active       bool        Whether the spy is currently hooking
        paused       bool        Whether new entries are suppressed
        tab          string      Currently selected tab ID
        query        string      Current search/filter string
        logs         table       Array of LogEntry objects (bounded to CFG.MaxLogs)
        activeRows   table       Array of Frame objects currently in the scroll list
        blocked      table       Set of paths the user explicitly blocked
        ignored      table       Set of paths the user explicitly ignored
        customTabs   table       Map of tabId → CustomTabDef added by plugins
        dirty        bool        Single new row to prepend (non-destructive)
        dirtyFull    bool        Full list rebuild required (tab/filter change)
        lastRebuild  number      os.clock() of last full rebuild
        rowOrderCtr  number      Decrementing LayoutOrder counter (newest = lowest)
        visCount     number      Count of visible (non-hidden) entries since last clear
        totalCount   number      Total entries ever received this session
        spamCount    number      Total spam-dropped entries

    LogEntry fields:
        id           number      Unique autoincrement
        remote       Instance    The actual remote object (may be GC'd)
        path         string      Fully-qualified remote path
        type         string      "RemoteEvent" | "RemoteFunction" | "UnreliableRemoteEvent" | "ReturnValue"
        args         table       Array of arguments received
        timestamp    number      os.clock() value
        spam         bool        Flagged as spam
        blocked      bool        Was in the blocked set at log time
        row          Frame?      Currently-rendered GUI row (nil when evicted)
]]

local S = {
    active       = false,
    paused       = false,
    tab          = "ALL",
    query        = "",
    logs         = {},
    activeRows   = {},
    blocked      = {},
    ignored      = {},
    customTabs   = {},
    dirty        = false,
    dirtyFull    = false,
    lastRebuild  = 0,
    rowOrderCtr  = 2^31,
    visCount     = 0,
    totalCount   = 0,
    spamCount    = 0,
    _idCtr       = 0,
}

local function nextId()
    S._idCtr += 1
    return S._idCtr
end

-- Push a new LogEntry onto S.logs (and evict oldest if over limit)
local function pushEntry(entry)
    entry.id = nextId()
    table.insert(S.logs, 1, entry)
    if #S.logs > CFG.MaxLogs then
        local evicted = table.remove(S.logs)
        -- Release GUI row so the frame can be GC'd
        if evicted.row then
            evicted.row:Destroy()
            evicted.row = nil
        end
    end
    S.totalCount += 1
    return entry
end

return { S = S, pushEntry = pushEntry }
