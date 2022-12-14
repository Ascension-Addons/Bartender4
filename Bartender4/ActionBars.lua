--[[
	Copyright (c) 2009, Hendrik "Nevcairiel" Leppkes < h.leppkes at gmail dot com >
	All rights reserved.
]]
local L = LibStub("AceLocale-3.0"):GetLocale("Bartender4")
local BT4ActionBars = Bartender4:NewModule("ActionBars", "AceEvent-3.0")

local ActionBar, ActionBar_MT

local abdefaults = {
	['**'] = Bartender4:Merge({
		enabled = true,
		buttons = 12,
		hidemacrotext = false,
		showgrid = false,
	}, Bartender4.StateBar.defaults),
	[1] = {
		states = {
			enabled = true,
			possess = true,
			actionbar = true,
			stance = {
				DRUID = { bear = 9, cat = 7, prowl = 8 },
				WARRIOR = { battle = 7, def = 8, berserker = 9 },
				ROGUE = { stealth = 7, shadowdance = 7 },
				HERO = { bear = 9, cat = 7, prowl = 8, stealth = 7, shadowdance = 7, battle = 7, def = 8, berserker = 9 },
			},
		},
		visibility = {
			vehicleui = false,
		},
	},
	[7] = {
		enabled = false,
	},
	[8] = {
		enabled = false,
	},
	[9] = {
		enabled = false,
	},
	[10] = {
		enabled = false,
	},
}

local defaults = {
	profile = {
		actionbars = abdefaults,
	}
}

function BT4ActionBars:OnInitialize()
	self.db = Bartender4.db:RegisterNamespace("ActionBars", defaults)

	-- fetch the prototype information
	ActionBar = Bartender4.ActionBar
	ActionBar_MT = {__index = ActionBar}
end


local LBF = LibStub("LibButtonFacade", true)

-- setup the 10 actionbars
local first = true
function BT4ActionBars:OnEnable()
	if first then
		self.playerclass = select(2, UnitClass("player"))
		self.actionbars = {}

		for i=1,10 do
			local config = self.db.profile.actionbars[i]
			if config.enabled then
				self.actionbars[i] = self:Create(i, config)
			else
				self:CreateBarOption(i, self.disabledoptions)
			end
		end

		first = nil
	end

	self:RegisterEvent("UPDATE_BINDINGS", "ReassignBindings")
	self:ReassignBindings()
end

function BT4ActionBars:SetupOptions()
	if not self.options then
		-- empty table to hold the bar options
		self.options = {}

		-- template for disabled bars
		self.disabledoptions = {
			general = {
				type = "group",
				name = L["General Settings"],
				cmdInline = true,
				order = 1,
				args = {
					enabled = {
						type = "toggle",
						name = L["Enabled"],
						desc = L["Enable/Disable the bar."],
						set = function(info, v) if v then BT4ActionBars:EnableBar(info[2]) end end,
						get = function() return false end,
					}
				}
			}
		}

		-- iterate over bars and create their option tables
		for i=1,10 do
			local config = self.db.profile.actionbars[i]
			if config.enabled then
				self:CreateBarOption(i)
			else
				self:CreateBarOption(i, self.disabledoptions)
			end
		end
	end
end

-- Applys the config in the current profile to all active Bars
function BT4ActionBars:ApplyConfig()
	for i=1,10 do
		local config = self.db.profile.actionbars[i]
		-- make sure the bar has its current config object if it exists already
		if self.actionbars[i] then
			self.actionbars[i].config = config
		end
		if config.enabled then
			self:EnableBar(i)
		else
			self:DisableBar(i)
		end
	end
end

-- we do not allow to disable the actionbars module
function BT4ActionBars:ToggleModule()
	return
end

function BT4ActionBars:UpdateButtons(force)
	for i,v in ipairs(self.actionbars) do
		for j,button in ipairs(v.buttons) do
			button:UpdateAction(force)
		end
	end
end

function BT4ActionBars:ReassignBindings()
	if InCombatLockdown() then return end
	if not self.actionbars or not self.actionbars[1] then return end
	local frame = self.actionbars[1]
	ClearOverrideBindings(frame)
	for i = 1,min(#frame.buttons, 12) do
		local button, real_button = ("ACTIONBUTTON%d"):format(i), ("BT4Button%d"):format(i)
		for k=1, select('#', GetBindingKey(button)) do
			local key = select(k, GetBindingKey(button))
			SetOverrideBindingClick(frame, false, key, real_button)
		end
	end

	for i = 1, 120 do
		-- rename old bindings from <buttonname>Secure to only <buttonname>
		local button, real_button = ("CLICK BT4Button%dSecure:LeftButton"):format(i), ("BT4Button%d"):format(i)

		for k=1, select('#', GetBindingKey(button)) do
			local key = select(k, GetBindingKey(button))
			if key and key ~= "" then
				SetBindingClick(key, real_button, "LeftButton")
			end
		end
	end
	SaveBindings(GetCurrentBindingSet() or 1)
end

-- Creates a new bar object based on the id and the specified config
function BT4ActionBars:Create(id, config)
	local id = tostring(id)
	local bar = setmetatable(Bartender4.StateBar:Create(id, config, (L["Bar %s"]):format(id)), ActionBar_MT)
	bar.module = self

	self:CreateBarOption(id)

	bar:ApplyConfig()

	return bar
end

function BT4ActionBars:DisableBar(id)
	id = tonumber(id)
	local bar = self.actionbars[id]
	if not bar then return end

	bar.config.enabled = false
	bar:Disable()
	self:CreateBarOption(id, self.disabledoptions)
end

function BT4ActionBars:EnableBar(id)
	id = tonumber(id)
	local bar = self.actionbars[id]
	local config = self.db.profile.actionbars[id]
	config.enabled = true
	if not bar then
		bar = self:Create(id, config)
		self.actionbars[id] = bar
	else
		bar.disabled = nil
		self:CreateBarOption(id)
		bar:ApplyConfig(config)
	end
	if not Bartender4.Locked then
		bar:Unlock()
	end
end

function BT4ActionBars:GetAll()
	return pairs(self.actionbars)
end

function BT4ActionBars:ForAll(method, ...)
	for _, bar in self:GetAll() do
		local func = bar[method]
		if func then
			func(bar, ...)
		end
	end
end

function BT4ActionBars:ForAllButtons(...)
	self:ForAll("ForAll", ...)
end
