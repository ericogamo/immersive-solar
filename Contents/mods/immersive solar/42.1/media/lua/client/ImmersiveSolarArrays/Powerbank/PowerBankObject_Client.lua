local ISA = require "ImmersiveSolarArrays/Utilities"
require "Map/CGlobalObject"

---@class PowerBankObject_Client : CGlobalObject
---@field luaSystem PowerbankSystem_Client
local PowerBank = CGlobalObject:derive("ISA_PowerBank_Client")

function PowerBank:new(luaSystem, globalObject)
    local o = CGlobalObject.new(self, luaSystem, globalObject)
    o.on = o.on or false
    o.batteries = o.batteries or 0
    o.charge = o.charge or 0
    o.maxcapacity = o.maxcapacity or 0
    o.drain = o.drain or 0
    o.npanels = o.npanels or 0
    o.panels = o.panels or {}
    o.lastHour = o.lastHour or 0
    return o
end

function PowerBank:fromModData(modData)
    if not modData then return end
    self.on = modData["on"] or false
    self.batteries = modData["batteries"] or 0
    self.charge = modData["charge"] or 0
    self.maxcapacity = modData["maxcapacity"] or 0
    self.drain = modData["drain"] or 0
    self.npanels = modData["npanels"] or 0
    self.panels = modData["panels"] or {}
    self.lastHour = modData["lastHour"] or 0
    self.conGenerator = modData["conGenerator"]
end

function PowerBank:shouldDrain()
    local square = self:getSquare()
    if not self.on then return false end
    if self.conGenerator and self.conGenerator.ison then return false end
    if getWorld():isHydroPowerOn() then
        if square and not square:isOutside() then return false end
    end
    return true
end

function PowerBank:getPanelStatus(panel)
    local x,y,z = panel:getX(), panel:getY(), panel:getZ()
    if IsoUtils.DistanceToSquared(x, y, self.x, self.y) <= 400.0 and math.abs(z - self.z) <= 3 then
        for _, panelXYZ in ipairs(self.panels) do
            if x == panelXYZ.x and y == panelXYZ.y and z == panelXYZ.z then return "connected" end
        end
        return "not connected"
    else
        return "far"
    end
end

---checks the square for a panel object and returns the object and status
function PowerBank:getPanelStatusOnSquare(square)
    local panel = ISA.WorldUtil.findTypeOnSquare(square, "Panel")
    if panel ~= nil then
        return panel, square:isOutside() and self:getPanelStatus(panel) or "indoors"
    end
    return nil, ""
end

function PowerBank:getSpriteForOverlay(modCharge)
    if not self.batteries or self.batteries <= 0 then return nil end
    if modCharge == nil then modCharge = self.maxcapacity > 0 and self.charge / self.maxcapacity or 0 end
    
    local tier = math.min(math.max(math.floor((self.batteries - 1) / 4), 0), 4)
    local bracket
    if modCharge < 0.10 then bracket = 0
    elseif modCharge < 0.35 then bracket = 1
    elseif modCharge < 0.65 then bracket = 2
    elseif modCharge < 0.95 then bracket = 3
    else bracket = 4 end
    
    local spriteId = bracket == 0 and (1 + tier) or (16 + tier * 4 + bracket - 1)
    return "solarmod_tileset_01_" .. spriteId
end

function PowerBank:updateSprite(modCharge)
    local newSprite = self:getSpriteForOverlay(modCharge)
    local isoObject = self:getIsoObject()
    if not isoObject then return end
    local attached = isoObject:getAttachedAnimSprite()

    if attached ~= nil then
        for i = 0, attached:size() - 1 do
            local attachedSprite = attached:get(i)
            local attachedName = attachedSprite:getName()
            if attachedName == newSprite then return end
            if attachedName and string.find(attachedName, "^solarmod_tileset_01_") then
                isoObject:RemoveAttachedAnim(i)
                break
            end
        end
    end
    if newSprite ~= nil then
        isoObject:addAttachedAnimSpriteByName(newSprite)
    end
end

return PowerBank
