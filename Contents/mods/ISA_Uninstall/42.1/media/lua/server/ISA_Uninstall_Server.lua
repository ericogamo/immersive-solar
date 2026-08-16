--[[
    ISA Safe Uninstaller — Server
    Removes ALL Immersive Solar Arrays objects from the game world.
    
    Usage:
    1. Enable BOTH "Immersive Solar Arrays" AND this uninstaller mod
    2. Load your save
    3. Wait for the "[ISA Uninstall] DONE!" message in console
    4. Walk around to load all chunks where you placed ISA objects
    5. Save the game
    6. Disable BOTH mods
--]]

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
            local ok, _ = pcall(function()
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
            local ok, _ = pcall(function()
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
-- Phase 1: Clean all tracked global objects via ISA's system
-- ============================================================
local function cleanGlobalObjects()
    local ISA
    local ok = pcall(function()
        ISA = require("ImmersiveSolarArrays/Utilities")
    end)

    if not ok or not ISA or not ISA.PBSystem_Server then
        print("[ISA Uninstall] WARNING: Could not access ISA system. Relying on sprite scanning only.")
        return
    end

    local system = ISA.PBSystem_Server
    if not system or not system.system then
        print("[ISA Uninstall] WARNING: ISA system not initialized yet.")
        return
    end

    local count = system.system:getObjectCount()
    print("[ISA Uninstall] Phase 1: Found " .. count .. " tracked PowerBank global objects")

    -- First pass: collect all panel squares from lua objects
    local panelSquares = {}
    for i = 1, system:getLuaObjectCount() do
        local ok2, _ = pcall(function()
            local luaObj = system:getLuaObjectByIndex(i)
            if luaObj and luaObj.panels then
                for _, panel in ipairs(luaObj.panels) do
                    table.insert(panelSquares, panel)
                end
            end
        end)
    end

    -- Clean panel squares tracked by powerbanks
    for _, pos in ipairs(panelSquares) do
        local sq = getSquare(pos.x, pos.y, pos.z)
        if sq then
            cleanSquare(sq)
        end
    end

    -- Clean all global object squares
    for i = count - 1, 0, -1 do
        local ok2, _ = pcall(function()
            local gObj = system.system:getObjectByIndex(i)
            if gObj then
                local sq = gObj:getSquare()
                if sq then
                    cleanSquare(sq)
                end
                stats.globalObjects = stats.globalObjects + 1
            end
        end)
    end

    -- Remove all global objects from the system
    for i = count - 1, 0, -1 do
        pcall(function()
            local gObj = system.system:getObjectByIndex(i)
            if gObj then
                system.system:removeObject(gObj)
            end
        end)
    end

    print("[ISA Uninstall] Phase 1 complete: " .. stats.globalObjects .. " global objects processed")
end

-- ============================================================
-- Phase 2: Ongoing chunk scanner for stragglers
-- ============================================================
local function onLoadGridsquare(square)
    if not square then return end
    -- Quick check: does this square have any ISA content?
    local gen = square:getGenerator()
    if gen then
        local md = gen:getModData()
        local tex = gen:getTextureName()
        if (md and md.generatorFullType == "ISA.PowerBank_test")
            or (tex and isISASprite(tex)) then
            cleanSquare(square)
            return
        end
    end
    local special = square:getSpecialObjects()
    if special and special:size() > 0 then
        for i = 0, special:size() - 1 do
            local ok, _ = pcall(function()
                local obj = special:get(i)
                if obj then
                    local tex = obj:getTextureName()
                    if tex and isISASprite(tex) then
                        cleanSquare(square)
                    end
                end
            end)
            if not ok then break end
        end
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
    print("[ISA Uninstall] ========================================")
    print("[ISA Uninstall] DONE! Save your game, then DISABLE both ISA mods.")
    print("[ISA Uninstall] ========================================")
end

-- ============================================================
-- Notify client via server command
-- ============================================================
local function notifyClients()
    if isServer() then
        sendServerCommand("ISA_Uninstall", "complete", stats)
    end
end

-- ============================================================
-- Entry Point
-- ============================================================
local function onGameStart()
    print("[ISA Uninstall] ========================================")
    print("[ISA Uninstall] Starting ISA Safe Uninstall...")
    print("[ISA Uninstall] ========================================")

    -- Phase 1: Clean tracked global objects
    cleanGlobalObjects()

    -- Phase 3: Clean player inventories
    cleanPlayerInventories()

    -- Print results
    printStats()

    -- Notify clients in MP
    notifyClients()
end

Events.OnGameStart.Add(onGameStart)

-- Phase 2: Keep scanning chunks for ISA objects
Events.LoadGridsquare.Add(onLoadGridsquare)
