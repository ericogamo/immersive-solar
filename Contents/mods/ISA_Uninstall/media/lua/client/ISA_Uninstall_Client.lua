--[[
    ISA Safe Uninstaller — Client
    Shows cleanup notification to the player.
--]]

local notified = false

-- ============================================================
-- Show completion message above player
-- ============================================================
local function showMessage(text, r, g, b)
    local player = getPlayer()
    if not player then return end
    if HaloTextHelper then
        HaloTextHelper.addTextWithArrow(player, true, text, true, HaloTextHelper.getColorWhite())
    end
end

-- ============================================================
-- Listen for server completion notification (Multiplayer)
-- ============================================================
local function onServerCommand(module, command, args)
    if module ~= "ISA_Uninstall" then return end
    if command == "complete" and not notified then
        notified = true
        local total = (args.powerbanks or 0) + (args.panels or 0) + (args.failsafes or 0) + (args.solarboxes or 0)
        showMessage("[ISA Uninstall] " .. total .. " objects removed. Save and disable both ISA mods!")
    end
end

-- ============================================================
-- Singleplayer: show message on game start
-- ============================================================
local function onGameStart()
    if isClient() then return end -- MP client waits for server command
    -- In SP, the server script runs first, so we just show a delayed message
    local tickCount = 0
    local function delayedMessage()
        tickCount = tickCount + 1
        if tickCount > 60 then -- ~1 second delay
            Events.OnTick.Remove(delayedMessage)
            if not notified then
                notified = true
                showMessage("[ISA Uninstall] Cleanup done! Save and disable both ISA mods.")
            end
        end
    end
    Events.OnTick.Add(delayedMessage)
end

Events.OnServerCommand.Add(onServerCommand)
Events.OnGameStart.Add(onGameStart)
