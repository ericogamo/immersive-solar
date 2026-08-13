require "ISUI/ISPanelJoypad"
local isa = require "ImmersiveSolarArrays/Utilities"

local ISAWindowsSumaryTab = ISPanelJoypad:derive("ISAWindowsSumaryTab")

function ISAWindowsSumaryTab:initialise()
	ISPanelJoypad.initialise(self)
end

function ISAWindowsSumaryTab:createChildren()
	self:setScrollChildren(true)
	self:addScrollBars()
end

function ISAWindowsSumaryTab:setVisible(visible)
	self.javaObject:setVisible(visible)
	if visible then
		self:setWidthAndParentWidth(580)
		self:setHeightAndParentHeight(445)
		self.currentFrame = 0
	end
end

function ISAWindowsSumaryTab:drawCardBox(x, y, w, h, title, icon)
	-- Background box (sleek dark card)
	self:drawRect(x, y, w, h, 0.75, 0.08, 0.09, 0.11)
	-- Border
	self:drawRectBorder(x, y, w, h, 1, 0.22, 0.25, 0.30)
	-- Header divider line
	self:drawRect(x, y + 28, w, 1, 1, 0.16, 0.18, 0.22)
	-- Icon
	if icon then
		self:drawTextureScaled(icon, x + 10, y + 5, 18, 18, 1, 1, 1, 1)
	end
	-- Title
	self:drawText(title, x + (icon and 34 or 12), y + 6, 0.95, 0.97, 1.0, 1, UIFont.Medium)
end

function ISAWindowsSumaryTab:drawStatusBadge(rightX, y, badgeText, r, g, b)
	if not badgeText then return end
	local bw = getTextManager():MeasureStringX(UIFont.Small, badgeText) + 14
	local bx = rightX - bw
	self:drawRect(bx, y, bw, 18, 0.85, r * 0.25, g * 0.25, b * 0.25)
	self:drawRectBorder(bx, y, bw, 18, 1, r, g, b)
	self:drawTextCentre(badgeText, bx + bw / 2, y + 2, r, g, b, 1, UIFont.Small)
end

function ISAWindowsSumaryTab:render()
	local pb = self.parent.parent.luaPB
	if not (pb and pb:getIsoObject()) then return self.parent.parent:close() end

	-- Update cached values every ~1 sec
	if self.currentFrame == 0 then
		pb:updateFromIsoObject()
		self.maxCapacity = pb.maxcapacity or 0
		self.charge = pb.charge or 0
		self.drain = pb.drain or 0
		self.batteryLevel = self.maxCapacity > 0 and (self.charge / self.maxCapacity) or 0
		self.panelsMaxInput = pb.luaSystem:getMaxSolarOutput(pb.npanels) or 0
		self.panelsInput = pb.luaSystem:getModifiedSolarOutput(pb.npanels) or 0
		self.difference = self.panelsInput - (pb:shouldDrain() and pb.drain or 0)
		self.night = not isa.isDayTime()

		self.currentFrame = self.fps - 1
	else
		self.currentFrame = self.currentFrame - 1
	end

	local w = self.width
	local cardW = w - 24

	-- ========================================================
	-- CARD 1: BATTERY STORAGE & GRID STATUS
	-- ========================================================
	local c1X, c1Y, c1H = 12, 12, 138
	self:drawCardBox(c1X, c1Y, cardW, c1H,
		getText("IGUI_ISAWindowsSumaryTab_BatteryStatus"),
		self.textureBattery)

	-- Status Badge (Top Right of Card 1)
	local badgeText = getText("IGUI_ISASummary_Stable")
	local bR, bG, bB = 0.5, 0.5, 0.5
	if self.maxCapacity <= 0 then
		badgeText = getText("IGUI_ISAWindowsSumaryTab_NoBatteries")
		bR, bG, bB = 0.9, 0.25, 0.25
	elseif self.difference > 0 then
		if self.maxCapacity == self.charge then
			badgeText = getText("IGUI_ISAWindowsSumaryTab_FullyCharged")
			bR, bG, bB = 0.15, 0.75, 0.35
		else
			badgeText = string.format(getText("IGUI_ISASummary_ChargingFmt"), math.floor(self.difference))
			bR, bG, bB = 0.15, 0.85, 0.35
		end
	elseif self.difference < 0 then
		if self.charge == 0 then
			badgeText = getText("IGUI_ISAWindowsSumaryTab_FullyDischarged")
			bR, bG, bB = 0.95, 0.25, 0.25
		else
			badgeText = string.format(getText("IGUI_ISASummary_DischargingFmt"), math.floor(math.abs(self.difference)))
			bR, bG, bB = 0.95, 0.65, 0.15
		end
	else
		badgeText = getText("IGUI_ISAWindowsSumaryTab_NotCharging")
		bR, bG, bB = 0.6, 0.6, 0.6
	end
	self:drawStatusBadge(c1X + cardW - 10, c1Y + 5, badgeText, bR, bG, bB)

	-- Progress Bar (x, y, w, h)
	local barX, barY, barW, barH = c1X + 14, c1Y + 36, cardW - 28, 22
	self:drawRect(barX, barY, barW, barH, 1, 0.05, 0.06, 0.08)
	local fillW = math.max(2, math.min(barW, barW * self.batteryLevel))
	local barR, barG, barB = 0.13, 0.77, 0.36
	if self.batteryLevel <= 0.25 then
		barR, barG, barB = 0.93, 0.26, 0.26
	elseif self.batteryLevel <= 0.60 then
		barR, barG, barB = 0.92, 0.70, 0.05
	end
	if self.maxCapacity > 0 then
		self:drawRect(barX, barY, fillW, barH, 0.9, barR, barG, barB)
	end
	self:drawRectBorder(barX, barY, barW, barH, 1, 0.30, 0.35, 0.42)
	local pctStr = string.format("%d %%   (%d / %d Ah)", math.floor(self.batteryLevel * 100), math.floor(self.charge), math.floor(self.maxCapacity))
	self:drawTextCentre(pctStr, barX + barW / 2, barY + 3, 1, 1, 1, 1, UIFont.Small)

	-- 2-Column Stats for Card 1
	local leftColX = c1X + 16
	local rightColX = c1X + math.floor(cardW / 2) + 10
	local statY1 = c1Y + 68
	local statY2 = c1Y + 95

	self:drawText(string.format(getText("IGUI_ISASummary_TotalCapacityFmt"), math.floor(self.maxCapacity), pb.batteries), leftColX, statY1, 0.8, 0.85, 0.9, 1, UIFont.Small)
	self:drawText(string.format(getText("IGUI_ISASummary_CurrentStoredFmt"), math.floor(self.charge)), rightColX, statY1, 0.8, 0.85, 0.9, 1, UIFont.Small)

	local netText = getText("IGUI_ISASummary_NetBalanced")
	local netR, netG, netB = 0.7, 0.7, 0.7
	if self.difference > 0 then
		netText = string.format(getText("IGUI_ISASummary_NetChargingFmt"), math.floor(self.difference))
		netR, netG, netB = 0.2, 0.85, 0.35
	elseif self.difference < 0 then
		netText = string.format(getText("IGUI_ISASummary_NetDischargingFmt"), math.floor(math.abs(self.difference)))
		netR, netG, netB = 0.95, 0.65, 0.15
	end
	self:drawText(getText("IGUI_ISASummary_NetPowerBalance") .. "  " .. netText, leftColX, statY2, netR, netG, netB, 1, UIFont.Small)

	-- Time estimation
	local timeEstStr = getText("IGUI_ISASummary_BatteryFull")
	local timeR, timeG, timeB = 0.2, 0.85, 0.35
	if self.maxCapacity <= 0 then
		timeEstStr = getText("IGUI_ISASummary_NoBankActive")
		timeR, timeG, timeB = 0.6, 0.6, 0.6
	elseif self.difference > 0 and self.charge < self.maxCapacity then
		local ctime = (self.maxCapacity - self.charge) / self.difference
		local h = math.floor(ctime)
		local m = math.floor((ctime - h) * 60)
		timeEstStr = string.format(getText("IGUI_ISASummary_TimeToFullFmt"), h, m)
	elseif self.difference < 0 and self.charge > 0 then
		local dtime = math.abs(self.charge / self.difference)
		local h = math.floor(dtime)
		local m = math.floor((dtime - h) * 60)
		timeEstStr = string.format(getText("IGUI_ISASummary_TimeToEmptyFmt"), h, m)
		timeR, timeG, timeB = 0.95, 0.35, 0.35
	elseif self.charge == 0 then
		timeEstStr = getText("IGUI_ISASummary_CompletelyDischarged")
		timeR, timeG, timeB = 0.95, 0.25, 0.25
	end
	self:drawText(getText("IGUI_ISASummary_TimeEstimate") .. "  " .. timeEstStr, rightColX, statY2, timeR, timeG, timeB, 1, UIFont.Small)

	-- ========================================================
	-- CARD 2: SOLAR GENERATION & WEATHER
	-- ========================================================
	local c2X, c2Y, c2H = 12, 160, 126
	self:drawCardBox(c2X, c2Y, cardW, c2H,
		getText("IGUI_ISAWindowsSumaryTab_PanelsStatus"),
		self.textureSolarPanel)

	-- Efficiency Badge on right
	local effPct = self.panelsMaxInput > 0 and math.floor((self.panelsInput / self.panelsMaxInput) * 100) or 0
	self:drawStatusBadge(c2X + cardW - 10, c2Y + 5, string.format(getText("IGUI_ISASummary_EfficiencyFmt"), effPct), 0.15, 0.75, 0.85)

	local c2Y1 = c2Y + 38
	local c2Y2 = c2Y + 63
	local c2Y3 = c2Y + 88

	self:drawText(string.format(getText("IGUI_ISASummary_CurrentSolarFmt"), math.floor(self.panelsInput)), leftColX, c2Y1, 0.2, 0.85, 0.35, 1, UIFont.Small)
	self:drawText(string.format(getText("IGUI_ISASummary_ConnectedPanelsFmt"), pb.npanels), rightColX, c2Y1, 0.8, 0.85, 0.9, 1, UIFont.Small)

	self:drawText(string.format(getText("IGUI_ISASummary_MaxSolarFmt"), math.floor(self.panelsMaxInput)), leftColX, c2Y2, 0.8, 0.85, 0.9, 1, UIFont.Small)
	self:drawText(string.format(getText("IGUI_ISASummary_BaseDrainFmt"), math.floor(pb.drain)), rightColX, c2Y2, 0.95, 0.45, 0.35, 1, UIFont.Small)

	-- Weather & Sun / Moon icon
	local sunIcon = self.night and self.textureMoon or self.textureSun
	if sunIcon then
		self:drawTextureScaled(sunIcon, leftColX, c2Y3 - 2, 18, 18, 1, 1, 1, 1)
	end
	local weatherText = self.night and getText("IGUI_ISASummary_NightNoSun") or (effPct > 70 and string.format(getText("IGUI_ISASummary_ClearSkyFmt"), effPct) or (effPct > 30 and string.format(getText("IGUI_ISASummary_CloudyFmt"), effPct) or getText("IGUI_ISASummary_HeavyClouds")))
	self:drawText(getText("IGUI_ISASummary_Environment") .. "  " .. weatherText, leftColX + 24, c2Y3, 0.85, 0.9, 0.95, 1, UIFont.Small)

	local statusText = getText("IGUI_ISASummary_WorkingOK")
	local stR, stG, stB = 0.2, 0.85, 0.35
	if pb.npanels <= 0 then
		statusText = getText("IGUI_ISASummary_NoPanelsConnected")
		stR, stG, stB = 0.9, 0.25, 0.25
	elseif self.drain > self.panelsMaxInput then
		statusText = getText("IGUI_ISASummary_NotEnoughPanels")
		stR, stG, stB = 0.95, 0.65, 0.15
	elseif self.drain > self.panelsInput then
		statusText = getText("IGUI_ISASummary_NotEnoughSunlight")
		stR, stG, stB = 0.95, 0.65, 0.15
	end
	self:drawText(getText("IGUI_ISASummary_ModuleStatus") .. "  " .. statusText, rightColX, c2Y3, stR, stG, stB, 1, UIFont.Small)

	-- ========================================================
	-- CARD 3: EMERGENCY POWER & SOLAR FAILSAFE
	-- ========================================================
	local c3X, c3Y, c3H = 12, 296, 110
	self:drawCardBox(c3X, c3Y, cardW, c3H,
		getText("IGUI_ISASummary_EmergencyTitle"),
		self.textureCables)

	self:drawStatusBadge(c3X + cardW - 10, c3Y + 5, getText("IGUI_ISASummary_AutoProtection"), 0.90, 0.65, 0.15)

	local hasFailsafe = false
	if pb.conGenerator then
		local genSq = getSquare(pb.conGenerator.x, pb.conGenerator.y, pb.conGenerator.z)
		if genSq and isa.WorldUtil.findOnSquare(genSq, "solarmod_tileset_01_15") then
			hasFailsafe = true
		end
	end

	local c3Y1 = c3Y + 38
	local c3Y2 = c3Y + 68

	local genText = pb.conGenerator and getText("IGUI_ISASummary_GenConnectedReady") or getText("IGUI_ISASummary_GenNoneConnected")
	local genR, genG, genB = pb.conGenerator and 0.2 or 0.6, pb.conGenerator and 0.85 or 0.6, pb.conGenerator and 0.35 or 0.6
	self:drawText(getText("IGUI_ISASummary_BackupGenerator") .. "  " .. genText, leftColX, c3Y1, genR, genG, genB, 1, UIFont.Small)

	local failsafeText = hasFailsafe and getText("IGUI_ISASummary_FailsafeActive") or (pb.conGenerator and getText("IGUI_ISASummary_FailsafeInactiveNoFS") or getText("IGUI_ISASummary_FailsafeInactive"))
	local fsR, fsG, fsB = hasFailsafe and 0.2 or 0.6, hasFailsafe and 0.85 or 0.6, hasFailsafe and 0.35 or 0.6
	self:drawText(getText("IGUI_ISASummary_FailsafeState") .. "  " .. failsafeText, rightColX, c3Y1, fsR, fsG, fsB, 1, UIFont.Small)

	local locText = pb.conGenerator and string.format("(%d, %d, %d)", pb.conGenerator.x, pb.conGenerator.y, pb.conGenerator.z) or "—"
	self:drawText(getText("IGUI_ISASummary_LocationCoords") .. "  " .. locText, leftColX, c3Y2, 0.8, 0.85, 0.9, 1, UIFont.Small)
	self:drawText(getText("IGUI_ISASummary_EmergencyAuto") .. "  " .. (pb.conGenerator and getText("IGUI_ISASummary_ReadyOnEmpty") or "—"), rightColX, c3Y2, 0.8, 0.85, 0.9, 1, UIFont.Small)
end

function ISAWindowsSumaryTab:new(x, y, width, height)
	local o = ISPanelJoypad.new(self, x, y, width, height)
	o:noBackground()

	-- Textures
	o.textureBattery = getTexture("media/ui/isa_battery.png")
	o.textureCables = getTexture("media/ui/isa_cables.png")
	o.textureHouse = getTexture("media/ui/isa_house.png")
	o.textureSolarPanel = getTexture("media/ui/isa_solar_panel.png")
	o.textureSolarPanelNoEnergy = getTexture("media/ui/isa_solar_panel_no_energy.png")
	o.textureCross = getTexture("media/ui/isa_cross.png")
	o.textureSolarRadiation = getTexture("media/ui/isa_solar_radiation.png")
	o.textureSun = getTexture("media/ui/isa_sun.png")
	o.textureMoon = getTexture("media/ui/isa_moon.png")

	o.currentFrame = 0
	o.maxCapacity = 0
	o.charge = 0
	o.drain = 0
	o.batteryLevel = 0
	o.panelsMaxInput = 0
	o.panelsInput = 0
	o.difference = 0
	o.night = false

	o.fps = getCore():getOptionUIRenderFPS()
	return o
end

function ISAWindowsSumaryTab.measureTexts()
	local max = { left = 150, right = 150 }
	return max
end

isa.StatusWindowSummaryView = ISAWindowsSumaryTab