# Overturn Spy

<div align="center">

<!-- Moon logo in ASCII for README -->
```
    ██████
  ██      ██
 ██        ██  ██████
 ██        ████      █
 ██          ██      █
  ██        ██████████
    ██████
```

**A high-performance Roblox remote spy.**  
Purple × matte-black. Animated. Smart. Extensible.

[![Version](https://img.shields.io/badge/version-2.0.0-7c3aed?style=flat-square)](https://github.com/burningtire1/Overturn-Spy/releases)
[![License](https://img.shields.io/badge/license-MIT-4f46e5?style=flat-square)](LICENSE)

</div>

---

## Features

| Feature | Overturn | Cobalt |
|---------|----------|--------|
| UnreliableRemoteEvent support | ✅ | ❌ |
| Smart anti-spam engine | ✅ | ❌ |
| Dedup + rate-limit (two layers) | ✅ | ❌ |
| O(1) incremental row rendering | ✅ | ❌ |
| Full namespaced plugin API | ✅ | Partial |
| Custom plugin tabs | ✅ | ❌ |
| Toast notifications | ✅ | ❌ |
| Copy-as-script (all types) | ✅ | ✅ |
| Theme override API | ✅ | ❌ |
| Block / ignore / whitelist | ✅ | ✅ |

---

## Quick Start

1. Open `overturn.lua` and copy its contents
2. Paste and execute in your script executor
3. The window appears automatically — no setup required

---

## UI Overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│  ☽ Overturn  v2.0.0   ● LIVE                                      –   ✕  │
├────────────────────────────────────────────────────────────────────────────┤
│  All │ Remotes │ Functions │ Unreliable │ Spam │ Blocked              │
├────────────────────────────────────────────────────────────────────────────┤
│  🔍  Search remotes, paths, arguments…                      142 entries    │
├────────────────────────────────────────────────────────────────────────────┤
│  RE  Attack          ("swing", 42, Vector3.new(0,5,0))           0.02s     │
│  RF  GetInventory    ()                                           0.04s    │
│ URE  PlayerMove      (CFrame.new(12,3,7) * CFrame.Angles(0,1,0)) 0.01s    │
│  RE  ChatMessage     ("hello world")                              0.10s    │
│ ...                                                                        │
├────────────────────────────────────────────────────────────────────────────┤
│  142 visible  / 238 total   3 spam                    Clear    Pause       │
└────────────────────────────────────────────────────────────────────────────┘
```

**Controls:**
- Drag the title bar to move the window
- **–** minimise | **✕** close (removes hook)
- Right-click any row for the context menu
- **Pause** / **Resume** in the status bar
- **Clear** to wipe all logs

---

## Anti-Spam

Overturn's two-layer spam protection keeps your log clean:

1. **Dedup** — drops identical calls (same remote + same args) within 60 ms
2. **Rate Limiter** — flags remotes firing > 20× in 2 seconds

Configure at runtime:

```lua
_G.__Overturn.Spam.configure({
    rateLimit  = 30,
    action     = "block",   -- "hide" | "block" | "log"
    dedupMs    = 100,
})
```

See [docs/anti-spam.md](docs/anti-spam.md) for full details.

---

## Plugin API

```lua
local API = _G.__Overturn

-- Listen for every remote call
API.Events.onLog.Event:Connect(function(entry)
    print(entry.path, entry.type, entry.args[1])
end)

-- Add a custom tab
API.UI.addTab("COMBAT", "Combat ⚔", function(entry)
    return entry.path:lower():find("attack") ~= nil
end)

-- Show a toast notification
API.UI.toast("Plugin active!", "success")

-- Block a noisy remote
API.Remotes.ignore("game.ReplicatedStorage.Remotes.Heartbeat")

-- Re-theme
API.UI.setTheme({
    Purple = Color3.fromRGB(236, 72, 153),  -- pink
})
```

Full reference: [docs/api-reference.md](docs/api-reference.md)  
Plugin examples: [plugins/example.lua](plugins/example.lua)

---

## Repository Structure

```
Overturn-Spy/
├── overturn.lua          ← Single-file executor script (paste and run)
├── src/
│   ├── core/
│   │   ├── config.lua    ← Theme + CFG tables
│   │   ├── state.lua     ← Shared runtime state (S)
│   │   ├── serializer.lua← Value → Lua string conversion
│   │   ├── antispam.lua  ← Two-layer spam engine
│   │   └── hooks.lua     ← __namecall metamethod hook
│   └── ui/
│       ├── helpers.lua   ← mk / frame / label / tween utilities
│       ├── window.lua    ← Root ScreenGui + window frame
│       ├── titlebar.lua  ← Title bar + moon logo + drag
│       ├── tabs.lua      ← Tab strip + custom tab registration
│       ├── search.lua    ← Search bar with debounce
│       ├── loglist.lua   ← Incremental O(1) log rows
│       ├── ctxmenu.lua   ← Right-click context menu
│       ├── statusbar.lua ← Bottom stats + controls
│       ├── toast.lua     ← Slide-in notification toasts
│       └── interactions.lua ← Heartbeat loop + button wiring
├── src/api.lua           ← _G.__Overturn public API
├── plugins/
│   └── example.lua       ← Annotated plugin template
├── docs/
│   ├── getting-started.md
│   ├── api-reference.md
│   ├── plugin-guide.md
│   ├── anti-spam.md
│   └── ui-themes.md
└── scripts/
    ├── bundle.py         ← Python bundler: src/ → overturn.lua
    ├── bundle.json       ← Module manifest + build config
    └── header.lua        ← Prepended to bundled output
```

---

## Rebuilding from Source

```bash
python scripts/bundle.py
# → overturn.lua rebuilt from src/ modules
```

---

## License

MIT — see [LICENSE](LICENSE).
