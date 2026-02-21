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

    if isClient() then
        sendClientCommand(o.character, "ISA", "DebugPrint", { text = "INIT" })
    else
        print("[ISA Server] INIT")
    end

    return o
end

function ISA_ActivatePowerBank:isValid()
    return self.isoPb:getObjectIndex() ~= -1
end

function ISA_ActivatePowerBank:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 40 - 3 * self.character:getPerkLevel(Perks.Electricity)
end

function ISA_ActivatePowerBank:complete()

    if isClient() then
        sendClientCommand(self.character, "ISA", "DebugPrint", { text = "COMPLETE" })
    else
        print("[ISA Server] COMPLETE")
    end

    print("[########] TEST:", self.test)

    local pb = ISA.PBSystem_Server:getLuaObjectAt(self.x, self.y, self.z)
    if self.activate then
        local level = self.character:getPerkLevel(Perks.Electricity)
        if level < 3 and ZombRand(6-2*level) ~= 0 then
            -- self.isoPb:getSquare():playSound("GeneratorFailedToStart")
            self.activate = false
        end
    end
    if self.activate and pb.charge > 0 then
        -- self.isoPb:getSquare():playSound("GeneratorStarting")
    elseif self.activate then
        -- self.isoPb:getSquare():playSound("GeneratorFailedToStart")
    else
        -- self.isoPb:getSquare():playSound("GeneratorStopping")
    end

    pb.on = self.activate
    pb.switchchanged = true
    pb:updateDrain()
    pb:updateGenerator()
    pb:saveData(true)
end

ISA.ActivatePowerbank = ISA_ActivatePowerBank

return ISA_ActivatePowerBank
