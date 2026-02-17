-- UpgradeManager.lua
-- Handles upgrading things placed in slots
-- Place in: ServerScriptService/Things/

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeManager = {}

local MAX_UPGRADE_LEVEL = 100
local COST_MULTIPLIER = 1.5 -- Each upgrade costs 1.5x more
local RATE_BOOST_PER_LEVEL = 1.25 -- Each level gives 1.25x boost

-- Calculate upgrade cost
-- First upgrade = baseRate
-- Each upgrade after = previous cost * 1.5
function UpgradeManager.GetUpgradeCost(baseRate, currentLevel)
	if currentLevel >= MAX_UPGRADE_LEVEL then
		return nil -- Max level reached
	end
	
	-- First upgrade costs the base rate
	-- Level 0 -> 1 = baseRate
	-- Level 1 -> 2 = baseRate * 1.5
	-- Level 2 -> 3 = baseRate * 1.5^2
	local cost = baseRate * (COST_MULTIPLIER ^ currentLevel)
	return math.floor(cost)
end

-- Calculate upgraded rate multiplier
-- Level 0 = 1x (base rate)
-- Level 1 = 1.25x
-- Level 2 = 1.5625x (1.25^2)
-- Level 3 = 1.953125x (1.25^3)
function UpgradeManager.GetRateMultiplier(upgradeLevel)
	return RATE_BOOST_PER_LEVEL ^ upgradeLevel
end

-- Calculate upgraded rate
function UpgradeManager.GetUpgradedRate(baseRate, upgradeLevel)
	local multiplier = UpgradeManager.GetRateMultiplier(upgradeLevel)
	return baseRate * multiplier
end

-- Check if player can afford upgrade
function UpgradeManager.CanAffordUpgrade(player, cost)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return false end
	
	local money = leaderstats:FindFirstChild("Money")
	if not money then return false end
	
	return money.Value >= cost
end

-- Take money from player
function UpgradeManager.TakeMoney(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return false end
	
	local money = leaderstats:FindFirstChild("Money")
	if not money then return false end
	
	if money.Value >= amount then
		print("[UpgradeManager:65] Subtracting upgrade cost:", amount, "| Current:", money.Value, "| New:", money.Value - amount)
		money.Value = money.Value - amount
		return true
	end
	
	return false
end

-- Upgrade a slot
function UpgradeManager.UpgradeSlot(player, slot)
	-- Check if slot has a thing
	local occupied = slot:GetAttribute("Occupied")
	if not occupied then
		return false, "No thing in slot"
	end
	
	-- Get current upgrade level
	local currentLevel = slot:GetAttribute("UpgradeLevel") or 0
	
	-- Check max level
	if currentLevel >= MAX_UPGRADE_LEVEL then
		return false, "Max level reached"
	end
	
	-- Find the thing in the slot
	local baseModel = slot:FindFirstChild("Base")
	if not baseModel then return false, "Invalid slot" end
	
	local placeHolder = baseModel:FindFirstChild("PlaceHolder")
	if not placeHolder then return false, "Invalid slot" end
	
	local thing = placeHolder:FindFirstChildOfClass("Model")
	if not thing then return false, "No thing in slot" end
	
	-- Get base rate
	local ThingValueManager = require(script.Parent.ThingValueManager)
	local baseRate = ThingValueManager.GetThingValue(thing)
	
	-- Calculate upgrade cost
	local cost = UpgradeManager.GetUpgradeCost(baseRate, currentLevel)
	if not cost then
		return false, "Max level reached"
	end
	
	-- Check if player can afford
	if not UpgradeManager.CanAffordUpgrade(player, cost) then
		return false, "Not enough money"
	end
	
	-- Take money
	if not UpgradeManager.TakeMoney(player, cost) then
		return false, "Payment failed"
	end
	
	-- Upgrade the slot
	local newLevel = currentLevel + 1
	slot:SetAttribute("UpgradeLevel", newLevel)
	
	-- Play upgrade sound
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEvents then
		local playSoundEvent = remoteEvents:FindFirstChild("PlaySoundEvent")
		if playSoundEvent then
			playSoundEvent:FireClient(player, "click")
		end
	end
	
	-- Update upgrade UI (not money display - that's handled by accumulation)
	UpgradeManager.UpdateUpgradeUI(slot, baseRate, newLevel)
	
	return true, newLevel
end

-- Update upgrade UI on slot
function UpgradeManager.UpdateUpgradeUI(slot, baseRate, currentLevel)
	local upgrade = slot:FindFirstChild("Upgrade")
	if not upgrade then return end
	
	local surfaceGui = upgrade:FindFirstChild("SurfaceGui")
	if not surfaceGui then return end
	
	local frame = surfaceGui:FindFirstChild("Frame")
	if not frame then return end
	
	-- Calculate the new rate with upgrade
	local currentRate = UpgradeManager.GetUpgradedRate(baseRate, currentLevel)
	local nextRate = UpgradeManager.GetUpgradedRate(baseRate, currentLevel + 1)
	
	-- Update level display (shows current level -> next level)
	local levelChange = frame:FindFirstChild("LevelChange")
	if levelChange then
		if currentLevel >= MAX_UPGRADE_LEVEL then
			levelChange.Text = "Level MAX"
		else
			levelChange.Text = "Level " .. currentLevel .. " -> Level " .. (currentLevel + 1)
		end
	end
	
	-- Update cost display
	local costLabel = frame:FindFirstChild("Cost")
	if costLabel then
		if currentLevel >= MAX_UPGRADE_LEVEL then
			costLabel.Text = "MAX LEVEL"
		else
			local upgradeCost = UpgradeManager.GetUpgradeCost(baseRate, currentLevel)
			costLabel.Text = UpgradeManager.FormatMoney(upgradeCost)
		end
	end
end

-- Format money for display
function UpgradeManager.FormatMoney(amount)
	local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
	local tier = 1
	local num = amount

	while num >= 1000 and tier < #suffixes do
		num = num / 1000
		tier = tier + 1
	end

	-- Check if it's a whole number
	local isWhole = (num == math.floor(num))

	local formatted
	if isWhole then
		formatted = string.format("$%.0f%s", num, suffixes[tier])
	elseif num >= 100 then
		formatted = string.format("$%.0f%s", num, suffixes[tier])
	elseif num >= 10 then
		formatted = string.format("$%.1f%s", num, suffixes[tier])
	else
		formatted = string.format("$%.2f%s", num, suffixes[tier])
	end
	
	return formatted
end

-- Initialize remote events
function UpgradeManager.Init()
	local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
	if not remoteEvents then
		warn("[UpgradeManager] RemoteEvents folder not found!")
		return
	end
	
	-- Create or get UpgradeSlot RemoteFunction
	local upgradeSlotFunc = remoteEvents:FindFirstChild("UpgradeSlot")
	if not upgradeSlotFunc then
		upgradeSlotFunc = Instance.new("RemoteFunction")
		upgradeSlotFunc.Name = "UpgradeSlot"
		upgradeSlotFunc.Parent = remoteEvents
	end
	
	upgradeSlotFunc.OnServerInvoke = function(player, slot)
		return UpgradeManager.UpgradeSlot(player, slot)
	end
end

return UpgradeManager
