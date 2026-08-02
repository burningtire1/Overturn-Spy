--[[
    Overturn Spy v2.0.0 — example plugin
    Demonstrates the full _G.__Overturn API surface.

    Load this in a second executor tab AFTER overturn.lua has run.
]]

local API = _G.__Overturn
assert(API, "Overturn Spy is not loaded. Execute overturn.lua first.")

-- ── 1. Custom Tab ──────────────────────────────────────────────────────────
-- Register a "Combat" tab that shows any remote whose path contains
-- common combat keywords.
API.UI.addTab("COMBAT", "Combat ⚔", function(entry)
    local p = entry.path:lower()
    return p:find("damage")  ~= nil
        or p:find("attack")  ~= nil
        or p:find("hit")     ~= nil
        or p:find("shoot")   ~= nil
        or p:find("kill")    ~= nil
end)

-- ── 2. Log monitoring ─────────────────────────────────────────────────────
-- Print every RemoteFunction call and its return value to the console.
API.Events.onLog.Event:Connect(function(entry)
    if entry.type == "RemoteFunction" then
        print(("[Overturn] RF call: %s"):format(entry.path))
    elseif entry.type == "ReturnValue" then
        -- Pair with previous RF (paths match, type is "ReturnValue")
        local preview = entry.args[1] ~= nil and tostring(entry.args[1]) or "nil"
        print(("[Overturn] RF return: %s → %s"):format(entry.path, preview))
    end
end)

-- ── 3. Spam monitoring ────────────────────────────────────────────────────
-- Auto-whitelist any remote that gets spam-flagged and contains "position"
-- (common heartbeat remote pattern — you may not want to hide these).
API.Events.onSpam.Event:Connect(function(path, record)
    if path:lower():find("position") or path:lower():find("move") then
        API.Spam.whitelist(path)
        API.UI.toast("Auto-whitelisted: " .. path:match("[^.]+$"), "info", 4)
    else
        API.UI.toast("Spam flagged: " .. path:match("[^.]+$"), "warn", 3)
    end
end)

-- ── 4. Ignore common noise ────────────────────────────────────────────────
local IGNORE_PATTERNS = { "heartbeat", "ping", "keepalive", "network" }
API.Events.onLog.Event:Connect(function(entry)
    for _, pat in ipairs(IGNORE_PATTERNS) do
        if entry.path:lower():find(pat) and not API.Remotes.isIgnored(entry.path) then
            API.Remotes.ignore(entry.path)
        end
    end
end)

-- ── 5. Tuning the anti-spam config ────────────────────────────────────────
-- Lower the rate limit if the game is very spammy.
API.Spam.configure({
    rateLimit  = 15,     -- flag remotes firing > 15× per 2 seconds
    dedupMs    = 80,     -- slightly wider dedup window
    action     = "hide", -- hide spam entries rather than blocking them
})

-- ── 6. Confirm plugin loaded ──────────────────────────────────────────────
API.UI.toast("Example plugin loaded ✓", "success", 4)
print("[Overturn/example-plugin] Loaded. API version: " .. API.version)
