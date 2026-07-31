---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"

ISA.Patches = {}


ISA.Patches["ISActivateGenerator.complete"] = function ()
    local original = ISActivateGenerator.complete
    ISActivateGenerator.complete = function (self)
        local result = original(self)

        --check action was successful
        if result and self.activate == self.generator:isActivated() then 
            ISA.PBSystem_Server:onActivateGenerator(self.character, self.generator, self.activate)
        end

        return result
    end
end


ISA.queueFunction("OnTick", function (tick)
    for _, patch in pairs(ISA.Patches) do
        patch()
    end
    ISA.Patches = nil
end)