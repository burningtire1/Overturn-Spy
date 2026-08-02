# Getting Started with Overturn Spy

Overturn is a high-performance Roblox remote spy for use with script executors.  
It hooks into the `__namecall` metamethod to capture every `:FireServer`,  
`:InvokeServer`, and `:FireUnreliableServer` call your client makes.

---

## Requirements

| Executor API          | Used for                                 |
|-----------------------|------------------------------------------|
| `hookmetamethod`      | Intercepting `__namecall`                |
| `getrawmetatable`     | Reading the game metatable               |
| `getnamecallmethod`   | Identifying which method was called      |
| `newcclosure`         | Wrapping the hook safely                 |
| `setclipboard`        | Copy-to-clipboard actions                |
| `gethui` *(optional)* | Protected GUI container (fallback: CoreGui) |

Most modern executors (Synapse X, KRNL, Fluxus, Solara, etc.) satisfy all of these.

---

## Installation

1. Copy the contents of **`overturn.lua`** from this repository.
2. Paste and execute it in your executor's script window.
3. The Overturn window will appear in the top-centre of your screen.

That's it — no extra scripts, no dependencies, no external HTTP calls.

---

## First Use

Once the window opens, Overturn automatically begins capturing remotes.  
The status pill in the title bar shows **LIVE** (green) when active.

### Controls

| Action | How |
|--------|-----|
| Drag window | Click and drag the title bar |
| Minimise | Click **–** (top-right) |
| Close | Click **✕** (top-right) — also removes the hook |
| Pause capture | Click **Pause** in the status bar |
| Clear all logs | Click **Clear** in the status bar |
| Filter by type | Click a tab (Remotes, Functions, Unreliable…) |
| Search | Type in the search box (debounced, 160 ms) |
| Right-click row | Copy path / script / args, block, ignore, spam tools |

---

## Tabs

| Tab | Shows |
|-----|-------|
| **All** | Every non-ignored remote (spam hidden if action=`hide`) |
| **Remotes** | `RemoteEvent` only |
| **Functions** | `RemoteFunction` + return values |
| **Unreliable** | `UnreliableRemoteEvent` only |
| **Spam** | Remotes currently flagged as spam |
| **Blocked** | Paths you've blocked or ignored |

Plugins can add custom tabs — see [plugin-guide.md](plugin-guide.md).

---

## Copying Remote Calls

Right-click any log row and choose:

- **Copy Path** — copies `game.ReplicatedStorage.Remotes.Attack`  
- **Copy as Script** — copies a ready-to-run Lua line, e.g.  
  `game.ReplicatedStorage.Remotes.Attack:FireServer("swing", 42)`  
- **Copy Args** — copies just the argument list

---

## Anti-Spam

Overturn ships with a smart anti-spam engine that prevents noisy games from  
flooding the log with useless entries. See [anti-spam.md](anti-spam.md) for details  
and runtime configuration options.

---

## Plugin API

Overturn exposes a full namespaced Lua API at `_G.__Overturn`.  
See [api-reference.md](api-reference.md) for the complete reference and  
[plugin-guide.md](plugin-guide.md) for a walkthrough with examples.
