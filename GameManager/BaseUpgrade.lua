-- Base Upgrade System
-- Place this in GameManager folder

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local STARTING_COST = 1000000 -- 1 million
local MAX_COST = 1000000000000000000 -- 1 quintillion (Qi)
local MAX_UPGRADES = 20

-- Calculate cost multiplier for exponential scaling
local COST_MULTIPLIER = (MAX_COST / STARTING_COST) ^ (1 / (MAX_UPGRADES - 1))

-- Module
local BaseUpgrade = {}

-- Calculate upgrade cost
function BaseUpgrade:GetUpgradeCost(currentLevel)
	if currentLevel >= MAX_UPGRADES then
		return nil -- Max level reached
	end
	
	local cost = STARTING_COST * (COST_MULTIPLIER ^ currentLevel)
	return math.floor(cost)
end

-- Format large numbers with suffixes
local function formatNumber(num)
	local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
	local tier = 1
	
	while num >= 1000 and tier < #suffixes do
		num = num / 1000
		tier = tier + 1
	end
	
	if num >= 100 then
		return string.format("%.0f%s", num, suffixes[tier])
	elseif num >= 10 then
		return string.format("%.1f%s", num, suffixes[tier])
	else
		return string.format("%.2f%s", num, suffixes[tier])
	end
end

-- Set visibility and collision for folder contents
local function setFolderVisibility(folder, visible)
	if not folder then return end
	
	for _, part in pairs(folder:GetDescendants()) do
		if part:IsA("BasePart") then
			if visible then
				part.Transparency = 0
				part.CanCollide = true
			else
				part.Transparency = 1
				part.CanCollide = false
			end
		end
	end
end

-- Unlock a specific slot
local function unlockSlot(slotsFolder, slotNumber)
	if not slotsFolder then return end
	
	local slotName = "Slot" .. slotNumber
	local slot = slotsFolder:FindFirstChild(slotName)
	
	if slot then
		-- Find key parts
		local baseModel = slot:FindFirstChild("Base")
		local placeHolder = baseModel and baseModel:FindFirstChild("PlaceHolder")
		local collect = slot:FindFirstChild("Collect")
		local upgrade = slot:FindFirstChild("Upgrade")
		
		-- Make slot visible/collidable, but SKIP PlaceHolder contents and Upgrade part
		for _, part in pairs(slot:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Check if this part is inside PlaceHolder (placed things)
				local isInPlaceHolder = false
				if placeHolder then
					isInPlaceHolder = (part == placeHolder or part:IsDescendantOf(placeHolder))
				end
				
				-- Check if this part is inside Upgrade folder (controlled by BaseSlotManager)
				local isInUpgrade = false
				if upgrade then
					isInUpgrade = (part == upgrade or part:IsDescendantOf(upgrade))
				end
				
				-- Only modify slot structure parts (Base model and Collect)
				-- Skip PlaceHolder (placed things) and Upgrade (has its own logic)
				if not isInPlaceHolder and not isInUpgrade then
					part.Transparency = 0
					-- Collect should NOT collide, Base parts can collide
					if collect and (part == collect or part:IsDescendantOf(collect)) then
						part.CanCollide = false
					else
						part.CanCollide = true
					end
				end
			end
		end
		print("Unlocked", slotName)
	else
		warn("Slot not found:", slotName)
	end
end

-- Unlock floor at specific upgrade level
local function unlockFloor(base, floorNumber)
	local floorsFolder = base:FindFirstChild("Floors")
	if not floorsFolder then return end
	
	local floorName = "Floor" .. floorNumber
	local floor = floorsFolder:FindFirstChild(floorName)
	if not floor then return end
	
	-- Make floor parts visible
	local floorsParts = floor:FindFirstChild("Floors")
	if floorsParts then
		for _, part in pairs(floorsParts:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0
				part.CanCollide = true
			end
		end
	end
	
	-- Unlock Supports, Ladder, and OuterLines
	setFolderVisibility(floor:FindFirstChild("Supports"), true)
	setFolderVisibility(floor:FindFirstChild("Ladder"), true)
	setFolderVisibility(floor:FindFirstChild("OuterLines"), true)
end

-- Apply upgrade to base
function BaseUpgrade:ApplyUpgrade(player, newLevel)
	local baseNumber = player:GetAttribute("BaseNumber")
	if not baseNumber then
		warn("Player doesn't own a base!")
		return false
	end
	
	local baseName = "Base" .. baseNumber
	local base = workspace.Bases:FindFirstChild(baseName)
	if not base then
		warn("Base not found:", baseName)
		return false
	end
	
	local slotsFolder = base:FindFirstChild("Slots")
	
	-- Unlock slot for this level (slots 1-10 already unlocked, 11-30 unlock with upgrades)
	local slotNumber = 10 + newLevel -- Slot 11 at upgrade 1, slot 30 at upgrade 20
	
	if slotsFolder then
		local slotName = "Slot" .. slotNumber
		local slot = slotsFolder:FindFirstChild(slotName)
		if slot then
			-- First, initialize the slot's structure (Base, Collect, Upgrade visibility)
			local ServerScriptService = game:GetService("ServerScriptService")
			local BaseManager = require(ServerScriptService.GameManager.BaseManager)
			BaseManager:InitializeSingleSlot(slot)
			
			-- Then setup the slot with BaseSlotManager (connects prompts, etc.)
			local BaseSlotManager = require(ServerScriptService.Things.BaseSlotManager)
			BaseSlotManager.SetupSlot(player, slot)
		end
	end
	
	-- Special upgrades at levels 1 and 11
	if newLevel == 1 then
		-- Unlock Floor 2
		unlockFloor(base, 2)
	elseif newLevel == 11 then
		-- Unlock Floor 3
		unlockFloor(base, 3)
	end
end

-- Purchase upgrade
function BaseUpgrade:PurchaseUpgrade(player)
	local currentLevel = player:GetAttribute("BaseUpgradeLevel") or 0
	
	-- Check if already max level
	if currentLevel >= MAX_UPGRADES then
		return false, "Base is already max level!"
	end
	
	-- Get upgrade cost
	local cost = self:GetUpgradeCost(currentLevel)
	if not cost then
		return false, "Max upgrades reached!"
	end
	
	-- Check if player has enough money
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Money")
	
	if not money or money.Value < cost then
		return false, "Not enough money! Need " .. formatNumber(cost)
	end
	
	-- Deduct money
	print("[BaseUpgrade:207] Subtracting upgrade cost:", cost, "| Current:", money.Value, "| New:", money.Value - cost)
	money.Value = money.Value - cost
	
	-- Increase upgrade level
	local newLevel = currentLevel + 1
	player:SetAttribute("BaseUpgradeLevel", newLevel)
	
	-- Apply upgrade effects
	self:ApplyUpgrade(player, newLevel)
	
	return true, "Base upgraded to level " .. newLevel .. "!"
end

-- Get upgrade info for UI
function BaseUpgrade:GetUpgradeInfo(player)
	local currentLevel = player:GetAttribute("BaseUpgradeLevel") or 0
	local nextCost = self:GetUpgradeCost(currentLevel)
	
	local info = {
		CurrentLevel = currentLevel,
		MaxLevel = MAX_UPGRADES,
		NextCost = nextCost,
		NextCostFormatted = nextCost and formatNumber(nextCost) or "MAX",
		CanUpgrade = nextCost ~= nil
	}
	
	-- Add special upgrade info
	if currentLevel == 0 then
		info.NextUnlock = "Floor 2 + Slot 11"
	elseif currentLevel == 10 then
		info.NextUnlock = "Floor 3 + Slot 21"
	else
		info.NextUnlock = "Slot " .. (10 + currentLevel + 1)
	end
	
	return info
end

return BaseUpgrade
