# Plugin Development Guide

Overturn exposes a rich API at `_G.__Overturn` that lets external scripts extend  
its behaviour without modifying the core source. This guide walks through building  
a real plugin from scratch.

---

## Plugin Loading

A plugin is just a Lua script that runs **after** Overturn has been executed.  
There is no special loader — simply require `_G.__Overturn` in any second script  
you execute in the same session.

```lua
-- Wait for Overturn to initialise (usually instant, but be safe)
local API = _G.__Overturn
if not API then
    warn("Overturn not loaded")
    return
end
```

---

## Minimal Plugin Template

```lua
local API = _G.__Overturn
assert(API, "Overturn is not loaded")

-- Listen for every logged remote
API.Events.onLog.Event:Connect(function(entry)
    -- entry.path, entry.type, entry.args, entry.timestamp, entry.spam
    if entry.type == "RemoteEvent" then
        -- do something
    end
end)

-- Show a toast to confirm the plugin is active
API.UI.toast("MyPlugin loaded", "success")
```

---

## Example: Damage Logger Plugin

Adds a custom **Damage** tab that only shows combat-related remotes,  
and logs every damage call to the console with its numeric argument.

```lua
local API = _G.__Overturn
assert(API, "Overturn is not loaded")

-- 1. Register a custom tab
API.UI.addTab("DAMAGE", "Damage 🗡", function(entry)
    local p = entry.path:lower()
    return p:find("damage") or p:find("attack") or p:find("hit") or false
end)

-- 2. Auto-ignore the noisy heartbeat remote (example)
API.Remotes.ignore("game.ReplicatedStorage.Remotes.Heartbeat")

-- 3. Log damage amounts to executor console
API.Events.onLog.Event:Connect(function(entry)
    if entry.path:lower():find("damage") then
        local amount = entry.args[1]
        if type(amount) == "number" then
            print(("[Overturn/DamageLogger] %s → %d dmg"):format(entry.path, amount))
        end
    end
end)

-- 4. Auto-whitelist any path that fires at reasonable rate
API.Events.onSpam.Event:Connect(function(path, rec)
    if path:lower():find("heartbeat") then
        API.Spam.whitelist(path)
        API.UI.toast("Auto-whitelisted: " .. path, "info")
    end
end)

API.UI.toast("DamageLogger ready", "success")
```

---

## Example: Theme Override Plugin

Switches Overturn to a pink/neon theme.

```lua
local API = _G.__Overturn
assert(API, "Overturn is not loaded")

API.UI.setTheme({
    Purple    = Color3.fromRGB(236,  72, 153),
    PurpleHi  = Color3.fromRGB(244, 114, 182),
    PurpleLo  = Color3.fromRGB(219,  39, 119),
    PurpleDim = Color3.fromRGB(131,  24,  67),
    PurpleBg  = Color3.fromRGB( 40,   5,  20),
    BadgeRE   = Color3.fromRGB(236,  72, 153),
})

API.UI.toast("Pink theme applied!", "info")
```

---

## Example: Remote Blocker Plugin

Block any remote whose name contains "Anti" or "Detect":

```lua
local API = _G.__Overturn
assert(API, "Overturn is not loaded")

API.Events.onLog.Event:Connect(function(entry)
    local name = entry.path:lower()
    if name:find("anti") or name:find("detect") then
        API.Remotes.block(entry.path)
        API.UI.toast("Blocked: " .. entry.path, "warn", 4)
    end
end)

API.UI.toast("AntiBlock plugin active", "success")
```

---

## Entry Object Reference

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Full path of the remote (e.g. `game.RS.Remotes.Fire`) |
| `type` | string | `"RemoteEvent"` / `"RemoteFunction"` / `"UnreliableRemoteEvent"` / `"ReturnValue"` |
| `args` | table | Array of arguments passed to the call |
| `timestamp` | number | `os.clock()` value at call time |
| `spam` | bool | Whether the entry was spam-flagged |
| `blocked` | bool | Whether the path was in the blocked set |
| `remote` | Instance | The actual remote object (may be GC'd later) |

---

## Best Practices

- Always `assert(_G.__Overturn, ...)` at the top of your plugin.
- Use `task.defer` for any heavy work inside `onLog` callbacks.
- Prefer `API.Remotes.ignore` over `API.Remotes.block` unless you specifically  
  need to prevent the call from reaching the server.
- Keep `filterFn` in `addTab` cheap — it runs on every entry during rebuilds.
