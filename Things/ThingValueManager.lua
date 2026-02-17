-- ThingValueManager.lua
-- Handles money generation from placed things (online/offline)
-- Each thing has its own unique value!
-- Place in: ServerScriptService/Things/

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ThingValueManager = {}

local THING_VALUES = {
	-- Common
	["iPhone 2G"] = 2,
	["iPhone 6"] = 5,
	["iPhone SE"] = 8,
	["Nokia"] = 12,
	["Samsung S6"] = 16,

	-- Uncommon
	["iPhone 7"] = 25,
	["RealMe C67"] = 40,
	["Samsung S7"] = 60,
	["Samsung S8"] = 85,
	["Samsung Tab"] = 110,

	-- Rare
	["Huawei Y6"] = 150,
	["iPhone 8"] = 200,
	["Samsung A50"] = 260,
	["Samsung Note8"] = 330,
	["Samsung S10"] = 400,

	-- Epic
	["iPhone 9"] = 500,
	["iPhone Bronze"] = 650,
	["OnePlus 12"] = 850,
	["RealMe GT6"] = 1100,
	["Samsung Tab S"] = 1400,

	-- Legendary
	["Huawei Nova Flip"] = 2500,
	["iPhone Silver"] = 4000,
	["iPhone XR"] = 5000,
	["Oppo A17"] = 6000,
	["Samsung S20"] = 8000,

	-- Mythical
	["Huawei Mate 50"] = 11000,
	["iPhone 11"] = 25000,
	["iPhone Gold"] = 40000,
	["iPhone 13"] = 67000,

	-- Divine
	["iPhone 14 Pro"] = 110000,
	["iPhone 15 Pro"] = 180000,
	["iPad 4th Gen"] = 300000,
	["iPhone 17"] = 444444,

	-- Secret
	["iPhone 13 Pro"] = 1000000,
	["Samsung S25 Ultra"] = 2000000,
	["iPad 6th Gen"] = 3000000,
	["iPad 9th Gen"] = 4000000,
	["iPhone 16 Pro"] = 5000000,

	-- Celestial
	["iPhone 17 Pro"] = 10000000, -- 10M per second (lowest celestial)
	["Samsung Z Flip"] = 15000000, -- 15M per second
	["iPad Pro"] = 20000000, -- 20M per second
	["iPhone 17 Pro Max"] = 30000000, -- 30M per second (best celestial)

	-- Limited (wheel/robux only)
	["Valentine Pro Max"] = 50000000, -- 50M per second (ultra rare)
}

-- Default values by rarity (fallback if thing not in list) - per second
local RARITY_DEFAULTS = {
	Common = 2,
	Uncommon = 10,
	Rare = 30,
	Epic = 80,
	Legendary = 250,
	Mythical = 750,
	Divine = 2000,
	Secret = 6000,
	Celestial = 10000,
	Limited = 20000
}

local OFFLINE_MULTIPLIER = 0.25 -- 25% of normal rate when offline
local UPDATE_INTERVAL = 1 -- Update every 1 second

local playerEarnings = {} -- Track earnings for each player

-- Initialize
function ThingValueManager.Init()
	-- Setup for new players
	Players.PlayerAdded:Connect(function(player)
		ThingValueManager.SetupPlayer(player)
	end)

	-- Setup existing players
	for _, player in ipairs(Players:GetPlayers()) do
		ThingValueManager.SetupPlayer(player)
	end

	-- Start earning loop
	task.spawn(function()
		ThingValueManager.EarningLoop()
	end)
end

-- Count how many unique thing values we have
function ThingValueManager.CountThingValues()
	local count = 0
	for _ in pairs(THING_VALUES) do
		count = count + 1
	end
	return count
end

-- Setup player earnings
function ThingValueManager.SetupPlayer(player)
	playerEarnings[player.UserId] = {
		LastUpdate = os.time(),
		TotalEarned = 0,
		CurrentRate = 0 -- Dollars per minute
	}

	-- Calculate offline earnings when player joins
	ThingValueManager.CalculateOfflineEarnings(player)

	-- Cleanup on leave
	player.AncestryChanged:Connect(function()
		if not player:IsDescendantOf(game) then
			-- Save last update time for offline calculations
			if playerEarnings[player.UserId] then
				playerEarnings[player.UserId].LastUpdate = os.time()
			end
		end
	end)
end

-- Calculate offline earnings
function ThingValueManager.CalculateOfflineEarnings(player)
	-- In a real game, you'd load the last play time from DataStore
	-- Example of how this would work:
	-- local lastPlayTime = LoadFromDataStore(player.UserId, "LastPlayTime")
	-- local currentTime = os.time()
	-- local timeDiff = currentTime - lastPlayTime
	-- local offlineMinutes = timeDiff / 60
	-- 
	-- if offlineMinutes > 0 then
	--     local offlineEarnings = currentRate * offlineMinutes * OFFLINE_MULTIPLIER
	--     -- Give player the offline earnings
	-- end
end

-- Main earning loop
function ThingValueManager.EarningLoop()
	while true do
		task.wait(UPDATE_INTERVAL)

		for _, player in ipairs(Players:GetPlayers()) do
			ThingValueManager.UpdatePlayerEarnings(player)
		end
	end
end

-- Update earnings for a single player (accumulates money in slots instead of giving directly)
function ThingValueManager.UpdatePlayerEarnings(player)
	local playerData = playerEarnings[player.UserId]
	if not playerData then return end

	-- Get all placed things and accumulate money per slot
	local BaseSlotManager = require(script.Parent.BaseSlotManager)
	local Workspace = game:GetService("Workspace")
	local bases = Workspace:FindFirstChild("Bases")
	if not bases then return end

	local baseNumber = player:GetAttribute("BaseNumber")
	if not baseNumber then return end

	local playerBase = bases:FindFirstChild("Base" .. baseNumber)
	if not playerBase then return end

	local slotsFolder = playerBase:FindFirstChild("Slots")
	if not slotsFolder then return end

	-- Calculate earnings for each occupied slot
	local currentTime = os.time()
	local timeDiff = currentTime - playerData.LastUpdate
	local secondsPassed = timeDiff

	if secondsPassed > 0 then
		for _, slot in ipairs(slotsFolder:GetChildren()) do
			if slot:IsA("Model") and slot:GetAttribute("Occupied") then
				local baseModel = slot:FindFirstChild("Base")
				if baseModel then
					local placeHolder = baseModel:FindFirstChild("PlaceHolder")
					if placeHolder then
						local thing = placeHolder:FindFirstChildOfClass("Model")
						if thing then
							-- Calculate earnings for this thing
							local rate = ThingValueManager.GetThingValue(thing)

							-- Apply rebirth/gamepass multiplier
							local multiplier = player:GetAttribute("RebirthMultiplier") or 1
							local earnings = rate * multiplier * secondsPassed

							-- Add to slot's accumulated money
							local currentAccumulated = slot:GetAttribute("AccumulatedMoney") or 0
							slot:SetAttribute("AccumulatedMoney", currentAccumulated + earnings)

							-- Update money display
							BaseSlotManager.UpdateSlotMoneyDisplay(slot, currentAccumulated + earnings)

							-- Update rate display
							local collect = slot:FindFirstChild("Collect")
							if collect then
								local statsGui = collect:FindFirstChild("StatsGui")
								if statsGui then
									local frame = statsGui:FindFirstChild("Frame")
									if frame then
										local rateLabel = frame:FindFirstChild("Rate")
										if rateLabel then
											local formatted
											if rate >= 1000000 then
												formatted = string.format("$%.1fM/s", rate / 1000000)
											elseif rate >= 1000 then
												formatted = string.format("$%.1fK/s", rate / 1000)
											else
												formatted = "$" .. tostring(math.floor(rate)) .. "/s"
											end
											rateLabel.Text = formatted
										end
									end
								end
							end
						end
					end
				end
			end
		end

		playerData.LastUpdate = currentTime
	end
end

-- Get value of a single thing (per SECOND) - UNIQUE PER THING + MUTATIONS + UPGRADES!
function ThingValueManager.GetThingValue(thing)
	local handle = thing:FindFirstChild("Handle")
	if not handle then return 0 end

	local statsGui = handle:FindFirstChild("StatsGui")
	if not statsGui then return 0 end

	local frame = statsGui:FindFirstChild("Frame")
	if not frame then return 0 end

	-- Get thing name from Name label
	local nameLabel = frame:FindFirstChild("Name")
	local thingName = nameLabel and nameLabel.Text or thing.Name

	-- Get rarity from Class label
	local classLabel = frame:FindFirstChild("Class")
	local rarity = classLabel and classLabel.Text or "Common"

	-- Get mutation multiplier
	local mutationLabel = frame:FindFirstChild("Mutation")
	local mutation = mutationLabel and mutationLabel.Text or "None"

	-- Get base value for this thing
	local baseValue = THING_VALUES[thingName]

	if not baseValue then
		-- Fallback to rarity default
		baseValue = RARITY_DEFAULTS[rarity] or 0
	end

	-- Apply mutation multiplier
	local mutationMultiplier = 1
	if mutation == "Gold" then
		mutationMultiplier = 1.5
	elseif mutation == "Diamond" then
		mutationMultiplier = 2
	elseif mutation == "Emerald" then
		mutationMultiplier = 3
	end

	local valueWithMutation = baseValue * mutationMultiplier

	-- Apply upgrade multiplier if thing is placed in a slot
	local isPlaced = thing:GetAttribute("IsPlaced")
	if isPlaced then
		-- Find the slot this thing is in
		local slotName = thing:GetAttribute("SlotName")
		local ownerUserId = thing:GetAttribute("OwnerUserId")

		if slotName and ownerUserId then
			-- Find owner's base using their UserId
			local bases = workspace:FindFirstChild("Bases")
			if bases then
				local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
				if ownerPlayer then
					local baseNumber = ownerPlayer:GetAttribute("BaseNumber")
					if baseNumber then
						local playerBase = bases:FindFirstChild("Base" .. baseNumber)
						if playerBase then
							local slotsFolder = playerBase:FindFirstChild("Slots")
							if slotsFolder then
								local slot = slotsFolder:FindFirstChild(slotName)
								if slot then
									local upgradeLevel = slot:GetAttribute("UpgradeLevel") or 0
									if upgradeLevel > 0 then
										-- Apply upgrade multiplier: 1.25^level (exponential scaling)
										local upgradeMultiplier = 1.25 ^ upgradeLevel
										return valueWithMutation * upgradeMultiplier
									end
								end
							end
						end
					end
				end
			end
		end
	end

	return valueWithMutation
end

-- Give money to player
function ThingValueManager.GiveMoney(player, amount)
	if amount <= 0 then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local money = leaderstats:FindFirstChild("Money")
	if money then
		print("[ThingValueManager:318] Adding collected value:", amount, "| Current:", money.Value, "| New:", money.Value + amount)
		money.Value = money.Value + amount
	end
end

-- Get player's current earning rate
function ThingValueManager.GetEarningRate(player)
	local playerData = playerEarnings[player.UserId]
	if not playerData then return 0 end

	return playerData.CurrentRate
end

-- Get total earnings
function ThingValueManager.GetTotalEarnings(player)
	local playerData = playerEarnings[player.UserId]
	if not playerData then return 0 end

	return playerData.TotalEarned
end

-- Calculate sell value (instant cash instead of passive)
function ThingValueManager.GetSellValue(thing)
	-- Sell value is typically higher than passive earnings
	-- Let's make it equivalent to 1 hour of passive income
	local perSecondValue = ThingValueManager.GetThingValue(thing)
	local sellValue = perSecondValue * 3600 -- 1 hour worth (3600 seconds)

	return sellValue
end

-- Format money display
function ThingValueManager.FormatMoney(amount)
	if amount >= 1000000000 then
		return string.format("$%.2fB", amount / 1000000000)
	elseif amount >= 1000000 then
		return string.format("$%.2fM", amount / 1000000)
	elseif amount >= 1000 then
		return string.format("$%.2fK", amount / 1000)
	else
		return string.format("$%.0f", amount)
	end
end

-- Get thing info for display
function ThingValueManager.GetThingInfo(thing)
	local handle = thing:FindFirstChild("Handle")
	if not handle then return nil end

	local statsGui = handle:FindFirstChild("StatsGui")
	if not statsGui then return nil end

	local frame = statsGui:FindFirstChild("Frame")
	if not frame then return nil end

	local nameLabel = frame:FindFirstChild("Name")
	local classLabel = frame:FindFirstChild("Class")
	local mutationLabel = frame:FindFirstChild("Mutation")

	local thingName = nameLabel and nameLabel.Text or thing.Name
	local rarity = classLabel and classLabel.Text or "Unknown"
	local mutation = mutationLabel and mutationLabel.Text or "None"

	local perMinuteValue = ThingValueManager.GetThingValue(thing)
	local sellValue = ThingValueManager.GetSellValue(thing)

	-- Build display name with mutation
	local displayName = thingName
	if mutation ~= "None" then
		displayName = mutation .. " " .. thingName
	end

	return {
		Name = displayName,
		Rarity = rarity,
		Mutation = mutation,
		PassiveValue = ThingValueManager.FormatMoney(perMinuteValue) .. "/sec",
		SellValue = ThingValueManager.FormatMoney(sellValue),
		RawPassiveValue = perMinuteValue,
		RawSellValue = sellValue
	}
end

-- Add a new thing value (for when you add new things to your game)
function ThingValueManager.AddThingValue(thingName, valuePerSecond)
	THING_VALUES[thingName] = valuePerSecond
	print("[ThingValueManager] Added value for " .. thingName .. ": $" .. valuePerSecond .. "/sec")
end

-- Get value by thing name and rarity (for display before spawning)
function ThingValueManager.GetThingValueByName(thingName, rarity)
	-- Get base value for this thing
	local baseValue = THING_VALUES[thingName]

	if not baseValue then
		-- Debug: Print when falling back to rarity default
		warn("[ThingValueManager] Thing name '" .. tostring(thingName) .. "' not found in THING_VALUES, using rarity default for " .. tostring(rarity))
		-- Fallback to rarity default
		baseValue = RARITY_DEFAULTS[rarity] or 100
	else
		print("[ThingValueManager] Found value for '" .. thingName .. "': " .. baseValue)
	end

	return baseValue
end

-- Get all thing values (for debugging)
function ThingValueManager.GetAllThingValues()
	return THING_VALUES
end

return ThingValueManager
