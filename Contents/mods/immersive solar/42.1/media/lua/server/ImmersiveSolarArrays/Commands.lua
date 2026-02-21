local ISA = require "ImmersiveSolarArrays/Utilities"

local function getPowerBankParentAt(x, y, z)
    if not x or not y or not z then return nil end

    local square = getSquare(x, y, z)
    if not square then return nil end

    return ISA.WorldUtil.findTypeOnSquare(square, "PowerBank")
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "ISA" then return end

    if command == "ActivatePowerBank" then
        local character = player
        local powerbank = args.powerbank
        local activate = args.activate
        ISTimedActionQueue.add(ISA_ActivatePowerBank:new(character, powerbank, activate))
    end

    if command == "ConnectPanel" then
        local character = player
        local panel = args.panel
        local powerbank = args.powerbank
        ISTimedActionQueue.add(ISA_ConnectPanel:new(character, panel, powerbank))
    end
    
    if command == "PlugBackupGenerator" then
        local pb = ISA.PBSystem_Server:getLuaObjectAt(args.pbX, args.pbY, args.pbZ)
        if pb then
            local square = getSquare(args.genX, args.genY, args.genZ)
            local generator = square and square:getGenerator()
            if generator then
                if args.plug then
                    pb:connectBackupGenerator(generator)
                else
                    pb:disconnectBackupGenerator(generator)
                end
                pb:saveData(true)
            end
        end
    end

    if command == "DebugPrint" then
        local text = args.text
        print("[ISA Server] .. " .. text)
    end

    if command == "TransferAction" then
        local item = args.transferItem
        local srcParent = getPowerBankParentAt(args.srcX, args.srcY, args.srcZ)
        local dstParent = getPowerBankParentAt(args.dstX, args.dstY, args.dstZ)

        if ISA.PBSystem_Server then
            ISA.PBSystem_Server:onTransferItem(item, srcParent, dstParent)
        end
    end
end)