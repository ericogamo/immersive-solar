local ISA = require "ImmersiveSolarArrays/Utilities"
local RandomWorldSpawns = require "ImmersiveSolarArrays/World/RandomWorldSpawns"

if isClient() then

    ---update isoObjects when chunk loads
    local function LoadPowerbank(isoObject)
        if not isoObject then return end
        local container = isoObject:getContainer()
        if not container and isoObject.createContainersFromSpriteProperties then
            isoObject:createContainersFromSpriteProperties()
            container = isoObject:getContainer()
        end
        if container and container.setAcceptItemFunction then
            container:setAcceptItemFunction("AcceptItemFunction.ISA_Batteries")
        end
    end
    MapObjects.OnLoadWithSprite("solarmod_tileset_01_0", LoadPowerbank, 6)

else

    ---update isoObjects when chunk loads
    local function LoadPowerbank(isoObject)
        if not isoObject then return end
        ISA.PBSystem_Server:loadIsoObject(isoObject)
        local container = isoObject:getContainer()
        if not container and isoObject.createContainersFromSpriteProperties then
            isoObject:createContainersFromSpriteProperties()
            container = isoObject:getContainer()
        end
        if container and container.setAcceptItemFunction then
            container:setAcceptItemFunction("AcceptItemFunction.ISA_Batteries")
        end
    end
    MapObjects.OnLoadWithSprite("solarmod_tileset_01_0", LoadPowerbank, 6)

    ---update isoObjects when chunk loads first time
    local function OnNewWithSprite(isoObject)
        local isaType = ISA.WorldUtil.getType(isoObject)
        local square = isoObject:getSquare()
        if not square then error("ISA: OnNewWithSprite no square") return end

        if isaType == "PowerBank" then
            local index = isoObject:getObjectIndex()
            local spriteName = isoObject:getTextureName()
            square:transmitRemoveItemFromSquare(isoObject)
            RandomWorldSpawns.addToWorld(square, spriteName, index)
        else
            square:getSpecialObjects():add(isoObject)
        end
    end

    local MapObjects = MapObjects
    for sprite, type in pairs(ISA.WorldUtil.ISATypes) do
        MapObjects.OnNewWithSprite(sprite, OnNewWithSprite, 5)
    end

end
