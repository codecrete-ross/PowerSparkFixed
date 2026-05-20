PowerSparkDB = PowerSparkDB or {
	enabled = true,
	DruidBarFrame = true,
	SUF = true,
	ElvUI = true,
	Statusbars2 = true,
	maxManaHide = true,
	maxEnergyHide = true,
}
local playerClass = select(2, UnitClass('player'))
if playerClass == 'WARRIOR' then return end -- 战士不需要
local frame = CreateFrame('Frame')
local POWER_MANA = 0
local POWER_ENERGY = 3
local POWER_TOKENS = {
	[POWER_MANA] = 'MANA',
	[POWER_ENERGY] = 'ENERGY',
}
local ENERGY_TICK_INTERVAL = 2
local ENERGY_POLL_INTERVAL = .01
local SKIP_WINDOW = .75
local TICK_TOLERANCE = .25
frame.resTime = {}
frame.skip = {}
frame.energy = {}

local function clock()
	return GetTimePreciseSec and GetTimePreciseSec() or GetTime()
end

local function isPowerEvent(powerToken, powerType)
	return not powerToken or powerToken == POWER_TOKENS[powerType] or powerToken == powerType
end

local function consumeSkip(self, powerType, now)
	local skipTime = self.skip[powerType]
	if type(skipTime) ~= 'number' then return end
	self.skip[powerType] = nil
	return now <= skipTime
end

local function getEnergyInterval(self)
	return self.interval or ENERGY_TICK_INTERVAL
end

local function isNaturalEnergyGain(delta, previous, current, maxEnergy)
	if delta >= 18 and delta <= 22 then return true end
	if playerClass == 'ROGUE' and delta >= 38 and delta <= 42 then return true end
	return current == maxEnergy and previous < maxEnergy and maxEnergy - previous <= (playerClass == 'ROGUE' and 42 or 20)
end

function frame:baselineEnergy()
	if not PowerSparkDB.enabled then return end
	if playerClass ~= 'DRUID' and playerClass ~= 'ROGUE' then return end
	self.energy.displayPower = UnitPowerType('player')
	self.energy.lastValue = UnitPower('player', POWER_ENERGY)
	self.energy.lastMax = UnitPowerMax('player', POWER_ENERGY)
end

function frame:observeEnergy(now, baselineOnly)
	if not PowerSparkDB.enabled then return end
	if playerClass ~= 'DRUID' and playerClass ~= 'ROGUE' then return end
	local displayPower = UnitPowerType('player')
	if self.energy.displayPower and self.energy.displayPower ~= displayPower then
		self:baselineEnergy()
		return
	end
	if baselineOnly or type(self.energy.lastValue) ~= 'number' then
		self:baselineEnergy()
		return
	end

	local energy = UnitPower('player', POWER_ENERGY)
	local maxEnergy = UnitPowerMax('player', POWER_ENERGY)
	local previous = self.energy.lastValue

	if energy > previous then
		local skipped = consumeSkip(self, POWER_ENERGY, now)
		local delta = energy - previous
		local elapsed = type(self.energy.lastTickTime) == 'number' and now - self.energy.lastTickTime
		local ready = not self.energy.synced or type(elapsed) ~= 'number' or elapsed >= getEnergyInterval(self) - TICK_TOLERANCE

		if not skipped and ready and isNaturalEnergyGain(delta, previous, energy, maxEnergy) then
			self.energy.synced = true
			self.energy.lastTickTime = now
			self.resTime[POWER_ENERGY] = now
		end
	end

	self.energy.lastValue = energy
	self.energy.lastMax = maxEnergy
end

-- 初始化
function frame:init(bar, powerType)
	if not bar then return end
	if not bar.spark then
		bar.spark = bar:CreateTexture()
		bar.spark:SetTexture('Interface\\CastingBar\\UI-CastingBar-Spark')
		bar.spark:SetBlendMode('ADD')
		bar.spark:SetSize(28, 28)
		bar.spark:SetAlpha(.8)
	end
	if powerType then bar.powerType = powerType end
	if bar.PowerSparkHooked then return end
	bar.PowerSparkHooked = true

	bar:HookScript('OnUpdate', function(self)
		local now = clock()
		local powerType = self.powerType or UnitPowerType('player')
		local resTime = powerType == POWER_ENERGY and frame.energy.lastTickTime or frame.resTime[powerType]

		if UnitIsDeadOrGhost('player') or
			powerType ~= POWER_MANA and powerType ~= POWER_ENERGY or
			not InCombatLockdown() and UnitPower('player', powerType) >= UnitPowerMax('player', powerType) and (
				powerType == POWER_MANA and PowerSparkDB.maxManaHide or
				powerType == POWER_ENERGY and not IsStealthed() and not UnitCanAttack('player', 'target') and PowerSparkDB.maxEnergyHide
			) then
			self.spark:Hide()
			return
		end
		if powerType == POWER_ENERGY and (not frame.energy.synced or type(resTime) ~= 'number') then
			self.spark:Hide()
			return
		end
		self.spark:Show()
		local interval = powerType == POWER_ENERGY and getEnergyInterval(frame) or 2 -- 恢复间隔
		local width = self:GetWidth()
		if powerType == POWER_MANA and type(frame.waitTime) == 'number' and frame.waitTime > now then
			self.spark:ClearAllPoints()
			self.spark:SetPoint('CENTER', self, 'LEFT', width * (frame.waitTime - now) / 5, 0)
		elseif type(resTime) == 'number' and now > resTime then
			self.spark:ClearAllPoints()
			self.spark:SetPoint('CENTER', self, 'LEFT', width * (mod(now - resTime, interval) / interval), 0)
		end
	end)
end

for _, event in pairs({
	'PLAYER_ENTERING_WORLD', -- 进入世界
	'COMBAT_LOG_EVENT_UNFILTERED', -- 战斗日志
	'ACTIVE_TALENT_GROUP_CHANGED', -- 天赋切换
	'UNIT_DISPLAYPOWER', -- 形态/能量类型变化
	'UPDATE_SHAPESHIFT_FORM', -- 形态变化
	'UNIT_POWER_UPDATE', -- 法力/能量值变化
}) do
	frame:RegisterEvent(event)
end
frame:SetScript('OnEvent', function(self, event, unit, powerToken)
	local now = clock()
	if event == 'PLAYER_ENTERING_WORLD' then
		if PowerSparkDB.enabled then
			if UnitPowerType('player') == POWER_MANA or playerClass == 'DRUID' then -- 法力
				self.lastMana = UnitPower('player', POWER_MANA)
			end
			if UnitPowerType('player') == POWER_ENERGY then -- 能量
				self.lastEnergy = UnitPower('player', POWER_ENERGY)
			end
			self.resTime[POWER_MANA] = now
			self:baselineEnergy()

			self:init(PlayerFrameManaBar)
			if playerClass == 'DRUID' then
				self:init(PlayerFrameAlternateManaBar, POWER_MANA)
				self:init(PlayerFrameDruidBar, POWER_MANA) -- 兼容 BiechuUnitFrames 德鲁伊法力条
				if PowerSparkDB.DruidBarFrame then self:init(DruidBarFrame, POWER_MANA) end -- 兼容 DruidBarFrame
			end
			if ElvUF_Player and PowerSparkDB.ElvUI then self:init(ElvUF_Player.Power) end -- 兼容 ElvUI
			if PowerSparkDB.Statusbars2 then self:init(StatusBars2_playerPowerBar) end -- 兼容 Statusbars2

			-- 兼容 SUF
			if SUFUnitplayer and PowerSparkDB.SUF then
				self:init(SUFUnitplayer.powerBar)
				if playerClass == 'DRUID' then self:init(SUFUnitplayer.druidBar, POWER_MANA) end
			end
		end
	elseif event == 'COMBAT_LOG_EVENT_UNFILTERED' then
		local guid = UnitGUID('player')
		local _, subevent, _, _, _, _, _, destGUID, _, _, _, spellId, _, _, amount, _, powerType = CombatLogGetCurrentEventInfo()
		if destGUID == guid then -- 施法目标自己
			if spellId == 13750 then -- 冲动
				if subevent == 'SPELL_AURA_APPLIED' then -- 冲动 开始
					self.interval = 1
				elseif subevent == 'SPELL_AURA_REMOVED' then -- 冲动 结束
					self.interval = nil
				end
			elseif spellId == 29166 then -- 激活
				if subevent == 'SPELL_AURA_APPLIED' then -- 激活 开始
					self.ignore = true
				elseif subevent == 'SPELL_AURA_REMOVED' then -- 激活 结束
					self.ignore = nil
				end
			elseif subevent == 'SPELL_ENERGIZE' or subevent == 'SPELL_PERIODIC_ENERGIZE' then -- 法力药水 生命分流 法力之泉 菊花茶 跳过
				if type(powerType) == 'number' and type(amount) == 'number' and amount > 0 then self.skip[powerType] = now + SKIP_WINDOW end
			end
		end
	elseif event == 'ACTIVE_TALENT_GROUP_CHANGED' then
		self.skip[POWER_MANA] = now + SKIP_WINDOW
	elseif event == 'UNIT_DISPLAYPOWER' then
		if unit == 'player' then self:baselineEnergy() end
	elseif event == 'UPDATE_SHAPESHIFT_FORM' then
		self:baselineEnergy()
	elseif event == 'UNIT_POWER_UPDATE' then
		if unit == 'player' then
			if isPowerEvent(powerToken, POWER_MANA) and (UnitPowerType('player') == POWER_MANA or playerClass == 'DRUID') then -- 法力
				local mana = UnitPower('player', POWER_MANA)
				if not consumeSkip(self, POWER_MANA, now) then -- 跳过 法力恢复
					if self.ignore then
						self.waitTime = nil
					elseif type(self.lastMana) == 'number' and mana < self.lastMana and mana < UnitPowerMax('player', POWER_MANA) then
						self.waitTime = now + 5
					elseif type(self.lastMana) == 'number' and mana > self.lastMana and (type(self.waitTime) ~= 'number' or self.waitTime < now) then
						self.resTime[POWER_MANA] = now
						self.waitTime = nil
					end
				end
				self.lastMana = mana
			end

			if isPowerEvent(powerToken, POWER_ENERGY) then -- 能量
				self:observeEnergy(now)
				self.lastEnergy = UnitPower('player', POWER_ENERGY)
			end
		end
	end
end)

frame:SetScript('OnUpdate', function(self)
	local now = clock()
	if self.energyPoll and now < self.energyPoll then return end
	self.energyPoll = now + ENERGY_POLL_INTERVAL
	self:observeEnergy(now)
end)
