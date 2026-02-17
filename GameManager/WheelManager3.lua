-- WheelManager.lua
-- Manages wheel spins, playtime timer, and reward distribution

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local WheelManager = {}

-- Configuration
local PLAYTIME_REQUIRED = 900 -- 15 minutes in seconds (15 * 60)

-- Reward chances (must add up to 100)
local REWARDS = {
	{Name = "1M Cash", Type = "Money", Amount = 1000000, Chance = 49.9},
	{Name = "2x Money", Type = "Boost", Duration = 600, Multiplier = 2, Chance = 25}, -- 10 minutes money
	{Name = "2x Speed", Type = "SpeedBoost", Duration = 600, Multiplier = 2, Chance = 15}, -- 10 minutes 2x speed
	{Name = "100M Cash", Type = "Money", Amount = 100000000, Chance = 9},
	{Name = "Random Celestial", Type = "Item", ItemName = "RandomCelestial", Chance = 1}, -- Random celestial item
	{Name = "Love Knight", Type = "Item", ItemName = "Love Knight", Chance = 0.1}, -- Ultra rare Limited
}

-- Remote events (create these manually in ReplicatedStorage > RemoteEvents)
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local spinWheelEvent = remoteEventsFolder:WaitForChild("SpinWheel")
local updateWheelUI = remoteEventsFolder:WaitForChild("UpdateWheelUI")

-- Player data tracking
local playerSpins = {} -- {[userId] = spinsAvailable}
local playerPlaytime = {} -- {[userId] = secondsPlayed}
local playerTimers = {} -- {[userId] = thread}

-- Give money to player
local function giveMoney(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local money = leaderstats:FindFirstChild("Money")
		if money then
			money.Value = money.Value + amount
			return true
		end
	end
	return false
end

-- Give boost to player
local function giveBoost(player, multiplier, duration)
	local BoostManager = require(script.Parent.BoostManager)
	if BoostManager and BoostManager.ApplyMoneyBoost then
		BoostManager.ApplyMoneyBoost(player, multiplier, duration)
		return true
	end
	return false
end

-- Give speed boost to player
local function giveSpeedBoost(player, multiplier, duration)
	local BoostManager = require(script.Parent.BoostManager)
	if BoostManager and BoostManager.ApplySpeedBoost then
		BoostManager.ApplySpeedBoost(player, multiplier, duration)
		return true
	end
	return false
end

-- Give item to player
local function giveItem(player, itemName)
	-- Give the actual item to player's inventory
	local ServerScriptService = game:GetService("ServerScriptService")
	local ThingInventoryManager = require(ServerScriptService.Things.ThingInventoryManager)
	local ThingValueManager = require(ServerScriptService.Things.ThingValueManager)
	
	-- Handle random celestial selection
	local actualItemName = itemName
	local rarity = "Limited" -- Default for Limited items from wheel
	
	if itemName == "RandomCelestial" then
		-- Pick a random celestial based on spawn weights
		local celestialItems = {
			{name = "Angel", weight = 25},
			{name = "Frostbite", weight = 25},
			{name = "HeartBreaker", weight = 25},
			{name = "Space", weight = 25},
		}
		
		local totalWeight = 0
		for _, item in ipairs(celestialItems) do
			totalWeight = totalWeight + item.weight
		end
		
		local randomValue = math.random() * totalWeight
		local currentWeight = 0
		
		for _, item in ipairs(celestialItems) do
			currentWeight = currentWeight + item.weight
			if randomValue <= currentWeight then
				actualItemName = item.name
				break
			end
		end
		
		rarity = "Celestial"
	elseif itemName == "Love Knight" then
		rarity = "Limited"
	else
		-- For other items, try to determine rarity
		rarity = "Celestial" -- Default assumption for wheel items
	end
	
	-- Get the rate for this thing
	local rate = ThingValueManager.GetThingValueByName(actualItemName, rarity)
	
	-- Add to inventory with no mutation (None)
	local success, message = ThingInventoryManager.AddToInventory(
		player,
		actualItemName,
		"", -- No mutation
		rarity,
		rate,
		{}, -- Empty GUI data (will use template)
		0 -- No upgrade level
	)
	
	if success then
		-- Notify player
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		local notificationEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("Notification")
		
		if notificationEvent then
			notificationEvent:FireClient(player, "🎉 You won " .. actualItemName .. "! Check your inventory!", true)
		end
		return true
	else
		-- Failed to add (inventory full?)
		warn("Failed to give item to", player.Name, ":", message)
		return false
	end
end

-- Select random reward based on chances
local function selectReward()
	local random = math.random() * 100
	local cumulative = 0
	
	for _, reward in ipairs(REWARDS) do
		cumulative = cumulative + reward.Chance
		if random <= cumulative then
			return reward
		end
	end
	
	-- Fallback to first reward if something goes wrong
	return REWARDS[1]
end

-- Give reward to player
function WheelManager:GiveReward(player, reward)
	local success = false
	
	if reward.Type == "Money" then
		success = giveMoney(player, reward.Amount)
		if success then
			print(player.Name, "won", reward.Amount, "money from wheel")
		end
		
	elseif reward.Type == "Boost" then
		success = giveBoost(player, reward.Multiplier, reward.Duration)
		if success then
			print(player.Name, "won", reward.Multiplier .. "x money boost for", reward.Duration, "seconds")
		end
		
	elseif reward.Type == "SpeedBoost" then
		success = giveSpeedBoost(player, reward.Multiplier, reward.Duration)
		if success then
			print(player.Name, "won", reward.Multiplier .. "x speed boost for", reward.Duration, "seconds")
		end
		
	elseif reward.Type == "Item" then
		success = giveItem(player, reward.ItemName)
		if success then
			print(player.Name, "won item:", reward.ItemName)
		end
	end
	
	return success
end

-- Spin the wheel
function WheelManager:SpinWheel(player)
	local userId = player.UserId
	
	-- Check if player has spins available
	if not playerSpins[userId] or playerSpins[userId] <= 0 then
		warn(player.Name, "tried to spin without available spins")
		return false, "No spins available!"
	end
	
	-- Deduct one spin
	playerSpins[userId] = playerSpins[userId] - 1
	
	-- Store as player attribute for SaveManager
	player:SetAttribute("WheelSpins", playerSpins[userId])
	
	-- Select reward
	local reward = selectReward()
	
	-- Give reward
	local success = self:GiveReward(player, reward)
	
	-- Update UI
	self:UpdatePlayerUI(player)
	
	return true, reward
end

-- Add spins to player
function WheelManager:AddSpins(player, amount)
	local userId = player.UserId
	
	if not playerSpins[userId] then
		playerSpins[userId] = 0
	end
	
	playerSpins[userId] = playerSpins[userId] + amount
	
	-- Store as player attribute for SaveManager
	player:SetAttribute("WheelSpins", playerSpins[userId])
	
	print(player.Name, "received", amount, "wheel spins (total:", playerSpins[userId] .. ")")
	
	-- Update UI
	self:UpdatePlayerUI(player)
end

-- Get player spins
function WheelManager:GetSpins(player)
	return playerSpins[player.UserId] or 0
end

-- Get player playtime
function WheelManager:GetPlaytime(player)
	return playerPlaytime[player.UserId] or 0
end

-- Initialize player spins from saved data
function WheelManager:InitializePlayer(player, savedSpins)
	local userId = player.UserId
	playerSpins[userId] = savedSpins or 0
	-- Store as player attribute for SaveManager
	player:SetAttribute("WheelSpins", playerSpins[userId])
	print("[WheelManager] Initialized", player.Name, "with", playerSpins[userId], "spins")
end

-- Update player UI
function WheelManager:UpdatePlayerUI(player)
	local spins = self:GetSpins(player)
	local playtime = self:GetPlaytime(player)
	local timeRemaining = math.max(0, PLAYTIME_REQUIRED - playtime)
	
	updateWheelUI:FireClient(player, {
		Spins = spins,
		PlaytimeRemaining = timeRemaining,
		PlaytimeRequired = PLAYTIME_REQUIRED
	})
end

-- Start playtime tracker for player
local function startPlaytimeTracker(player)
	local userId = player.UserId
	
	-- Initialize playtime
	playerPlaytime[userId] = 0
	playerSpins[userId] = playerSpins[userId] or 0
	
	-- Start timer thread
	playerTimers[userId] = task.spawn(function()
		while player.Parent do
			task.wait(1) -- Update every second
			
			if player.Parent then
				playerPlaytime[userId] = playerPlaytime[userId] + 1
				
				-- Check if player earned a free spin
				if playerPlaytime[userId] >= PLAYTIME_REQUIRED then
					WheelManager:AddSpins(player, 1)
					playerPlaytime[userId] = 0 -- Reset timer for next spin
					print(player.Name, "earned 1 free spin from playtime!")
				end
				
				-- Update UI every 10 seconds or when close to earning spin
				if playerPlaytime[userId] % 10 == 0 or playerPlaytime[userId] >= PLAYTIME_REQUIRED - 10 then
					WheelManager:UpdatePlayerUI(player)
				end
			end
		end
	end)
end

-- Player joined
Players.PlayerAdded:Connect(function(player)
	startPlaytimeTracker(player)
	
	-- Send initial UI update after brief delay
	task.wait(1)
	WheelManager:UpdatePlayerUI(player)
end)

-- Player leaving
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	
	-- Cancel timer thread
	if playerTimers[userId] then
		task.cancel(playerTimers[userId])
		playerTimers[userId] = nil
	end
	
	-- Store final spin count as attribute before cleanup
	if playerSpins[userId] then
		player:SetAttribute("WheelSpins", playerSpins[userId])
		print("[WheelManager] Saved", playerSpins[userId], "spins for", player.Name)
	end
	
	-- Note: SaveManager's PlayerRemoving will handle the actualDataStore save
	
	-- Clean up data
	playerPlaytime[userId] = nil
	playerSpins[userId] = nil
end)

-- Remote event handler
spinWheelEvent.OnServerEvent:Connect(function(player, action)
	-- Handle update request (when GUI opens)
	if action == "RequestUpdate" then
		WheelManager:UpdatePlayerUI(player)
		return
	end
	
	-- Handle spin request (default behavior)
	local success, result = WheelManager:SpinWheel(player)
	
	if success then
		-- Send reward to client for animation
		updateWheelUI:FireClient(player, {
			Reward = result
		})
	else
		-- Send error message
		updateWheelUI:FireClient(player, {
			Error = result
		})
	end
end)

print("WheelManager loaded successfully")

return WheelManager
