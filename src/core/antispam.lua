--[[
    @module  AntiSpam
    @file    src/core/antispam.lua
    @desc    Smart anti-spam engine with two independent layers:

             1. DEDUP — drops identical calls (same remote + same args hash)
                that arrive within CFG.Spam.dedupMs milliseconds of each other.
                Prevents games from hammering the same exact payload every frame.

             2. RATE LIMITER — tracks calls per remote over a sliding time window.
                When a remote fires more than CFG.Spam.rateLimit times within
                CFG.Spam.rateWindow seconds, it is flagged as spam.
                The flag clears automatically when the rate drops below
                rateLimit × hysteresis (prevents oscillation).

             Per-remote records are stored in Spam._records[path] and are
             LRU-evicted once Spam._trackedPaths reaches CFG.Spam.maxTracked.

    CFG.Spam.action controls what happens to flagged remotes:
        "hide"  — entry is logged with entry.spam=true, hidden from the All tab
        "block" — entry is dropped entirely (never reaches S.logs)
        "log"   — entry shows everywhere with a SPAM badge (no hiding)

    Public:
        spamCheck(path, args) → bool  (true = drop this call)
        Spam._records         — table of SpamRecord per path
        Spam._flagCount       — number of currently flagged remotes
]]

-- Depends on: CFG (§3), argsStr (§6), Ev (§4)

local Spam = {
    _records      = {},
    _trackedPaths = {},   -- ordered list for LRU eviction
    _flagCount    = 0,
}

-- djb2-variant string hash of the first ≤3 serialised arguments.
-- Collision chance is acceptably low for dedup purposes.
local function hashArgs(args)
    local s
    if #args == 0 then
        s = ""
    else
        local lim = math.min(#args, 3)
        local p   = table.create(lim)
        -- NOTE: _ser must be in scope (injected from serializer module in bundle)
        for i = 1, lim do p[i] = _ser(args[i]) end
        s = table.concat(p, "|")
        if #s > 128 then s = s:sub(1, 128) end
    end
    local h = 5381
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 0x7FFFFFFF end
    return h
end

local function spamRecord(path)
    local r = Spam._records[path]
    if r then return r end

    if #Spam._trackedPaths >= CFG.Spam.maxTracked then
        local evict = table.remove(Spam._trackedPaths, 1)
        if Spam._records[evict] and Spam._records[evict].flagged then
            Spam._flagCount = math.max(0, Spam._flagCount - 1)
        end
        Spam._records[evict] = nil
    end

    r = {
        times     = {},    -- sliding window of os.clock() values
        lastHash  = -1,    -- hash of last seen args
        lastHashT = 0,     -- os.clock() when lastHash was recorded
        flagged   = false,
        total     = 0,     -- lifetime call count (non-dropped)
        dropped   = 0,     -- calls silently discarded
    }
    Spam._records[path] = r
    table.insert(Spam._trackedPaths, path)
    return r
end

-- Call this for every remote call before deciding to log it.
-- Returns true → caller should discard the call entirely.
local function spamCheck(path, args)
    local cfg = CFG.Spam
    if not cfg.enabled or cfg.whitelist[path] then return false end

    local r   = spamRecord(path)
    local now = os.clock()
    r.total  += 1

    -- Layer 1: dedup
    local h = hashArgs(args)
    if h == r.lastHash and (now - r.lastHashT) * 1000 < cfg.dedupMs then
        r.dropped += 1
        return true
    end
    r.lastHash  = h
    r.lastHashT = now

    -- Layer 2: sliding-window rate limiter
    local cutoff = now - cfg.rateWindow
    local t, head = r.times, 1
    while head <= #t and t[head] < cutoff do head += 1 end
    if head > 1 then
        local n = #t - head + 1
        for i = 1, n     do t[i] = t[i + head - 1] end
        for i = n + 1, #t do t[i] = nil end
    end
    t[#t + 1] = now

    local rate = #t
    if not r.flagged and rate > cfg.rateLimit then
        r.flagged       = true
        Spam._flagCount += 1
        task.defer(function() Ev.onSpam:Fire(path, r) end)
    elseif r.flagged and rate <= math.floor(cfg.rateLimit * cfg.hysteresis) then
        r.flagged       = false
        Spam._flagCount = math.max(0, Spam._flagCount - 1)
    end

    if r.flagged and cfg.action == "block" then
        r.dropped += 1
        return true
    end

    return false
end

return { Spam = Spam, spamCheck = spamCheck }
