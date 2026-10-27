require "TimedActions/ISBaseTimedAction"
---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"

ISA_ConnectBackup = ISBaseTimedAction:derive("ISA_ConnectBackup")

function ISA_ConnectBackup:new(character, generator, pbX, pbY, pbZ)
    local o = ISBaseTimedAction.new(self, character)
    o.generator = generator
    o.pbX = pbX
    o.pbY = pbY
    o.pbZ = pbZ
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = false
    o.maxTime = o:getDuration()
    return o
end

function ISA_ConnectBackup:isValid()
    return self.generator ~= nil and self.generator:getObjectIndex() ~= -1
end

function ISA_ConnectBackup:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    --base time in minutes at level 3, ~1/3 at level 10
    return SandboxVars.ISA.ConnectPanelMin * (1 - 0.095 * (self.character:getPerkLevel(Perks.Electricity) - 3)) * 0.5 * getGameTime():getMinutesPerDay()
end

function ISA_ConnectBackup:serverStart()
    if not self.generator then return end
    local data = self.generator:getModData()
    local prevDelta = data["connectDelta"]
    if not prevDelta then prevDelta = 0 elseif prevDelta > 90 then prevDelta = 90 end
    data["connectDelta"] = prevDelta

    -- Disconnect the generator initially just in case it was connected somehow
    ISA.PBSystem_Server:onUnPlugGenerator(self.character, self.generator)
    self.generator:transmitModData()
end

function ISA_ConnectBackup:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
    self.sound = self.character:playSound("GeneratorConnect")

    -- Data stored on the generator itself to allow resuming
    local data = self.generator:getModData()
    local prevDelta = data["connectDelta"]
    if not prevDelta then prevDelta = 0 elseif prevDelta > 90 then prevDelta = 90 end
    self:setCurrentTime(self.maxTime * prevDelta / 100)

    if not isClient() and not isServer() then
        self:serverStart()
    end
end

function ISA_ConnectBackup:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

function ISA_ConnectBackup:update()
    self.character:faceThisObject(self.generator)
end

function ISA_ConnectBackup:serverStop()
    if not self.generator or self.generator:getObjectIndex() == -1 then return end
    local progress = self.netAction and self.netAction:getProgress() or self:getJobDelta()
    local delta = math.floor(progress * 100)
    local data = self.generator:getModData()
    if delta > (data.connectDelta or 0) then
        data.connectDelta = delta
        if isServer() then
            self.generator:transmitModData()
        end
    end
end

function ISA_ConnectBackup:stop()
    self.character:stopOrTriggerSound(self.sound)
    if not isClient() and not isServer() then
        self:serverStop()
    end

    ISBaseTimedAction.stop(self)
end

function ISA_ConnectBackup:perform()
    self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.perform(self)
end

function ISA_ConnectBackup:complete()
    if not self.generator or self.pbX == nil or self.pbY == nil or self.pbZ == nil then
        return false
    end

    local data = self.generator:getModData()
    data.connectDelta = 100

    -- When manual, we use the plugGenerator server command with the specific PB we targeted
    if isClient() then
        sendClientCommand(self.character, "ISA", "PlugBackupGenerator", {
            genX = self.generator:getX(),
            genY = self.generator:getY(),
            genZ = self.generator:getZ(),
            pbX = self.pbX,
            pbY = self.pbY,
            pbZ = self.pbZ,
            plug = true
        })
        return true
    end

    -- If running in Singleplayer/Server, perform logic immediately
    local pb = ISA.PBSystem_Server:getLuaObjectAt(self.pbX, self.pbY, self.pbZ)
    if not pb then
        self.generator:transmitModData()
        return false
    end

    pb:connectBackupGenerator(self.generator)
    pb:saveData(true)
    self.generator:transmitModData()
    return true
end

ISA.ConnectBackup = ISA_ConnectBackup

return ISA_ConnectBackup
