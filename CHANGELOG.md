# Immersive Solar Arrays [B42 MP] - Changelog

---

## 1. Steam Workshop Change Notes (BBCode - for Steam Workshop Changelog Tab)

[h1]🔧 Hotfix: Fixed Mod Not Loading in B42.20.2 (Items Missing / Sandbox Error)[/h1]

[b]Fix:[/b]
[list]
[*] [b]FIX - Mod Fails to Load in B42.20.2:[/b] Resolved an issue where the mod would not load correctly in Build 42.20.2, causing items to not appear in Debug mode or Admin Items mode. The game's updated Translator now processes Sandbox tooltip strings through Java's [code]String.format()[/code], which interprets literal [code]%[/code] characters (e.g. "12% is realistic") as format specifiers — causing [code]java.util.UnknownFormatConversionException: Conversion = 'i'[/code]. Fixed by escaping all [code]%[/code] as [code]%%[/code] in the Solar Panel Efficiency tooltip across all 27 languages.
[/list]

---

[h1]📢 Previous Update: Fixed Indoor Generator Toxic Gas, Infinite Error Spam & B42 Multiplayer Compatibility[/h1]

[b]Fixes & Improvements:[/b]
[list]
[*] [b]CRITICAL FIX - Indoor Generator Toxic Gas ("Lethal Vapors") Fixed:[/b] Resolved an urgent issue where placing a Battery Bank / PowerBank indoors caused players to suffer from lethal toxic generator fumes ([i]"tötliche Dämpfe"[/i]). In Build 42, any activated [code]IsoGenerator[/code] tile inside a building automatically causes vanilla Project Zomboid to set [code]building.setToxic(true)[/code] whenever chunks load or update. Previously, the mod only reset this flag once every 10 in-game minutes. Added real-time tick-based toxicity protection ([code]PBSystem.preventToxicBuildings[/code]) on both server and client, guaranteeing that indoor Battery Banks never poison players!
[*] [b]CRITICAL FIX - Server Electricity & Automatic Grid Connection Fixed:[/b] Fixed an issue where Battery Banks on multiplayer servers stopped providing electricity to buildings or appliances (like TV/Radio) after chunk reloads, placement, or toggling ON. Previously, changing [code]setConnected(true)[/code] or [code]setActivated(true)[/code] on the server modified Java memory but never transmitted a synchronization packet to multiplayer clients. Added mandatory [code]gen:sync()[/code] and [code]gen:updateSurroundingNow()[/code] calls on the server whenever a Battery Bank updates, ensuring the electrical grid is immediately synchronized across the server and all player clients!
[*] [b]CRITICAL FIX - Duplicate Battery Bank Placement Fixed:[/b] Resolved a bug where placing or crafting a Battery Bank placed two Battery Banks on the same tile. In Build 42, [code]replaceIsoObjectWithGenerator[/code] was triggered twice (once by [code]Events.OnObjectAdded[/code] and once by [code]BuildRecipeCode.OnCreate[/code]). Added duplicate detection and tile cleanup so exactly one Battery Bank is placed!
[*] [b]CRITICAL FIX - Console Error Spam & Log Bloat Fixed:[/b] Resolved a severe bug where [code]PowerBankSystem_Client.lua[/code] threw 60 errors per second ([i]java.lang.RuntimeException: attempted index: setAcceptItemFunction of non-table: null[/i]) when checking nearby Battery Banks. In Build 42, containers on client tiles can initially be null; when the script crashed, the tile was never removed from the processing queue, causing an infinite 60fps retry loop. Added defensive null-checks, automatic container initialization, and error trapping ([code]pcall[/code]) to permanently prevent console spam.
[*] [b]CRITICAL FIX - Multiplayer Server TimedAction Crash Fixed:[/b] Resolved server-side [i]java.lang.NullPointerException[/i] in [code]NetTimedAction.perform[/code] when activating powerbanks, connecting backup generators, or linking solar panels in Multiplayer. In Build 42, TimedAction methods like [code]complete()[/code] and [code]isValid()[/code] must return a boolean on all execution paths. Added explicit boolean returns across all TimedActions.
[*] [b]Crafting & Build Menu Fixed:[/b] Battery Bank, Solar Panels, Inverters, and Failsafes previously did not appear in the Build 42 Crafting Menu because the [i]Solar[/i] category is ignored by the B42 UI. All recipes are now properly listed under the [b]Electrical[/b] tab!
[*] [b]Build 42 JSON Localization:[/b] Full conversion of all 27 supported languages (200+ files) to the new B42 JSON format ([i]IG_UI, ContextMenu, ItemName, Recipes, Tooltip, Moveables, Sandbox, Stash[/i]). No more missing UI names or English fallback text!
[*] [b]Script Startup Crash Fixed:[/b] Removed deprecated [code]require("recipecode")[/code] call in [i]ISA_recipecode.lua[/i] that caused script loading to abort in Build 42.
[*] [b]Audio / Mute Crash Fixed:[/b] Resolved nil pointer exception in [code]mutePowerbanks[/code] ([i]PowerBankSystem_Client.lua[/i]) when accessing generator sound emitters in Build 42.
[*] [b]UI & Performance Optimizations:[/b] Removed duplicate [code]Events.OnTick[/code] registration for audio muting, throttled mute checks to ~2 seconds, and reduced garbage collection overhead via color table hoisting and spatial scan caching.
[/list]

---

## 2. Git Release Notes & Technical Changelog (Markdown - for Git / GitHub / Release Tag)

### v42.1.3 - Hotfix: B42.20.2 Sandbox Translation Format Crash

#### 🐛 Bug Fixes
- **Sandbox Tooltip Format Exception (`Translate/*/Sandbox_*.txt`, `Translate/*/Sandbox.json`)**:
  - **Issue**: In PZ Build 42.20.2, TIS added `Translator.reportMissingArgumentsFromPastAbuse` which passes all translation strings through Java's `String.format()` for format specifier validation. The `Sandbox_ISA_solarPanelEfficiency_tooltip` string contained unescaped literal `%` characters (e.g. `12% is realistic`, `25% is modern solar`). Java's `Formatter` interprets `% i` as an invalid format conversion `%i`, throwing `java.util.UnknownFormatConversionException: Conversion = 'i'` at startup. This exception prevented the mod's sandbox options from loading, which cascaded into items not appearing in Debug/Admin Items mode.
  - **Fix**: Escaped all literal `%` as `%%` (Java's format-safe percent literal) in the `solarPanelEfficiency_tooltip` string across all 27 language directories (54 files: `.txt` + `.json` per language). Covers all regional `%` placement variants: `12%%`, `%% 12` (Turkish), `12 %%` (Czech, German, Finnish, Norwegian).

---

### v42.1.2 - Indoor Generator Toxicity Protection, Container Error Spam Fix & B42 Localization

#### 🐛 Bug Fixes
- **Indoor Generator Toxicity Protection (`PowerBankSystem_Server.lua`, `PowerBankSystem_Client.lua`, `PowerBankObject_Server.lua`)**:
  - **Issue**: Players reported lethal toxic generator vapors inside buildings containing active Battery Banks / PowerBanks. In Project Zomboid Build 42, `IsoGenerator.update()` and `IsoChunk` loading logic check any activated generator tile (`isActivated() == true`) inside an indoor building (`building != null`) and invoke `building.setToxic(true)`, sending network packets and poisoning characters inside. Because `updateGenerator()` only called `building:setToxic(false)` every 10 in-game minutes, buildings remained toxic between updates or whenever chunks reloaded.
  - **Fix**:
    - Added `PBSystem.preventToxicBuildings` registered to `Events.OnTick` on both Server and Client.
    - Continuously inspects active PowerBank objects (`pb.on == true`) and safely calls `building:setToxic(false)` only if `building:isToxic() == true`, instantly preventing toxic damage without generating redundant network traffic.
    - Added explicit toxicity suppression to `loadGenerator()` in `PowerBankObject_Server.lua`.
- **Multiplayer Electrical Grid & Client Synchronization (`PowerBankObject_Server.lua`)**:
  - **Issue**: Battery Banks on dedicated multiplayer servers did not power surrounding appliances (e.g. televisions, lights, fridges) on player clients (`"sie gibt kein strom ab. ich kann den fehrnsher nicht an machen"`). Previously, modifying `generator:setConnected(true)` or `generator:setActivated(true)` on the server changed Java server memory but never sent a network synchronization packet (`syncIsoObjectSend`) to connected clients.
  - **Fix**:
    - Added mandatory `gen:sync()` and `gen:updateSurroundingNow()` calls inside `updateGenerator()` and `loadGenerator()` in `PowerBankObject_Server.lua`.
    - Updated generator lookup logic to prioritize `self:getIsoObject()` with automatic fallback to `square:getGenerator()`, ensuring the exact Battery Bank `IsoGenerator` tile is updated and synchronized across all multiplayer clients.
- **Infinite OnTick Error Spam (`PowerBankSystem_Client.lua`, `MapObjects.lua`)**:
  - **Issue**: `java.lang.RuntimeException: attempted index: setAcceptItemFunction of non-table: null` thrown at `PowerBankSystem_Client.lua:46`. In Build 42, client-side `IsoGenerator` tiles do not always have an initialized `ItemContainer` immediately upon chunk load. Because the unhandled exception aborted `o.process()` before `table.remove(o.data, i)` could execute, the tile remained in the processing queue and retried **60 times per second**, spamming the console and inflating log files.
  - **Fix**:
    - Added defensive `nil`-checks and automatic fallback via `createContainersFromSpriteProperties()` in `PBSystem.processNewLua`, `PBSystem.resetAcceptItemFunction`, and `PBSystem.updateBanksForClient`.
    - Wrapped processing loops in `pcall` (protected call) to guarantee that even if an unexpected exception occurs, the affected square is caught and safely removed from `o.data` without causing infinite retry loops.
    - Updated `LoadPowerbank` in `MapObjects.lua` to check container validity on both server and client chunk loads.
- **Multiplayer Server TimedAction Crash (`ActivatePowerbank.lua`, `ConnectBackup.lua`, `ConnectPanel.lua`)**:
  - **Issue**: `java.lang.NullPointerException: Cannot invoke "java.lang.Boolean.booleanValue()" because the return value of ... is null at NetTimedAction.perform(NetTimedAction.java:140)` on dedicated servers.
  - **Fix**: In Project Zomboid Build 42, `NetTimedAction.perform()` invokes `action:complete()` and expects a non-null `Boolean` return value. Added explicit `return true` (and `return false` on error paths) across all TimedActions and made `isValid()` null-safe.
- **Crafting & Build Menu (`42.1/media/scripts/entities/entity_*.txt`)**:
  - Replaced unsupported crafting category `category = Solar,` with `category = Electrical,` across all entity scripts (`entity_powerbank.txt`, `entity_flatpanel.txt`, `entity_mountedpanel.txt`, `entity_solarfailsafe.txt`, `entity_wallpanel.txt`).
  - Ensures all build and craft recipes appear correctly under the **Electrical** tab in the PZ Build 42 Crafting UI (`B` key).
- **Script Loading Crash (`ISA_recipecode.lua`)**:
  - Removed deprecated `require "recipecode"` statement (legacy B41 script removed in PZ B42) which caused `require("recipecode") failed` and aborted recipe script execution.
- **Sound Mute Nil Pointer Exception (`PowerBankSystem_Client.lua`, `ActivatePowerbank.lua`)**:
  - Fixed `Object tried to call nil in mutePowerbanks` by validating `gen.getEmitter and gen:getEmitter() ~= nil` before invoking `getEmitter()`, with fallback to `gen:stopSound()`.

#### 🌍 Localization (Build 42 JSON System)
- **Full JSON Dictionary Migration (`42.1/media/lua/shared/Translate/<LANG>/`)**:
  - Converted legacy `.txt` translation tables to UTF-8 `.json` dictionaries across all **27 supported language codes** (216 JSON files total).
  - Synchronized localization files for `IG_UI`, `ContextMenu`, `ItemName`, `Recipes`, `Tooltip`, `Moveables`, `Sandbox`, and `Stash`.

#### ⚡ Performance & Code Cleanup
- **Event Mute Throttling (`PowerBankSystem_Client.lua`)**:
  - Removed duplicate `Events.OnTick.Add(PBSystem.mutePowerbanks)` registration.
  - Throttled audio checks to run once every 120 ticks (~2 seconds) instead of every frame.
- **UI Render Loop (`ISAUI.lua`)**:
  - Hoisted color table allocations (`fgBar`, `fgText`) out of per-frame `ISInventoryPane_drawItemDetails_patch` to eliminate GC thrashing.
- **Spatial Scanning (`SolarScan.lua`, `ISAStatusWindowDetailsView.lua`)**:
  - Implemented result caching and throttling for `getGeneratorsInAreaInfo` to reduce CPU overhead during UI rendering.
  - Hoisted constant boolean conditions out of innermost spatial scan loops in server-side solar scanning.
