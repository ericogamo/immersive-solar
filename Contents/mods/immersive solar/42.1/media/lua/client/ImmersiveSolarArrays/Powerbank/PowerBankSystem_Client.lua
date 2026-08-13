require "Map/CGlobalObjectSystem"
---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"
local PowerBank = require "ImmersiveSolarArrays/Powerbank/PowerBankObject_Client"

---@class PowerbankSystem_Client : PowerbankSystem, CGlobalObjectSystem
local PBSystem = require("ImmersiveSolarArrays/PowerBankSystem_Shared"):new(CGlobalObjectSystem:derive("ISA_PowerBankSystem_Client"))

function PBSystem:new()
    return CGlobalObjectSystem.new(self, "isa_powerbank")
end

function PBSystem:initSystem()
    ISA.PBSystem_Client = self
    if isClient() then
        Events.EveryTenMinutes.Add(PBSystem.updateBanksForClient)
    end
    --added after server function with sendObjectChange("containers") so SP need only one tick
    Events.EveryDays.Add(PBSystem.resetAcceptItemFunction.addItems)
    
    Events.OnTick.Add(PBSystem.mutePowerbanks)
    Events.OnTick.Add(PBSystem.preventToxicBuildings)
end

function PBSystem:newLuaObject(globalObject)
    return PowerBank:new(self, globalObject)
end

--called by java receiveNewLuaObjectAt
function PBSystem:newLuaObjectAt(x, y, z)
    self:noise("adding luaObject "..x..','..y..','..z)
    local globalObject = self.system:newObject(x, y, z)
    self.processNewLua:addItem(x,y,z)
    return self:newLuaObject(globalObject)
end

do
    local o = ISA.delayedProcess:new{maxTimes=999}

    function o.process()
        if not o.data then return o:stop() end
        for i = #o.data, 1 , -1 do
            local sq = o.data[i]
            local success, err = pcall(function()
                local gen = sq and sq:getGenerator()
                if gen then
                    local isoPb = PBSystem.instance:getIsoObjectOnSquare(sq)
                    if isoPb then
                        local container = isoPb:getContainer()
                        if not container and isoPb.createContainersFromSpriteProperties then
                            isoPb:createContainersFromSpriteProperties()
                            container = isoPb:getContainer()
                        end
                        if container and container.setAcceptItemFunction then
                            container:setAcceptItemFunction("AcceptItemFunction.ISA_Batteries")
                        end
                    end
                    table.remove(o.data, i)
                end
            end)
            if not success then
                table.remove(o.data, i)
            end
        end
        if #o.data == 0 or o.times <= 1 then o:stop() return end
        o.times = o.times - 1
    end

    function o:addItem(x,y,z)
        local square = getSquare(x,y,z)
        if not square then return end
        if not self.data then
            self.data = {}
            self:start()
        end
        self.times = self.maxTimes
        table.insert(self.data, square)
    end

    PBSystem.processNewLua = o
end

do
    local o = ISA.delayedProcess:new{maxTimes=999}

    function o.process()
        if not o.data then return o:stop() end

        for i = #o.data, 1, -1 do
            local obj = o.data[i]
            local success, err = pcall(function()
                if not obj or obj:getObjectIndex() == -1 then
                    table.remove(o.data, i)
                else
                    local container = obj:getContainer()
                    if not container and obj.createContainersFromSpriteProperties then
                        obj:createContainersFromSpriteProperties()
                        container = obj:getContainer()
                    end
                    if not container then
                        table.remove(o.data, i)
                    elseif container.getAcceptItemFunction and container:getAcceptItemFunction() == nil then
                        PBSystem.instance:noise("Container reset")

                        if container.setAcceptItemFunction then
                            container:setAcceptItemFunction("AcceptItemFunction.ISA_Batteries")
                        end
                        triggerEvent("OnContainerUpdate", obj)
                        table.remove(o.data, i)

                        --shortcut for container changed, bugged transfer action
                        local players = IsoPlayer.getPlayers()
                        for p = 0, players:size() - 1 do
                            local player = players:get(p)
                            if player ~= nil and player:getZ() == obj:getZ() and IsoUtils.DistanceToSquared(player:getX(), player:getY(), obj:getX() + 0.5, obj:getY() + 0.5) <= 4 then
                                --clear both java / lua
                                ISTimedActionQueue.clear(player)
                            end
                        end
                    else
                        table.remove(o.data, i)
                    end
                end
            end)
            if not success then
                table.remove(o.data, i)
            end
        end

        if #o.data == 0 or o.times <= 1 then return o:stop() end
        o.times = o.times - 1
    end

    function o.addItems()
        o.data = {}
        for i=1,PBSystem.instance:getLuaObjectCount() do
            local isoObject = PBSystem.instance:getLuaObjectByIndex(i):getIsoObject()
            if isoObject then
                table.insert(o.data,isoObject)
            end
        end
        if #o.data > 0 then
            o.times = o.maxTimes
            o:start()
        else
            o.data = nil
        end
    end
    PBSystem.resetAcceptItemFunction = o
end

function PBSystem.canConnectPanelTo(panel)
    local options = {}

    if not panel:getSquare():isOutside() then
        options.inside = true
        return options
    end

    local x = panel:getX()
    local y = panel:getY()
    local z = panel:getZ()
    local DistanceToSquared, abs = IsoUtils.DistanceToSquared, math.abs
    local jSystem = PBSystem.instance.system

    for i = 0, jSystem:getObjectCount() -1  do
        local pb = jSystem:getObjectByIndex(i):getModData()

        if DistanceToSquared(x, y, pb.x, pb.y) <= 400.0 and abs(z - pb.z) <= 3 then
            pb:updateFromIsoObject()
            local isConnected
            for _, ipanel in ipairs(pb.panels) do
                if x == ipanel.x and y == ipanel.y and z == ipanel.z then
                    isConnected = true
                    break
                end
            end
            table.insert(options, {pb, pb.x-x,pb.y-y, isConnected})
        end
    end

    return options
end

--draw debug num of valid generators
function PBSystem.getGeneratorsInAreaInfo(luaPb, area)
    local getSquare = getSquare
    local DistanceToSquared = IsoUtils.DistanceToSquared

    local generators = 0
    for ix = luaPb.x - area.radius, luaPb.x + area.radius do
        for iy = luaPb.y - area.radius, luaPb.y + area.radius do
            for iz = luaPb.z - area.levels, luaPb.z + area.levels do
                local isquare = getSquare(ix, iy, iz)
                local generator = isquare and luaPb.luaSystem:getValidBackupOnSquare(isquare)
                if generator and DistanceToSquared(luaPb.x,luaPb.y,luaPb.z,ix,iy,iz) <= area.distance then
                    generators = generators + 1
                end
            end
        end
    end
    return generators
end

---FIXME this might run before new data is received, use command instead
function PBSystem.updateBanksForClient()
    for i=1,PBSystem.instance:getLuaObjectCount() do
        local pb = PBSystem.instance:getLuaObjectByIndex(i)
        local isopb = pb:getIsoObject()
        if isopb then
            pb:fromModData(isopb:getModData())
            local delta = pb.maxcapacity > 0 and pb.charge / pb.maxcapacity or 0
            if pb.updateSprite then
                pb:updateSprite(delta)
            end
            local container = isopb:getContainer()
            if not container and isopb.createContainersFromSpriteProperties then
                isopb:createContainersFromSpriteProperties()
                container = isopb:getContainer()
            end
            if container and container.getItems then
                local items = container:getItems()
                for v=0,items:size()-1 do
                    local item = items:get(v)
                    --FIXME all items should be valid batteries and drainable here already
                    if item:getModData().ISA_maxCapacity then
                        item:setCurrentUsesFloat(delta)
                    end
                end
            end
        end
    end
end

function PBSystem.mutePowerbanks()
    if not PBSystem.instance then return end
    for i=1,PBSystem.instance:getLuaObjectCount() do
        local pb = PBSystem.instance:getLuaObjectByIndex(i)
        local isopb = pb:getIsoObject()
        if isopb then
            local square = isopb:getSquare()
            local gen = square and square:getGenerator()
            if not gen and instanceof(isopb, "IsoGenerator") then
                gen = isopb
            end
            if not gen and square then
                for j=0,square:getSpecialObjects():size()-1 do
                    local obj = square:getSpecialObjects():get(j)
                    if instanceof(obj, "IsoGenerator") then
                        gen = obj
                        break
                    end
                end
            end
            if gen ~= nil then
                -- Remove from client engine processing to prevent sound/toxic re-triggering
                if gen:getCell() then
                    gen:getCell():addToProcessIsoObjectRemove(gen)
                end
                if gen.getEmitter and gen:getEmitter() ~= nil then
                    local emitter = gen:getEmitter()
                    emitter:setVolumeAll(0.0)
                    if emitter:isPlaying("GeneratorLoop") then
                        emitter:stopSoundByName("GeneratorLoop")
                    end
                    if emitter:isPlaying("OldGeneratorLoop") then
                        emitter:stopSoundByName("OldGeneratorLoop")
                    end
                elseif gen.stopSound then
                    gen:stopSound("GeneratorLoop")
                    gen:stopSound("OldGeneratorLoop")
                end
            end
        end
    end
end

function PBSystem.preventToxicBuildings()
    local self = PBSystem.instance
    if not self then return end
    for i = 1, self:getLuaObjectCount() do
        local pb = self:getLuaObjectByIndex(i)
        if pb and pb.on then
            local isopb = pb:getIsoObject()
            if isopb then
                local square = isopb:getSquare()
                if square then
                    local building = square:getBuilding()
                    if building and building:isToxic() then
                        building:setToxic(false)
                    end
                end
            end
        end
    end
end

CGlobalObjectSystem.RegisterSystemClass(PBSystem)

return PBSystem
