---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"

local WorldUtil = {}

---@alias ISAType
---| `PowerBank`
---| `Panel`
---| `FailSafe`

WorldUtil.ISATypes = {
    solarmod_tileset_01_0 = "PowerBank",
    solarmod_tileset_01_6 = "Panel",
    solarmod_tileset_01_7 = "Panel",
    solarmod_tileset_01_8 = "Panel",
    solarmod_tileset_01_9 = "Panel",
    solarmod_tileset_01_10 = "Panel",
    solarmod_tileset_01_15 = "Failsafe",
}

---return type of solar object
---@param isoObject IsoObject
---@return ISAType
function WorldUtil.getType(isoObject)
    if not isoObject then return nil end
    if instanceof(isoObject, "IsoGenerator") and isoObject:getModData().generatorFullType == "ISA.PowerBank_test" then
        return "PowerBank"
    end
    return WorldUtil.ISATypes[isoObject:getTextureName()]
end

---@param isoObject IsoObject
---@param modType ISAType
---@return boolean
function WorldUtil.objectIsType(isoObject, modType)
    if not isoObject then return false end
    if instanceof(isoObject, "IsoGenerator") and isoObject:getModData().generatorFullType == "ISA.PowerBank_test" then
        return modType == "PowerBank"
    end
    return WorldUtil.ISATypes[isoObject:getTextureName()] == modType
end

---@param level number Electical skill level
---@return table
function WorldUtil.getValidBackupArea(level)
    return { radius = level, levels = level > 5 and 1 or 0, distance = math.pow(level, 2) * 1.25 }
end

---@param square IsoGridSquare
---@param radius number
---@param zLevels number
---@param distance number
---@return table<any,PowerBankObject_Server>
function WorldUtil.getPowerBanksInArea(square, radius, zLevels, distance)
    local all = {}
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    for ix = x - radius, x + radius do
        for iy = y - radius, y + radius do
            for iz = z - zLevels, z + zLevels do
                local isquare = IsoUtils.DistanceToSquared(x,y,z,ix,iy,iz) <= distance and getSquare(ix, iy, iz)
                local pb
                if isquare then
                    if isClient() then
                        pb = ISA.PBSystem_Client:getLuaObjectOnSquare(isquare)
                    else
                        pb = ISA.PBSystem_Server:getLuaObjectOnSquare(isquare)
                    end
                end
                if pb ~= nil then
                    table.insert(all,pb)
                end
            end
        end
    end
    return all
end

function WorldUtil.findOnSquare(square,sprite)
    local special = square:getSpecialObjects()
    for i = 0, special:size()-1 do
        local obj = special:get(i)
        if obj:getTextureName() == sprite then
            return obj
        end
    end
end

---@param square IsoGridSquare
---@param type string
---@return IsoObject?
function WorldUtil.findTypeOnSquare(square, type)
    local special = square:getSpecialObjects()
    for i = 0, special:size() - 1 do
        local obj = special:get(i)
        if WorldUtil.ISATypes[obj:getTextureName()] == type then
            return obj
        end
    end
    return nil
end

---@param square IsoGridSquare
---@param spriteName string
---@param index number
---@param fullSpawn boolean
---@return IsoGenerator
function WorldUtil.placePowerBank(square, spriteName, index, fullSpawn)
    local sprite = getSprite(spriteName)
    local fullType = sprite:getProperties():Is("CustomItem") and sprite:getProperties():Val("CustomItem")
                     or ("Moveables." .. spriteName)

    local generator = IsoGenerator.new(square:getCell())
    generator:setSprite(sprite)
    generator:setSquare(square)

    --set sprite, condition, fuel, fulltype from item
    generator:getModData().generatorFullType = fullType

    if fullSpawn then
        square:AddSpecialObject(generator, index)
        generator:createContainersFromSpriteProperties()
        generator:getContainer():setExplored(true)
        generator:transmitCompleteItemToClients()
        ---these auto transmit, do after sending object
        generator:setCondition(100)
        generator:setFuel(100)
        generator:setConnected(true)
        triggerEvent("OnObjectAdded", generator)
    end

    return generator
end

---@param isoObject IsoObject
---@return IsoGenerator
function WorldUtil.replaceIsoObjectWithGenerator(isoObject)
    if not isoObject then return nil end

    local square = isoObject:getSquare()
    if not square then return nil end

    if instanceof(isoObject, "IsoGenerator") then
        return isoObject
    end

    local item = instanceItem("ISA.PowerBank_test")
    if not item then
        print("[ISA] Failed to instance ISA.PowerBank_test, trying Base.Generator")
        item = instanceItem("Base.Generator")
    end

    local gen = IsoGenerator.new(item, square:getCell(), square)

    -- Preserve visuals
    if isoObject:getSprite() then
        gen:setSprite(isoObject:getSprite())
    else
        gen:setSpriteByName("solarmod_tileset_01_0")
    end
    gen:setSquare(square)

    -- Identify as PowerBank
    gen:getModData().generatorFullType = "ISA.PowerBank_test"

    -- DO NOT add to square
    -- DO NOT remove isoObject
    -- DO NOT transmit
    -- DO NOT fire OnObjectAdded

    return gen
end

---Find all real generators (not PowerBanks) in an area around a square
---@param square IsoGridSquare
---@param radius number
---@param zLevels number
---@param distance number
---@return table<number, IsoGenerator>
function WorldUtil.getGeneratorsInArea(square, radius, zLevels, distance)
    local all = {}
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    for ix = x - radius, x + radius do
        for iy = y - radius, y + radius do
            for iz = z - zLevels, z + zLevels do
                if ix >= 0 and iy >= 0 and iz >= 0 then
                    local dist = IsoUtils.DistanceToSquared(x, y, z, ix, iy, iz)
                    if dist <= distance then
                        local isquare = getSquare(ix, iy, iz)
                        if isquare then
                            local generator = isquare:getGenerator()
                            if generator and generator:isConnected() and WorldUtil.ISATypes[generator:getTextureName()] ~= "PowerBank" then
                                table.insert(all, generator)
                            end
                        end
                    end
                end
            end
        end
    end
    return all
end

ISA.WorldUtil = WorldUtil
