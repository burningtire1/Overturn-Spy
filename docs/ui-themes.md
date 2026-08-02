# UI Themes

Overturn's purple/matte-black design is defined entirely in the `T` (theme) table.  
Every colour used by the UI references a named key from this table, making  
full re-theming possible without touching any component code.

---

## Theme Table Reference

| Key | Default | Used For |
|-----|---------|----------|
| `Bg` | `rgb(10, 9, 16)` | Window background |
| `Surface` | `rgb(17, 15, 26)` | Title bar, tab bar, status bar |
| `SurfaceAlt` | `rgb(22, 19, 34)` | Search bar, secondary panels |
| `SurfaceHigh` | `rgb(28, 24, 44)` | Hovered buttons, selected tabs |
| `Elevated` | `rgb(24, 21, 37)` | Context menu background |
| `Border` | `rgb(52, 40, 84)` | Outer window stroke |
| `BorderSub` | `rgb(30, 26, 50)` | Inner dividers |
| `Purple` | `rgb(139, 92, 246)` | Primary accent — moon, indicators |
| `PurpleHi` | `rgb(167, 139, 250)` | Remote name text, selected tab label |
| `PurpleLo` | `rgb(109, 68, 210)` | Darker purple accent |
| `PurpleDim` | `rgb(72, 44, 148)` | Unknown badge colour |
| `PurpleBg` | `rgb(22, 14, 48)` | Pill background, glow |
| `Text` | `rgb(228, 220, 255)` | Primary text |
| `TextSub` | `rgb(148, 132, 185)` | Secondary text, inactive tabs |
| `TextMuted` | `rgb(82, 72, 118)` | Timestamps, count labels |
| `TextCode` | `rgb(190, 172, 230)` | Argument preview text |
| `Green` | `rgb(74, 222, 128)` | LIVE pill, success toasts |
| `Red` | `rgb(248, 113, 113)` | Close button, error toasts, block warnings |
| `Orange` | `rgb(251, 146, 60)` | SPAM badges, Pause button, warn toasts |
| `BadgeRE` | `rgb(139, 92, 246)` | RemoteEvent type badge |
| `BadgeRF` | `rgb(59, 130, 246)` | RemoteFunction type badge |
| `BadgeURE` | `rgb(234, 88, 12)` | UnreliableRemoteEvent type badge |
| `BadgeRet` | `rgb(34, 197, 94)` | ReturnValue type badge |
| `BadgeSpam` | `rgb(234, 179, 8)` | Spam-flagged badge override |
| `Scrollbar` | `rgb(70, 54, 118)` | Scroll bar tint |
| `Font` | `GothamMedium` | Default UI font |
| `FontBold` | `GothamBold` | Title, badges, button text |
| `FontSemi` | `Gotham` | Tab labels |
| `FontMono` | `Code` | Argument preview (monospace) |

---

## Applying a Theme Override

Use `_G.__Overturn.UI.setTheme(overrides)` to apply any partial or complete  
theme change at runtime. Only the keys you provide are updated.

```lua
local API = _G.__Overturn

-- Blue / dark theme
API.UI.setTheme({
    Purple    = Color3.fromRGB( 59, 130, 246),
    PurpleHi  = Color3.fromRGB( 96, 165, 250),
    PurpleLo  = Color3.fromRGB( 37, 99, 235),
    PurpleDim = Color3.fromRGB( 29, 78, 216),
    PurpleBg  = Color3.fromRGB(  5, 15, 50),
    BadgeRE   = Color3.fromRGB( 59, 130, 246),
    Border    = Color3.fromRGB( 30, 58, 138),
})
```

> **Note:** `setTheme` updates the colour table; existing GUI instances  
> that have already been created (title bar, etc.) will not retroactively  
> update their colours. Newly-created rows and toasts will use the updated theme.  
> For a full re-render, close and reopen Overturn after applying the theme.

---

## Preset Themes

### Pink / Neon

```lua
_G.__Overturn.UI.setTheme({
    Purple    = Color3.fromRGB(236,  72, 153),
    PurpleHi  = Color3.fromRGB(244, 114, 182),
    PurpleLo  = Color3.fromRGB(219,  39, 119),
    PurpleDim = Color3.fromRGB(131,  24,  67),
    PurpleBg  = Color3.fromRGB( 40,   5,  20),
    BadgeRE   = Color3.fromRGB(236,  72, 153),
    Border    = Color3.fromRGB(157,  23,  77),
})
```

### Cyan / Teal

```lua
_G.__Overturn.UI.setTheme({
    Purple    = Color3.fromRGB( 34, 211, 238),
    PurpleHi  = Color3.fromRGB(103, 232, 249),
    PurpleLo  = Color3.fromRGB(  6, 182, 212),
    PurpleDim = Color3.fromRGB( 14, 116, 144),
    PurpleBg  = Color3.fromRGB(  4,  28,  38),
    BadgeRE   = Color3.fromRGB( 34, 211, 238),
    Border    = Color3.fromRGB( 14, 116, 144),
})
```

### High-Contrast White

```lua
_G.__Overturn.UI.setTheme({
    Bg         = Color3.fromRGB(245, 245, 250),
    Surface    = Color3.fromRGB(230, 228, 240),
    SurfaceAlt = Color3.fromRGB(220, 216, 234),
    Text       = Color3.fromRGB( 20,  15,  40),
    TextSub    = Color3.fromRGB( 80,  70, 120),
    TextMuted  = Color3.fromRGB(140, 130, 170),
    Border     = Color3.fromRGB(160, 140, 210),
})
```
