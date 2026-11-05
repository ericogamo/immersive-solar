local ISA = require "ImmersiveSolarArrays/Utilities"

local function getPowerBankParentAt(x, y, z)
    if not x or not y or not z then return nil end

    local square = getSquare(x, y, z)
    if not square then return nil end

    return ISA.WorldUtil.findTypeOnSquare(square, "PowerBank")
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "ISA" then return end

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

    if command == "SyncPowerBank" then
        if not args or not args.x or not args.y or not args.z then return end
        local square = getSquare(args.x, args.y, args.z)
        if not square or not ISA.PBSystem_Server then return end
        local isoObject = ISA.PBSystem_Server:getIsoObjectOnSquare(square) or ISA.WorldUtil.findTypeOnSquare(square, "PowerBank")
        if isoObject then
            if not instanceof(isoObject, "IsoGenerator") then
                isoObject = ISA.WorldUtil.replaceIsoObjectWithGenerator(isoObject)
            end
            if isoObject and ISA.PBSystem_Server:isValidIsoObject(isoObject) then
                ISA.PBSystem_Server:loadIsoObject(isoObject)
            end
        end
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