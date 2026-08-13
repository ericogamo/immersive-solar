require "TimedActions/ISBaseTimedAction"
---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"

ISA_ActivatePowerBank = ISBaseTimedAction:derive("ISA_ActivatePowerBank")

function ISA_ActivatePowerBank:new(character, powerbank, activate, x, y, z)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.activate = activate
    o.isoPb = powerbank
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()

    o.x = x
    o.y = y
    o.z = z

    return o
end

function ISA_ActivatePowerBank:isValid()
    return self.isoPb and self.isoPb:getObjectIndex() ~= -1 or false
end

function ISA_ActivatePowerBank:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 40 - 3 * self.character:getPerkLevel(Perks.Electricity)
end

function ISA_ActivatePowerBank:complete()
    if isClient() then
        sendClientCommand(self.character, "ISA", "activatePowerbank", {
            pb = { x = self.x, y = self.y, z = self.z },
            activate = self.activate
        })
        return true
    end

    local pb = ISA.PBSystem_Server:getLuaObjectAt(self.x, self.y, self.z)
    if not pb then return false end

    if self.activate then
        local level = self.character:getPerkLevel(Perks.Electricity)
        if level < 3 and ZombRand(6-2*level) ~= 0 then
            self.activate = false
        end
    end

    pb.on = self.activate
    pb.switchchanged = true
    pb:updateDrain()
    pb:updateGenerator()
    pb:saveData(true)
    return true
end

ISA.ActivatePowerbank = ISA_ActivatePowerBank

return ISA_ActivatePowerBank
