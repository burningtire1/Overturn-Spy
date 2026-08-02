# Anti-Spam Engine

Overturn's anti-spam engine protects you from noisy or malicious games that fire  
remotes hundreds of times per second. It operates in two independent layers and  
is fully configurable at runtime.

---

## How It Works

### Layer 1 — Deduplication

When the **same remote fires with identical arguments** within `dedupMs` milliseconds,  
the duplicate calls are silently dropped before they ever reach the log.

This handles games that spam the same payload every frame (e.g. a heartbeat remote  
sending the same player position 60× per second).

**Default:** 60 ms window.

### Layer 2 — Rate Limiting (Sliding Window)

Overturn tracks a sliding window of call timestamps for each remote path.  
If a remote fires more than `rateLimit` times within `rateWindow` seconds, it is  
**flagged as spam**.

Once flagged, the remote's entries:
- Appear in the **Spam** tab
- Are hidden from **All** (if `action = "hide"`)
- Are dropped before logging (if `action = "block"`)
- Are shown everywhere with a **SPAM** badge (if `action = "log"`)

**Auto-unflagging:** The flag clears automatically when the rate drops below  
`rateLimit × hysteresis`. The hysteresis factor (default 0.6) prevents rapid  
flag/unflag oscillation at the threshold.

---

## Configuration

All settings live in `CFG.Spam` and can be changed at runtime via the API:

```lua
_G.__Overturn.Spam.configure({
    enabled    = true,
    rateWindow = 2.0,    -- seconds
    rateLimit  = 20,     -- calls per rateWindow to trigger flag
    dedupMs    = 60,     -- ms for dedup window
    action     = "hide", -- "hide" | "block" | "log"
    hysteresis = 0.6,    -- unflag threshold = rateLimit * this
    maxTracked = 300,    -- max per-remote records before LRU eviction
})
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `true` | Master switch — disable to bypass all spam checks |
| `rateWindow` | number | `2.0` | Sliding window duration in seconds |
| `rateLimit` | number | `20` | Max calls per window before flagging |
| `dedupMs` | number | `60` | Identical-args dedup window in milliseconds |
| `action` | string | `"hide"` | What to do with flagged remotes |
| `hysteresis` | number | `0.6` | Unflag rate = `rateLimit × hysteresis` |
| `maxTracked` | number | `300` | LRU cap on per-remote tracking records |
| `whitelist` | table | `{}` | Paths that bypass all spam checks |

---

## Actions

| Action | Description |
|--------|-------------|
| `"hide"` | Entries are logged with `spam = true`. Hidden from **All**, visible in **Spam** tab. |
| `"block"` | Entries are dropped — never stored in `S.logs`. Invisible to plugins. |
| `"log"` | Entries appear everywhere with a yellow **SPAM** badge. Nothing is hidden. |

---

## Whitelisting

Add a path to the whitelist to completely skip spam checks for it:

```lua
-- Via context menu: right-click any row → "Spam Whitelist"

-- Via API:
_G.__Overturn.Spam.whitelist("game.ReplicatedStorage.Remotes.PlayerPosition")

-- Remove a whitelist entry:
_G.__Overturn.Spam.unwhitelist("game.ReplicatedStorage.Remotes.PlayerPosition")
```

Whitelisted remotes are always logged, even if they fire 1000× per second.

---

## Viewing Spam Stats

```lua
local API = _G.__Overturn

-- All currently flagged remotes
for _, item in ipairs(API.Spam.getAllFlagged()) do
    print(item.path, "total:", item.record.total, "dropped:", item.record.dropped)
end

-- Individual record
local rec = API.Spam.getRecord("game.RS.Remotes.Heartbeat")
if rec then
    print("flagged:", rec.flagged, "rate entries:", #rec.times)
end
```

---

## Spam Events

```lua
_G.__Overturn.Events.onSpam.Event:Connect(function(path, record)
    print(("Remote spam-flagged: %s (rate: %d/%.1fs)"):format(
        path, #record.times, CFG and CFG.Spam.rateWindow or 2.0))
end)
```

---

## LRU Eviction

Overturn keeps a per-remote record for up to `maxTracked` paths (default 300).  
When this limit is reached, the **oldest accessed** record is evicted to free memory.  
The evicted path's flag state is cleaned up automatically.

For games with hundreds of distinct remotes, increase `maxTracked` if you notice  
records being prematurely cleared:

```lua
_G.__Overturn.Spam.configure({ maxTracked = 600 })
```
