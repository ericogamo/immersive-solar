--[[
    ISA Safe Uninstaller — Client
    Shows cleanup progress and instructions to the player.
--]]

local lastPending = -1

-- ============================================================
-- Show message above player's head
-- ============================================================
local function showMessage(text)
    local player = getPlayer()
    if not player then return end
    if HaloTextHelper then
        HaloTextHelper.addTextWithArrow(player, true, text, true, HaloTextHelper.getColorWhite())
    end
end

-- ============================================================
-- Listen for server progress notifications (Multiplayer)
-- ============================================================
local function onServerCommand(module, command, args)
    if module ~= "ISA_Uninstall" then return end
    if command ~= "progress" then return end

    local total = (args.powerbanks or 0) + (args.panels or 0) + (args.failsafes or 0) + (args.solarboxes or 0)
    local pending = args.pending or 0

    if args.allClear then
        showMessage("[ISA] ALL CLEAR! " .. total .. " objects removed. Save & disable both mods!")
    elseif args.phase1 then
        if pending > 0 and pending ~= lastPending then
            lastPending = pending
            showMessage("[ISA] " .. total .. " removed, " .. pending .. " in unloaded chunks. Walk to those locations!")
        elseif pending <= 0 then
            showMessage("[ISA] ALL CLEAR! " .. total .. " objects removed. Save & disable both mods!")
        end
    end
end

-- ============================================================
-- Singleplayer: show message on game start with delay
-- ============================================================
local function onGameStart()
    if isClient() then return end -- MP client waits for server command

    -- In SP, the server script runs first, so we show a delayed message
    local tickCount = 0
    local function delayedMessage()
        tickCount = tickCount + 1
        -- Wait ~5 seconds (300 ticks) to give the server script time to finish Phase 1
        if tickCount > 300 then
            Events.OnTick.Remove(delayedMessage)
            showMessage("[ISA] Uninstaller active. Walk to all ISA locations, then save & disable.")
        end
    end
    Events.OnTick.Add(delayedMessage)
end

Events.OnServerCommand.Add(onServerCommand)
Events.OnGameStart.Add(onGameStart)
