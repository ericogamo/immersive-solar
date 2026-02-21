BuildRecipeCode = BuildRecipeCode or {}

local ISA = require "ImmersiveSolarArrays/Utilities"

-- Power Bank
BuildRecipeCode.ISA_PowerBank = {}
BuildRecipeCode.ISA_PowerBank.OnCreate = function(data)
    local thumpable = data.thumpable
    if not thumpable then return end

    local gen = ISA.WorldUtil.replaceIsoObjectWithGenerator(thumpable)
    if not gen then return end

    if ISA.PBSystem_Server then
        ISA.PBSystem_Server:loadIsoObject(gen)
    end

    return {
        replaceObject = true,
        object = gen
    }
end

BuildRecipeCode.ISA_PowerBank.OnIsValid = function(data)
    return true
end

-- Flat Panel
BuildRecipeCode.ISA_SolarPanelFlat = {}
BuildRecipeCode.ISA_SolarPanelFlat.OnCreate = function(data)
    local obj = data.thumpable
    if not obj then return true end

    local md = obj:getModData()
    md.pbLinked = nil
    md.connectDelta = nil
    obj:transmitModData()

    return true
end

BuildRecipeCode.ISA_SolarPanelFlat.OnIsValid = function(data)
    return true
end

-- Wall Panel
BuildRecipeCode.ISA_SolarPanelWall = {}
BuildRecipeCode.ISA_SolarPanelWall.OnCreate = function(data)
    local obj = data.thumpable
    if not obj then return true end

    local md = obj:getModData()
    md.pbLinked = nil
    md.connectDelta = nil
    obj:transmitModData()

    return true
end

BuildRecipeCode.ISA_SolarPanelWall.OnIsValid = function(data)
    return true
end

-- Mounted Panel
BuildRecipeCode.ISA_SolarPanelMounted = {}
BuildRecipeCode.ISA_SolarPanelMounted.OnCreate = function(data)
    local obj = data.thumpable
    if not obj then return true end

    local md = obj:getModData()
    md.pbLinked = nil
    md.connectDelta = nil
    obj:transmitModData()

    return true
end

BuildRecipeCode.ISA_SolarPanelMounted.OnIsValid = function(data)
    return true
end

-- Fail Safe
BuildRecipeCode.ISA_SolarFailsafe = {}
BuildRecipeCode.ISA_SolarFailsafe.OnCreate = function(data)
    local obj = data.thumpable
    if not obj then return true end

    local md = obj:getModData()
    md.pbLinked = nil
    md.connectDelta = nil
    obj:transmitModData()

    return true
end

BuildRecipeCode.ISA_SolarFailsafe.OnIsValid = function(data)
    return true
end