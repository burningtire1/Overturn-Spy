# Overturn API Reference

`_G.__Overturn` is available immediately after the script executes.  
All methods are safe to call from any plugin or external script loaded after Overturn.

---

## `_G.__Overturn.version`

```lua
print(_G.__Overturn.version)  -- "2.0.0"
```

---

## Events

All events are `BindableEvent` objects with a `.Event` signal.

### `Events.onLog`
Fires for every remote call that passes the spam filter and is logged.

```lua
_G.__Overturn.Events.onLog.Event:Connect(function(entry)
    -- entry.path      string   — "game.RS.Remotes.Attack"
    -- entry.type      string   — "RemoteEvent" | "RemoteFunction" |
    --                            "UnreliableRemoteEvent" | "ReturnValue"
    -- entry.args      table    — array of arguments received
    -- entry.timestamp number   — os.clock() value
    -- entry.spam      bool     — was spam-flagged at log time
    -- entry.blocked   bool     — was in the blocked set
    -- entry.remote    Instance — the actual remote (may be GC'd later)
    print(entry.path, entry.type)
end)
```

### `Events.onSpam`
Fires when a remote is newly flagged as spam.

```lua
_G.__Overturn.Events.onSpam.Event:Connect(function(path, record)
    -- path    string      — remote path
    -- record.total   number — lifetime call count
    -- record.dropped number — calls silently dropped
    print("Spam detected:", path, "rate:", #record.times)
end)
```

### `Events.onClear`
Fires when the log is cleared (via UI or API).

```lua
_G.__Overturn.Events.onClear.Event:Connect(function()
    print("Log was cleared")
end)
```

### `Events.onTabChange`
Fires when the active tab changes.

```lua
_G.__Overturn.Events.onTabChange.Event:Connect(function(tabId)
    print("Switched to tab:", tabId)
end)
```

---

## Logs

### `Logs.getAll()` → `table`
Returns a shallow copy of the full log array (newest first).

### `Logs.getFiltered()` → `table`
Returns entries matching the currently active tab + search query.

### `Logs.clear()`
Clears all logs and fires `onClear`.

### `Logs.count()` → `number`
Returns the current log count.

---

## Remotes

### `Remotes.block(path)`
Blocks a remote path — prevents the actual remote call from being fired server-side.  
*(Requires the executor hook to intercept before the call reaches the server.)*

### `Remotes.unblock(path)`

### `Remotes.ignore(path)`
Hides a path from the **All** tab (still captured, just not shown there).

### `Remotes.unignore(path)`

### `Remotes.isBlocked(path)` → `bool`

### `Remotes.isIgnored(path)` → `bool`

---

## Spam

### `Spam.getRecord(path)` → `SpamRecord | nil`

```lua
local rec = _G.__Overturn.Spam.getRecord("game.RS.Remotes.Heartbeat")
if rec then
    print("total:", rec.total, "dropped:", rec.dropped, "flagged:", rec.flagged)
end
```

### `Spam.getAllFlagged()` → `{ {path, record}, … }`

### `Spam.clearRecord(path)`
Deletes the sliding-window record; unflag if flagged.

### `Spam.whitelist(path)`
Bypasses all spam checks for this path permanently.

### `Spam.unwhitelist(path)`

### `Spam.configure(options)`
Hot-reload any `CFG.Spam` fields at runtime:

```lua
_G.__Overturn.Spam.configure({
    rateLimit = 30,
    action    = "block",
    dedupMs   = 100,
})
```

---

## UI

### `UI.toast(message, type?, duration?)`

| Param | Type | Default | Values |
|-------|------|---------|--------|
| message | string | — | any text |
| type | string | `"info"` | `"info"` `"success"` `"warn"` `"error"` |
| duration | number | `3` | seconds |

```lua
_G.__Overturn.UI.toast("Plugin loaded!", "success")
_G.__Overturn.UI.toast("Blocked 5 remotes", "warn", 5)
```

### `UI.addTab(id, label, filterFn)`
Add a custom tab to the tab strip.

```lua
_G.__Overturn.UI.addTab("DAMAGE", "Damage", function(entry)
    return entry.path:lower():find("damage") ~= nil
end)
```

### `UI.setTheme(overrides)`
Merge a partial theme table into the active theme:

```lua
_G.__Overturn.UI.setTheme({
    Purple   = Color3.fromRGB(236, 72, 153),   -- pink instead of purple
    PurpleHi = Color3.fromRGB(244, 114, 182),
})
```

### `UI.getTheme()` → `table`
Returns a copy of the current theme colour table.
