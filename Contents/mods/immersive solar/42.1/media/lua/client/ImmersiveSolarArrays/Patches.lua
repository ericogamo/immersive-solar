require "TimedActions/ISInventoryTransferAction"

local ISA = require "ImmersiveSolarArrays/Utilities"

local original = ISInventoryTransferAction.perform

ISInventoryTransferAction.perform = function(self)
    local item = self.item
    local src = self.srcContainer
    local dst = self.destContainer
    local character = self.character

    local result = original(self)

    if not item or not dst then
        return result
    end

    local srcParent = src and src:getParent()
    local dstParent = dst and dst:getParent()

    if not (srcParent or dstParent) then
        return result
    end


    sendClientCommand(character, "ISA", "TransferAction", {
        transferItem = item,
        sourceContainer = src,
        destContainer = dst,
        srcX = srcParent and srcParent:getX(),
        srcY = srcParent and srcParent:getY(),
        srcZ = srcParent and srcParent:getZ(),
        dstX = dstParent and dstParent:getX(),
        dstY = dstParent and dstParent:getY(),
        dstZ = dstParent and dstParent:getZ(),
    })

    return result
end
