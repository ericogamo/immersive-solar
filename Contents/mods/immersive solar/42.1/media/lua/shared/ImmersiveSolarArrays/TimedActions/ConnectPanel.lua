require "TimedActions/ISBaseTimedAction"
---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"

ISA_ConnectPanel = ISBaseTimedAction:derive("ISA_ConnectPanel")

function ISA_ConnectPanel:new(character, panel, x, y, z, pbX, pbY, pbZ)
    local o = ISBaseTimedAction.new(self, character)
    o.panel = panel
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = false
    o.maxTime = o:getDuration()
    o.x = x
    o.y = y
    o.z = z
    o.pbX = pbX
    o.pbY = pbY
    o.pbZ = pbZ
    return o
end

function ISA_ConnectPanel:isValid()
    return self.panel ~= nil and self.panel:getObjectIndex() ~= -1
end

function ISA_ConnectPanel:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    --base time in minutes at level 3, ~1/3 at level 10
    return SandboxVars.ISA.ConnectPanelMin * (1 - 0.095 * (self.character:getPerkLevel(Perks.Electricity) - 3)) * 0.5 * getGameTime():getMinutesPerDay()
end

function ISA_ConnectPanel:serverStart()
    if not self.panel then return end
    local data = self.panel:getModData()
    local prevDelta = data["connectDelta"]
    if not prevDelta then prevDelta = 0 elseif prevDelta > 90 then prevDelta = 90 end
    data["connectDelta"] = prevDelta
    ISA.PBSystem_Server:removePanel(self.panel)
    self.panel:transmitModData()
end

function ISA_ConnectPanel:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
    self.sound = self.character:playSound("GeneratorConnect")

    local data = self.panel:getModData()
    local prevDelta = data["connectDelta"]
    if not prevDelta then prevDelta = 0 elseif prevDelta > 90 then prevDelta = 90 end
    self:setCurrentTime(self.maxTime * prevDelta / 100)
    if not isClient() and not isServer() then
        self:serverStart()
    end
end

function ISA_ConnectPanel:waitToStart()
    self.character:faceThisObject(self.panel)
    return self.character:shouldBeTurning()
end

function ISA_ConnectPanel:update()
    ---TODO add weird texts: oof, why is this taking so long, if I was a better electricial this wouldn't take so long, 
    self.character:faceThisObject(self.panel)
end

function ISA_ConnectPanel:serverStop()
    if not self.panel or self.panel:getObjectIndex() == -1 then return end
    local progress = self.netAction and self.netAction:getProgress() or self:getJobDelta()
    local delta = math.floor(progress * 100)
    local data = self.panel:getModData()
    if delta > (data.connectDelta or 0) then
        data.connectDelta = delta
        if isServer() then
            self.panel:transmitModData()
        end
    end
end

function ISA_ConnectPanel:stop()
    self.character:stopOrTriggerSound(self.sound)
    if not isClient() and not isServer() then
        self:serverStop()
    end

    ISBaseTimedAction.stop(self)
end

function ISA_ConnectPanel:perform()
    self.character:stopOrTriggerSound(self.sound)
    ISBaseTimedAction.perform(self)
end

function ISA_ConnectPanel:complete()
    if not self.panel or self.pbX == nil or self.pbY == nil or self.pbZ == nil then
        return false
    end

    local data = self.panel:getModData()
    data.connectDelta = 100

    if isClient() then
        sendClientCommand(self.character, "ISA", "connectPanel", {
            pb = { x = self.pbX, y = self.pbY, z = self.pbZ },
            panel = { x = self.x, y = self.y, z = self.z }
        })
        return true
    end

    local pb = ISA.PBSystem_Server:getLuaObjectAt(self.pbX, self.pbY, self.pbZ)
    if not pb then
        self.panel:transmitModData()
        return false
    end
    local panel, status = pb:getPanelStatusOnSquare(self.panel:getSquare())
    if status == "not connected" then
        data.pbLinked = { x = pb.x , y = pb.y, z = pb.z }
        table.insert(pb.panels,{x = self.x, y = self.y, z = self.z})
        pb.npanels = pb.npanels + 1
        pb:saveData(true)
    end
    self.panel:transmitModData()
    return true
end

ISA.ConnectPanel = ISA_ConnectPanel

return ISA_ConnectPanel