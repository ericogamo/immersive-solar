# Immersive Solar Arrays [B42 MP] - Changelog

---

## 1. Steam Workshop Change Notes (BBCode - for Steam Workshop Changelog Tab)

[h1]📢 Update: Build 42.1 Crafting Menu Fix, JSON Localization & Crash Fixes[/h1]

[b]Fixes & Improvements in this update:[/b]
[list]
[*] [b]Crafting & Build Menu Fixed:[/b] Battery Bank, Solar Panels, Inverters, and Failsafes previously did not appear in the Build 42 Crafting Menu because the [i]Solar[/i] category is ignored by the B42 UI. All recipes are now properly listed under the [b]Electrical[/b] tab!
[*] [b]Build 42 JSON Localization:[/b] Full conversion of all 27 supported languages (200+ files) to the new B42 JSON format ([i]IG_UI, ContextMenu, ItemName, Recipes, Tooltip, Moveables, Sandbox, Stash[/i]). No more missing UI names or English fallback text!
[*] [b]Script Startup Crash Fixed:[/b] Removed deprecated [code]require("recipecode")[/code] call in [i]ISA_recipecode.lua[/i] that caused script loading to abort in Build 42.
[*] [b]Audio / Mute Crash Fixed:[/b] Resolved nil pointer exception in [code]mutePowerbanks[/code] ([i]PowerBankSystem_Client.lua[/i]) when accessing generator sound emitters in Build 42.
[*] [b]UI & Performance Optimizations:[/b] Reduced garbage collection overhead via color table hoisting and spatial scan caching.
[/list]

---

## 2. Git Release Notes & Technical Changelog (Markdown - for Git / GitHub / Release Tag)

### v42.1.0 - Build 42 Migration, Crafting Menu Fix & Localization Engine

#### 🐛 Bug Fixes
- **Crafting & Build Menu (`42.1/media/scripts/entities/entity_*.txt`)**:
  - Replaced unsupported crafting category `category = Solar,` with `category = Electrical,` in all entity scripts:
    - `entity_powerbank.txt`
    - `entity_flatpanel.txt`
    - `entity_mountedpanel.txt`
    - `entity_solarfailsafe.txt`
    - `entity_wallpanel.txt`
  - Ensures all build and craft recipes appear correctly under the **Electrical** tab in the PZ Build 42 Crafting UI (`B` key).
- **Script Loading Crash (`ISA_recipecode.lua`)**:
  - Removed deprecated `require "recipecode"` statement (legacy B41 script removed in PZ B42) which caused `require("recipecode") failed` and aborted recipe script execution.
- **Sound Mute Nil Pointer Exception (`PowerBankSystem_Client.lua`, `ActivatePowerbank.lua`)**:
  - Fixed `Object tried to call nil in mutePowerbanks` on line 227 by validating `gen.getEmitter and gen:getEmitter() ~= nil` before invoking `getEmitter()`, with fallback to `gen:stopSound()`.

#### 🌍 Localization (Build 42 JSON System)
- **Full JSON Dictionary Migration (`42.1/media/lua/shared/Translate/<LANG>/`)**:
  - Converted legacy `.txt` translation tables to UTF-8 `.json` dictionaries across all **27 supported language codes** (216 JSON files total).
  - Synchronized localization files for `IG_UI`, `ContextMenu`, `ItemName`, `Recipes`, `Tooltip`, `Moveables`, `Sandbox`, and `Stash`.

#### ⚡ Performance & Code Cleanup
- **UI Render Loop (`ISAUI.lua`)**:
  - Hoisted color table allocations (`fgBar`, `fgText`) out of per-frame `ISInventoryPane_drawItemDetails_patch` to eliminate GC thrashing.
- **Spatial Scanning (`SolarScan.lua`, `ISAStatusWindowDetailsView.lua`)**:
  - Implemented result caching and throttling for `getGeneratorsInAreaInfo` to reduce CPU overhead during UI rendering.
  - Hoisted constant boolean conditions out of innermost spatial scan loops in server-side solar scanning.
