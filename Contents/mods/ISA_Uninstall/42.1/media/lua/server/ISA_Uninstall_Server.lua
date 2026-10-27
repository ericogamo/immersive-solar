--[[
    ISA Safe Uninstaller — Server
    Removes ALL Immersive Solar Arrays objects from the game world.

    Usage:
    1. Enable BOTH "Immersive Solar Arrays" AND this uninstaller mod
    2. Load your save
    3. Walk around to ALL locations where you placed ISA objects
    4. Watch the console/halo messages for progress
    5. When "ALL CLEAR" appears, save the game
    6. Disable BOTH mods

    Fixes v2:
    - Waits for ISA system to initialize before cleanup
    - Properly handles unloaded chunks via pending queue
    - Removes IsoObjects before clearing GlobalObjects
    - Tracks completion across chunk loads
--]]

if isClient() then return end

-- ============================================================
-- ISA Sprite Lookup Table
-- ============================================================
local ISA_SPRITES = {}

-- PowerBank base
ISA_SPRITES["solarmod_tileset_01_0"] = "PowerBank"

-- PowerBank empty/tier overlays (1-5)
for i = 1, 5 do
    ISA_SPRITES["solarmod_tileset_01_" .. i] = "Overlay"
end

-- Solar Panels
ISA_SPRITES["solarmod_tileset_01_6"]  = "Panel"  -- Wall SW
ISA_SPRITES["solarmod_tileset_01_7"]  = "Panel"  -- Wall SE
ISA_SPRITES["solarmod_tileset_01_8"]  = "Panel"  -- Flat
ISA_SPRITES["solarmod_tileset_01_9"]  = "Panel"  -- Mounted W
ISA_SPRITES["solarmod_tileset_01_10"] = "Panel"  -- Mounted E

-- Failsafe
ISA_SPRITES["solarmod_tileset_01_15"] = "Failsafe"

-- PowerBank charge level overlays (16-35)
for i = 16, 35 do
    ISA_SPRITES["solarmod_tileset_01_" .. i] = "Overlay"
end

-- SolarBox containers
ISA_SPRITES["solarmod_tileset_01_36"] = "SolarBox"
ISA_SPRITES["solarmod_tileset_01_37"] = "SolarBox"
ISA_SPRITES["solarmod_tileset_01_38"] = "SolarBox"

-- ============================================================
-- ISA Item Types
-- ============================================================
local ISA_ITEM_MODULES = { ["ISA"] = true }

-- ============================================================
-- Stats Counter
-- ============================================================
local stats = {
    powerbanks = 0,
    panels = 0,
    failsafes = 0,
    solarboxes = 0,
    overlays = 0,
    items = 0,
    globalObjects = 0,
}

-- ============================================================
-- Pending squares from unloaded chunks (x_y_z -> {x,y,z})
-- These are squares that had tracked GlobalObjects but whose
-- chunks were not loaded during Phase 1.
-- ============================================================
local pendingSquares = {}
local pendingCount = 0

-- Track whether Phase 1 has completed
local phase1Complete = false
-- Track whether all global objects have been cleared from the system
local globalObjectsCleared = false

-- ============================================================
-- Helper: Check if a sprite name belongs to ISA
-- ============================================================
local function isISASprite(textureName)
    if not textureName then return false end
    return ISA_SPRITES[textureName] ~= nil
end

-- ============================================================
-- Helper: Remove ISA items from a container
-- ============================================================
local function cleanContainer(container)
    if not container then return end
    local items = container:getItems()
    if not items then return end
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item then
            local fullType = item:getFullType()
            if fullType then
                local mod = string.match(fullType, "^([^%.]+)%.")
                if mod and ISA_ITEM_MODULES[mod] then
                    container:Remove(item)
                    stats.items = stats.items + 1
                end
            end
        end
    end
end

-- ============================================================
-- Helper: Remove attached ISA overlay sprites from an object
-- ============================================================
local function cleanAttachedSprites(obj)
    if not obj or not obj.getAttachedAnimSprite then return end
    local attached = obj:getAttachedAnimSprite()
    if not attached then return end
    for i = attached:size() - 1, 0, -1 do
        local spr = attached:get(i)
        if spr then
            local name = spr:getName()
            if name and isISASprite(name) then
                obj:RemoveAttachedAnim(i)
                stats.overlays = stats.overlays + 1
            end
        end
    end
end

-- ============================================================
-- Helper: Remove an IsoObject from its square safely
-- ============================================================
local function removeObject(square, obj, category)
    if not obj or not square then return end
    pcall(function()
        if obj.setActivated then obj:setActivated(false) end
        if obj.setConnected then obj:setConnected(false) end
        cleanAttachedSprites(obj)
        cleanContainer(obj.getContainer and obj:getContainer() or nil)
        square:transmitRemoveItemFromSquare(obj)
        obj:removeFromWorld()
        obj:removeFromSquare()
    end)
    if category == "PowerBank" then
        stats.powerbanks = stats.powerbanks + 1
    elseif category == "Panel" then
        stats.panels = stats.panels + 1
    elseif category == "Failsafe" then
        stats.failsafes = stats.failsafes + 1
    elseif category == "SolarBox" then
        stats.solarboxes = stats.solarboxes + 1
    end
end

-- ============================================================
-- Core: Clean a single square of all ISA objects
-- ============================================================
local function cleanSquare(square)
    if not square then return end

    -- Check generator
    local gen = square:getGenerator()
    if gen then
        local md = gen:getModData()
        local tex = gen:getTextureName()
        if (md and md.generatorFullType == "ISA.PowerBank_test")
            or (md and md.generatorFullType and string.find(md.generatorFullType, "solarmod_tileset_01_"))
            or (tex and isISASprite(tex)) then
            removeObject(square, gen, "PowerBank")
        end
    end

    -- Check special objects (panels, failsafes, solarboxes)
    local special = square:getSpecialObjects()
    if special then
        for i = special:size() - 1, 0, -1 do
            pcall(function()
                local obj = special:get(i)
                if obj then
                    local tex = obj:getTextureName()
                    if tex and isISASprite(tex) then
                        removeObject(square, obj, ISA_SPRITES[tex])
                    end
                end
            end)
        end
    end

    -- Check regular objects list
    local objects = square:getObjects()
    if objects then
        for i = objects:size() - 1, 0, -1 do
            pcall(function()
                local obj = objects:get(i)
                if obj and not instanceof(obj, "IsoWorldInventoryObject") and not instanceof(obj, "IsoPlayer") then
                    local tex = obj:getTextureName()
                    if tex and isISASprite(tex) then
                        removeObject(square, obj, ISA_SPRITES[tex])
                    end
                end
            end)
        end
    end
end

-- ============================================================
-- Helper: Make a unique key for a position
-- ============================================================
local function posKey(x, y, z)
    return x .. "_" .. y .. "_" .. z
end

-- ============================================================
-- Phase 1: Clean all tracked global objects via ISA's system
-- ============================================================
local function cleanGlobalObjects()
    local ISA
    local ok = pcall(function()
        ISA = require("ImmersiveSolarArrays/Utilities")
    end)

    if not ok or not ISA then
        print("[ISA Uninstall] WARNING: Could not load ISA Utilities module.")
        return false
    end

    local system = ISA.PBSystem_Server
    if not system or not system.system then
        print("[ISA Uninstall] WARNING: ISA PowerBank system not initialized yet.")
        return false
    end

    local count = system.system:getObjectCount()
    print("[ISA Uninstall] Phase 1: Found " .. count .. " tracked PowerBank global objects")

    -- --------------------------------------------------------
    -- Step 1: Collect all panel squares from lua objects
    -- --------------------------------------------------------
    local panelSquares = {}
    for i = 1, system:getLuaObjectCount() do
        pcall(function()
            local luaObj = system:getLuaObjectByIndex(i)
            if luaObj and luaObj.panels then
                for _, panel in ipairs(luaObj.panels) do
                    table.insert(panelSquares, panel)
                end
            end
        end)
    end

    -- --------------------------------------------------------
    -- Step 2: Clean panel squares that are loaded
    -- Track unloaded ones for later
    -- --------------------------------------------------------
    for _, pos in ipairs(panelSquares) do
        local sq = getSquare(pos.x, pos.y, pos.z)
        if sq then
            cleanSquare(sq)
        else
            -- Chunk not loaded — add to pending queue
            local key = posKey(pos.x, pos.y, pos.z)
            if not pendingSquares[key] then
                pendingSquares[key] = { x = pos.x, y = pos.y, z = pos.z }
                pendingCount = pendingCount + 1
            end
        end
    end

    -- --------------------------------------------------------
    -- Step 3: Clean all global object squares that are loaded
    -- Track unloaded ones for later
    -- --------------------------------------------------------
    for i = 0, count - 1 do
        pcall(function()
            local gObj = system.system:getObjectByIndex(i)
            if gObj then
                local sq = gObj:getSquare()
                if sq then
                    -- Chunk is loaded — clean immediately
                    cleanSquare(sq)
                else
                    -- Chunk NOT loaded — add to pending queue
                    local x, y, z = gObj:getX(), gObj:getY(), gObj:getZ()
                    local key = posKey(x, y, z)
                    if not pendingSquares[key] then
                        pendingSquares[key] = { x = x, y = y, z = z }
                        pendingCount = pendingCount + 1
                    end
                end
                stats.globalObjects = stats.globalObjects + 1
            end
        end)
    end

    -- --------------------------------------------------------
    -- Step 4: NOW remove all global objects from the system
    -- (after IsoObjects on loaded squares have been cleaned)
    -- --------------------------------------------------------
    for i = count - 1, 0, -1 do
        pcall(function()
            local gObj = system.system:getObjectByIndex(i)
            if gObj then
                system.system:removeObject(gObj)
            end
        end)
    end
    globalObjectsCleared = true

    print("[ISA Uninstall] Phase 1 complete: " .. stats.globalObjects .. " global objects processed")
    if pendingCount > 0 then
        print("[ISA Uninstall] " .. pendingCount .. " squares in unloaded chunks — walk to those locations!")
    end

    return true
end

-- ============================================================
-- Forward declaration for notifyProgress (used in onLoadGridsquare)
-- ============================================================
local notifyProgress

-- ============================================================
-- Phase 2: Ongoing chunk scanner
-- Handles BOTH straggler sprites AND pending tracked squares
-- ============================================================
local function onLoadGridsquare(square)
    if not square then return end

    -- Check if this square is in our pending queue
    local key = posKey(square:getX(), square:getY(), square:getZ())
    if pendingSquares[key] then
        cleanSquare(square)
        pendingSquares[key] = nil
        pendingCount = pendingCount - 1
        if pendingCount <= 0 then
            pendingCount = 0
            print("[ISA Uninstall] All pending squares processed!")
            notifyProgress()
        end
        return -- already cleaned this square
    end

    -- Also scan for any ISA sprites not tracked by the system (stragglers)
    local found = false

    local gen = square:getGenerator()
    if gen then
        local md = gen:getModData()
        local tex = gen:getTextureName()
        if (md and md.generatorFullType == "ISA.PowerBank_test")
            or (tex and isISASprite(tex)) then
            found = true
        end
    end

    if not found then
        local special = square:getSpecialObjects()
        if special and special:size() > 0 then
            for i = 0, special:size() - 1 do
                local ok2, _ = pcall(function()
                    local obj = special:get(i)
                    if obj then
                        local tex = obj:getTextureName()
                        if tex and isISASprite(tex) then
                            found = true
                        end
                    end
                end)
                if found then break end
            end
        end
    end

    if found then
        cleanSquare(square)
    end
end

-- ============================================================
-- Phase 3: Clean player inventories
-- ============================================================
local function cleanPlayerInventories()
    local players = getOnlinePlayers()
    if players then
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player then
                cleanContainer(player:getInventory())
            end
        end
    else
        -- Singleplayer
        local player = getPlayer()
        if player then
            cleanContainer(player:getInventory())
        end
    end
end

-- ============================================================
-- Print summary
-- ============================================================
local function printStats()
    print("[ISA Uninstall] ========================================")
    print("[ISA Uninstall]        CLEANUP SUMMARY")
    print("[ISA Uninstall] ========================================")
    print("[ISA Uninstall]   Battery Banks:    " .. stats.powerbanks)
    print("[ISA Uninstall]   Solar Panels:     " .. stats.panels)
    print("[ISA Uninstall]   Failsafes:        " .. stats.failsafes)
    print("[ISA Uninstall]   SolarBoxes:       " .. stats.solarboxes)
    print("[ISA Uninstall]   Overlays:         " .. stats.overlays)
    print("[ISA Uninstall]   Items:            " .. stats.items)
    print("[ISA Uninstall]   Global Objects:   " .. stats.globalObjects)
    print("[ISA Uninstall]   Pending Squares:  " .. pendingCount)
    print("[ISA Uninstall] ========================================")
    if pendingCount > 0 then
        print("[ISA Uninstall] Walk to all ISA locations to clean remaining objects!")
    else
        print("[ISA Uninstall] ALL CLEAR! Save your game, then DISABLE both ISA mods.")
    end
    print("[ISA Uninstall] ========================================")
end

-- ============================================================
-- Notify clients via server command
-- ============================================================
notifyProgress = function()
    local data = {
        powerbanks = stats.powerbanks,
        panels = stats.panels,
        failsafes = stats.failsafes,
        solarboxes = stats.solarboxes,
        pending = pendingCount,
        phase1 = phase1Complete,
        allClear = (phase1Complete and pendingCount <= 0),
    }
    if isServer() then
        sendServerCommand("ISA_Uninstall", "progress", data)
    end
end

-- ============================================================
-- Entry Point — with retry logic for system initialization
-- ============================================================
local initAttempts = 0
local MAX_INIT_ATTEMPTS = 30 -- try for ~30 seconds

local function tryInit()
    initAttempts = initAttempts + 1

    print("[ISA Uninstall] Initialization attempt " .. initAttempts .. "/" .. MAX_INIT_ATTEMPTS)

    -- Try Phase 1
    local success = cleanGlobalObjects()

    if not success and initAttempts < MAX_INIT_ATTEMPTS then
        -- ISA system not ready yet — try again next second
        print("[ISA Uninstall] ISA system not ready, retrying in 1 second...")
        return false
    end

    if not success then
        print("[ISA Uninstall] WARNING: ISA system never initialized. Relying on sprite scanning only.")
        print("[ISA Uninstall] Walk to all ISA locations — objects will be removed as chunks load.")
        globalObjectsCleared = true
    end

    phase1Complete = true

    -- Phase 3: Clean player inventories
    cleanPlayerInventories()

    -- Print results
    printStats()

    -- Notify clients
    notifyProgress()

    return true
end

-- ============================================================
-- Startup: Use OnTick with tick counting for ~1 second delay
-- This ensures SGlobalObjectSystem has time to initialize
-- ============================================================
local tickCount = 0
local TICKS_PER_ATTEMPT = 60 -- ~1 second between attempts
local initDone = false

local function onStartupTick()
    if initDone then
        Events.OnTick.Remove(onStartupTick)
        return
    end

    tickCount = tickCount + 1

    -- First attempt after ~2 seconds to give SGlobalObjectSystem time
    if tickCount < 120 then return end

    -- Try every ~1 second after that
    if (tickCount - 120) % TICKS_PER_ATTEMPT ~= 0 then return end

    local success = tryInit()
    if success then
        initDone = true
        Events.OnTick.Remove(onStartupTick)
    end
end

print("[ISA Uninstall] ========================================")
print("[ISA Uninstall] ISA Safe Uninstaller loaded.")
print("[ISA Uninstall] Waiting for ISA system to initialize...")
print("[ISA Uninstall] ========================================")

Events.OnTick.Add(onStartupTick)

-- Phase 2: Keep scanning chunks for ISA objects (always active)
Events.LoadGridsquare.Add(onLoadGridsquare)
