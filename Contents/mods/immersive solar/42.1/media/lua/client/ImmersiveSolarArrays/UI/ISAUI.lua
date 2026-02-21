local string, math, getText = string, math, getText

---@class ImmersiveSolarArrays
local ISA = require "ImmersiveSolarArrays/Utilities"

local UI = {}

local rgbDefault, rgbGood, rgbBad = { r = 1, g = 1, b = 1, rich = " <RGB:1,1,1> " }, {}, {}
UI.rgbDefault, UI.rgbGood, UI.rgbBad = rgbDefault, rgbGood, rgbBad

function UI.updateColours()
    local core = getCore()
    local good = core:getGoodHighlitedColor()
    rgbGood.ColorInfo = good
    rgbGood.r, rgbGood.g, rgbGood.b = good:getR(), good:getG(), good:getB()
    rgbGood.rich = string.format(" <RGB:%.2f,%.2f,%.2f> ", rgbGood.r, rgbGood.g, rgbGood.b)
    local bad = core:getBadHighlitedColor()
    rgbBad.ColorInfo = bad
    rgbBad.r, rgbBad.g, rgbBad.b = bad:getR(), bad:getG(), bad:getB()
    rgbBad.rich = string.format(" <RGB:%.2f,%.2f,%.2f> ", rgbBad.r, rgbBad.g, rgbBad.b)
end

function UI.onConnectPanel(player,panel,luaPb)
    local character = getSpecificPlayer(player)
    if luautils.walkAdj(character, panel:getSquare(), true) then
        local panelX, panelY, panelZ = panel:getX(), panel:getY(), panel:getZ()
        local pbX, pbY, pbZ = luaPb.x, luaPb.y, luaPb.z
        local action = ISA_ConnectPanel:new(character, panel, luaPb, panelX, panelY, panelZ, pbX, pbY, pbZ)
        action.character = character
        action.panel = panel
        action.luaPb = luaPb
        action.x = panelX
        action.y = panelY
        action.z = panelZ
        action.pbX = pbX
        action.pbY = pbY
        action.pbZ = pbZ
        ISTimedActionQueue.add(action)
    end
end

function UI.onConnectBackup(player, generator, luaPb)
    local character = getSpecificPlayer(player)
    if luautils.walkAdj(character, generator:getSquare(), true) then
        local action = ISA_ConnectBackup:new(character, generator, luaPb)
        action.character = character
        action.generator = generator
        action.powerbank = luaPb
        ISTimedActionQueue.add(action)
    end
end

function UI.onDisconnectBackup(player, generator, luaPb)
    local character = getSpecificPlayer(player)
    if luautils.walkAdj(character, generator:getSquare(), true) then
        if isClient() then
            sendClientCommand(character, "ISA", "PlugBackupGenerator", {
                genX = generator:getX(),
                genY = generator:getY(),
                genZ = generator:getZ(),
                pbX = luaPb.x,
                pbY = luaPb.y,
                pbZ = luaPb.z,
                plug = false
            })
        else
            local pb = ISA.PBSystem_Server:getLuaObjectAt(luaPb.x, luaPb.y, luaPb.z)
            if pb then
                pb:disconnectBackupGenerator(generator)
                pb:saveData(true)
            end
        end
    end
end

local function ActivatePowerbank(player, powerbank, activate)
    local character = getSpecificPlayer(player)
    if luautils.walkAdj(character, powerbank:getSquare(), true) then
        local pbX, pbY, pbZ = powerbank:getX(), powerbank:getY(), powerbank:getZ()
        local action = ISA_ActivatePowerBank:new(character, powerbank, activate, pbX, pbY, pbZ)
        action.character = character
        action.activate = activate
        action.isoPb = powerbank
        action.x = pbX
        action.y = pbY
        action.z = pbZ
        ISTimedActionQueue.add(action)
    end
end

local function onConnectPanelCursor(player, square, powerbank)
    return ISA.ConnectPanelCursor:new(player, square, powerbank)
end

local _powerbank

function UI.OnPreFillWorldObjectContextMenu(player, context, worldobjects, test)
    local generator = ISWorldObjectContextMenu.fetchVars.generator

    if generator ~= nil and ISA.WorldUtil.objectIsType(generator, "PowerBank") then
        _powerbank = generator
        ISWorldObjectContextMenu.fetchVars.generator = nil
    end
end

function UI.OnFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end
    local powerbank = _powerbank
    local panel
    --local panels = {}

    for _, obj in ipairs(worldobjects) do
        local sprite = obj:getTextureName()
        local type = ISA.WorldUtil.ISATypes[sprite]
        if type == "PowerBank" then
            powerbank = obj
        elseif type == "Panel" then
            panel = obj
            --table.insert(panels,obj)
        end
    end

    if powerbank then
        _powerbank = nil
        local square = powerbank:getSquare()

        if test then return ISWorldObjectContextMenu.setTest() end
        local ISASubMenu = context:getNew(context)
        context:addSubMenu(context:addOption(getText("ContextMenu_ISA_BatteryBank")), ISASubMenu)
        if test then return ISWorldObjectContextMenu.setTest() end
        ISASubMenu:addOption(getText("ContextMenu_ISA_BatteryBankStatus"), player, ISA.StatusWindow.OnOpenPanel, square)
        local isOn = powerbank:getModData()["on"]
        local textOn = isOn and getText("ContextMenu_Turn_Off") or getText("ContextMenu_Turn_On")
        if test then return ISWorldObjectContextMenu.setTest() end
        ISASubMenu:addOption(textOn, player, ActivatePowerbank, powerbank, not isOn)
        if test then return ISWorldObjectContextMenu.setTest() end
        ISASubMenu:addOption(getText("ContextMenu_ISA_ConnectPanels"), player, onConnectPanelCursor, square, powerbank)

        local character = getSpecificPlayer(player)
        local elecLevel = character:getPerkLevel(Perks.Electricity)
        local area = ISA.WorldUtil.getValidBackupArea(elecLevel)
        local generators = ISA.WorldUtil.getGeneratorsInArea(square, area.radius, area.levels, area.distance)

        if #generators > 0 then
            for _, generator in ipairs(generators) do
                local isConnected = pb and pb.conGenerator and
                                   pb.conGenerator.x == generator:getX() and
                                   pb.conGenerator.y == generator:getY() and
                                   pb.conGenerator.z == generator:getZ()
                
                local text = isConnected and (getText("ContextMenu_ISA_Disconnect_Backup") or "Disconnect Backup") or 
                                            (getText("ContextMenu_ISA_Connect_Backup") or "Connect Backup")
                
                local func = isConnected and UI.onDisconnectBackup or UI.onConnectBackup
                ISASubMenu:addOption(text, player, func, generator, powerbank:getModData())
            end
        end
    end

    --for _,panel in ipairs(panels) do
        if panel then
            if test then return ISWorldObjectContextMenu.setTest() end
            local panelOption = context:addOption(getText("ContextMenu_ISA_SolarPanel"))
            local options = ISA.PBSystem_Client.canConnectPanelTo(panel)
            if #options > 0 then
                local ISASubMenu = context:getNew(context)
                context:addSubMenu(panelOption, ISASubMenu)
                for i,opt in ipairs(options) do
                    if test then return ISWorldObjectContextMenu.setTest() end
                    local option = ISASubMenu:addOption(getText("ContextMenu_ISA_Connect_Panel"), player, UI.onConnectPanel, panel, opt[1])
                    local tooltip = ISWorldObjectContextMenu.addToolTip()
                    tooltip:setName(getText("ContextMenu_ISA_BatteryBank"))
                    tooltip.description = opt[4] and rgbGood.rich .. getText("ContextMenu_ISA_Connect_Panel_toolTip_isConnected") or rgbBad.rich .. getText("ContextMenu_ISA_Connect_Panel_toolTip_isConnected_false")
                    tooltip.description = tooltip.description .. (rgbDefault.rich .. "<BR>" .. "( "..opt[2].." : "..opt[3].." )" .. getText("ContextMenu_ISA_Connect_Panel_toolTip"))
                    option.toolTip = tooltip
                end
            else
                if test then return ISWorldObjectContextMenu.setTest() end
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                if options.inside then
                    tooltip.description = rgbBad.rich .. getText("ContextMenu_ISA_Connect_Panel_toolTip_isOutside")
                else
                    tooltip.description = rgbBad.rich .. getText("ContextMenu_ISA_Connect_Panel_NoPowerbank")
                end
                panelOption.toolTip = tooltip
                panelOption.notAvailable = true
                panelOption.onSelect = nil
            end
        end
    --end
    
    local generator = ISWorldObjectContextMenu.fetchVars.generator
    if generator and generator:isConnected() and ISA.WorldUtil.getType(generator) ~= "PowerBank" then
        if test then return ISWorldObjectContextMenu.setTest() end
        
        local character = getSpecificPlayer(player)
        local elecLevel = character:getPerkLevel(Perks.Electricity)
        local area = ISA.WorldUtil.getValidBackupArea(elecLevel)
        local luaPowerbanks = ISA.WorldUtil.getPowerBanksInArea(generator:getSquare(), area.radius, area.levels, area.distance)
        
        if #luaPowerbanks > 0 then
            local genOption = context:addOption(getText("ContextMenu_ISA_Backup_Generator") or "Backup Generator")
            local ISASubMenu = context:getNew(context)
            context:addSubMenu(genOption, ISASubMenu)
            
            for i, pb in ipairs(luaPowerbanks) do
                local isConnected = pb.conGenerator and 
                                   pb.conGenerator.x == generator:getX() and 
                                   pb.conGenerator.y == generator:getY() and 
                                   pb.conGenerator.z == generator:getZ()
                
                local text = isConnected and (getText("ContextMenu_ISA_Disconnect_Backup") or "Disconnect Backup") or 
                                            (getText("ContextMenu_ISA_Connect_Backup") or "Connect Backup")
                
                local func = isConnected and UI.onDisconnectBackup or UI.onConnectBackup
                
                local opt = ISASubMenu:addOption(text, player, func, generator, pb)
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip:setName(getText("ContextMenu_ISA_BatteryBank"))
                
                local distanceStr = string.format("( %d : %d )", pb.x - generator:getX(), pb.y - generator:getY())
                if isConnected then
                    tooltip.description = rgbGood.rich .. (getText("ContextMenu_ISA_Connect_Panel_toolTip_isConnected") or "Connected")
                else
                    tooltip.description = rgbBad.rich .. (getText("ContextMenu_ISA_Connect_Panel_toolTip_isConnected_false") or "Not Connected")
                end
                tooltip.description = tooltip.description .. rgbDefault.rich .. "<BR>" .. distanceStr
                opt.toolTip = tooltip
            end
        end
    end
end

function UI.ISInventoryPane_drawItemDetails_patch(drawItemDetails)
    local NewColorInfo = ColorInfo:new()

    return function(self,item, y, xoff, yoff, red,...)
        if not item then return end
        if not (item:getModData().ISA_maxCapacity) then
            return drawItemDetails(self,item, y, xoff, yoff, red,...)
        else
            local hdrHgt = self.headerHgt
            local top = hdrHgt + y * self.itemHgt + yoff
            rgbBad.ColorInfo:interp(rgbGood.ColorInfo, item:getCondition()/100, NewColorInfo)
            local fgBar = {r=NewColorInfo:getR(),g=NewColorInfo:getG(),b=NewColorInfo:getB(),a=1}
            local fgText = red and {r=0.0, g=0.0, b=0.5, a=0.7} or {r=0.6, g=0.8, b=0.5, a=0.6}
            self:drawTextAndProgressBar(getText("Tooltip_weapon_Condition") .. ":", item:getCondition()/100, xoff, top, fgText, fgBar)
        end
    end
end

function UI.DoTooltip_patch(DoTooltip)
    return function(item,tooltip)
        local maxCapacity = item:getModData().ISA_maxCapacity
        if not maxCapacity then
            return DoTooltip(item,tooltip)
        else
            local lineHeight = tooltip:getLineSpacing()
            local font = tooltip:getFont()
            local y = 5
            --tooltip:render()
            tooltip:DrawText(font, item:getName(), 5, 5, 1, 1, 0.8, 1)
            y = y + lineHeight + 5
            --adjustWidth(5, name;
            local layout = tooltip:beginLayout()
            --setminwidth
            local option
            if tooltip:getWeightOfStack() > 0 then
                option = layout:addItem()
                option:setLabel(getText("Tooltip_item_StackWeight")..":",1,1,0.8,1)
                option:setValueRightNoPlus(tooltip:getWeightOfStack())
            else
                option = layout:addItem()
                option:setLabel(getText("Tooltip_item_Weight")..":",1,1,0.8,1)
                option:setValue(string.format("%.2f",item:isEquipped() and item:getEquippedWeight() or item:getUnequippedWeight()),1,1,0.8,1)
                option = layout:addItem()
                option:setLabel(getText("IGUI_invpanel_Remaining")..":",1,1,0.8,1)
                option:setValue(string.format("%d%%",item:getCurrentUsesFloat()*100),1,1,0.8,1)
                option = layout:addItem()
                option:setLabel(getText("Tooltip_weapon_Condition")..":",1,1,0.8,1)
                option:setValue(string.format("%d%%",item:getCondition()),1,1,0.8,1)
                option = layout:addItem()
                option:setLabel(getText("Tooltip_container_Capacity")..":",1,1,0.8,1)
                option:setValue(string.format("%d / %d",maxCapacity * (1 - math.pow((1 - (item:getCondition()/100)),6)),maxCapacity),1,1,0.8,1)
            end
            y = layout:render(5,y,tooltip)
            tooltip:endLayout(layout)
            --if width < 150 -- tooltip:setWidth(tooltip:getWidth())
            tooltip:setHeight(y+5)
        end
    end
end

UI.updateColours()

Events.OnPreFillWorldObjectContextMenu.Add(UI.OnPreFillWorldObjectContextMenu)
Events.OnFillWorldObjectContextMenu.Add(UI.OnFillWorldObjectContextMenu)

ISA.UI = UI
