-- Developer Products Module
-- Place in ServerScriptService/GameManager/Monetization

local DevProducts = {}

-- Define your developer products here with their IDs and rewards
-- Replace these placeholder IDs with your actual product IDs from Roblox
DevProducts.Products = {
	-- Cash Pack products
	CashPack1 = {
		ProductId = 3538164162, -- 9 Robux
		Name = "Cash Pack #1",
		Amount = 100000, -- $100K
		Type = "Money"
	},

	CashPack2 = {
		ProductId = 3538164363, -- 19 Robux
		Name = "Cash Pack #2",
		Amount = 1000000, -- $1M
		Type = "Money"
	},

	CashPack3 = {
		ProductId = 3538164576, -- 49 Robux
		Name = "Cash Pack #3",
		Amount = 100000000, -- $100M
		Type = "Money"
	},

	CashPack4 = {
		ProductId = 3538164884, -- 99 Robux
		Name = "Cash Pack #4",
		Amount = 1000000000, -- $1B
		Type = "Money"
	},

	CashPack5 = {
		ProductId = 3538165143, -- 199 Robux
		Name = "Cash Pack #5",
		Amount = 100000000000, -- $100B
		Type = "Money"
	},

	-- Speed products (5 tiers for +10 speed based on current speed range)
	SpeedTier1 = {
		ProductId = 3538157546, -- 18-50 speed (9 Robux)
		Name = "+10 Speed (Tier 1)",
		Amount = 10, -- +10 speed
		Type = "Speed",
		MinSpeed = 18,
		MaxSpeed = 50
	},

	SpeedTier2 = {
		ProductId = 3538157805, -- 51-100 speed (29 Robux)
		Name = "+10 Speed (Tier 2)",
		Amount = 10, -- +10 speed
		Type = "Speed",
		MinSpeed = 51,
		MaxSpeed = 100
	},

	SpeedTier3 = {
		ProductId = 3538158069, -- 101-150 speed (69 Robux)
		Name = "+10 Speed (Tier 3)",
		Amount = 10, -- +10 speed
		Type = "Speed",
		MinSpeed = 101,
		MaxSpeed = 150
	},

	SpeedTier4 = {
		ProductId = 3538158238, -- 151-200 speed (99 Robux)
		Name = "+10 Speed (Tier 4)",
		Amount = 10, -- +10 speed
		Type = "Speed",
		MinSpeed = 151,
		MaxSpeed = 200
	},

	SpeedTier5 = {
		ProductId = 3538158409, -- 201+ speed (129 Robux)
		Name = "+10 Speed (Tier 5)",
		Amount = 10, -- +10 speed
		Type = "Speed",
		MinSpeed = 201,
		MaxSpeed = 2000
	},

	-- Base upgrades
	BaseUpgrade = {
		ProductId = 0000000000, -- Replace with actual product ID
		Name = "Base Upgrade",
		Amount = 1, -- +1 upgrade level
		Type = "BaseUpgrade"
	},

	-- Carry upgrade (29 Robux)
	CarryUpgrade = {
		ProductId = 3538156782, -- 29 Robux
		Name = "Carry Upgrade",
		Amount = 1, -- +1 carry
		Type = "CarryUpgrade"
	},

	-- Wheel Spins
	WheelSpin1 = {
		ProductId = 3538157237, -- 29 Robux
		Name = "+1 Spin",
		Amount = 1, -- +1 wheel spin
		Type = "WheelSpin"
	},

	WheelSpin5 = {
		ProductId = 3538158736, -- 99 Robux
		Name = "+5 Spins",
		Amount = 5, -- +5 wheel spins
		Type = "WheelSpin"
	},

	-- Steal (49 Robux)
	Steal = {
		ProductId = 3533182046, -- 49 Robux
		Name = "Steal",
		Type = "Steal"
	},

	-- Pro Pack
	ProPack = {
		ProductId = 3538160531, -- 49 Robux
		Name = "Pro Pack",
		SpeedBoost = 50,
		Cash = 10000000, -- 10M
		Thing = "King", -- Secret King
		Rarity = "Secret",
		Type = "Pack"
	},

	-- OP Pack
	OPPack = {
		ProductId = 3538160313, -- 99 Robux
		Name = "OP Pack",
		SpeedBoost = 100,
		Cash = 100000000, -- 100M
		Thing = "Chill Bro", -- Secret Chill Bro
		Rarity = "Secret",
		Type = "Pack"
	},
	-- Godspeed Tsunami Spawn (19 Robux)
	GodspeedSpawn = {
		ProductId = 3538160106, -- 19 Robux
		Name = "Godspeed Tsunami",
		Type = "GodspeedSpawn"
	},

	-- Love Knight (399 Robux) - Limited Rarity
	LoveKnight = {
		ProductId = 3538163795, -- 399 Robux
		Name = "Love Knight",
		Thing = "Love Knight",
		Mutation = "",
		Rarity = "Limited",
		Type = "Thing"
	},

	-- Skip Rebirth Requirements (29 Robux)
	SkipRebirth = {
		ProductId = 3538161718, -- 29 Robux
		Name = "Skip Rebirth",
		Type = "SkipRebirth"
	},

	-- Stop Tsunamis for 30 seconds (19 Robux)
	StopTsunamis = {
		ProductId = 3538162731, -- 19 Robux
		Name = "Stop Tsunamis",
		Duration = 30, -- 30 seconds
		Type = "StopTsunamis"
	},

	-- 10-Minute 2x Speed Boost (19 Robux)
	Boost2xSpeed = {
		ProductId = 3538159618, -- 19 Robux
		Name = "2x Speed (10 Min)",
		Duration = 600, -- 10 minutes
		Type = "Boost2xSpeed"
	},

	-- 10-Minute 2x Money Boost (19 Robux)
	Boost2xMoney = {
		ProductId = 3538159449, -- 19 Robux
		Name = "2x Money (10 Min)",
		Duration = 600, -- 10 minutes
		Type = "Boost2xMoney"
	}
}

-- Get product by ID
function DevProducts:GetProductById(productId)
	for _, product in pairs(self.Products) do
		if product.ProductId == productId then
			return product
		end
	end
	return nil
end

-- Process purchase (called by MarketplaceHandler)
function DevProducts:ProcessPurchase(player, productId)
	local product = self:GetProductById(productId)

	if not product then
		warn("Unknown product ID:", productId)
		return false
	end

	-- Get notification event for feedback
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	local notificationEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("Notification")
	local playSoundEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("PlaySoundEvent")

	-- Grant rewards based on product type
	if product.Type == "Money" then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local money = leaderstats:FindFirstChild("Money")
			if money then
				money.Value = money.Value + product.Amount
				if notificationEvent then
					notificationEvent:FireClient(player, "Purchased " .. product.Name .. "!", true)
				end
				if playSoundEvent then
					playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
				end
				return true
			end
		end

	elseif product.Type == "Speed" then
		local currentSpeed = player:GetAttribute("Speed") or 18

		-- For tiered speed products, validate speed range
		if product.MinSpeed and product.MaxSpeed then
			if currentSpeed < product.MinSpeed or currentSpeed > product.MaxSpeed then
				warn(player.Name, "tried to purchase", product.Name, "but speed is outside valid range")
				return false
			end
		end

		local newSpeed = math.min(currentSpeed + product.Amount, 2000) -- Max 2000
		player:SetAttribute("Speed", newSpeed)

		-- Update WalkSpeed
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = newSpeed
			end
		end

		if notificationEvent then
			notificationEvent:FireClient(player, "Speed upgraded with Robux! +" .. product.Amount .. " (" .. newSpeed .. ")", true)
		end

		if playSoundEvent then
			playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
		end

		return true

	elseif product.Type == "BaseUpgrade" then
		local currentLevel = player:GetAttribute("BaseUpgradeLevel") or 0
		if currentLevel < 20 then
			player:SetAttribute("BaseUpgradeLevel", currentLevel + product.Amount)
			if notificationEvent then
				notificationEvent:FireClient(player, "Base upgraded! Level " .. (currentLevel + product.Amount), true)
			end
			if playSoundEvent then
				playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
			end
			return true
		else
			warn(player.Name, "is already at max base level")
			if notificationEvent then
				notificationEvent:FireClient(player, "Already at max base level!", false)
			end
			return false
		end

	elseif product.Type == "CarryUpgrade" then
		local currentCarry = player:GetAttribute("CarryCapacity") or 1
		if currentCarry < 10 then
			player:SetAttribute("CarryCapacity", currentCarry + product.Amount)
			if notificationEvent then
				notificationEvent:FireClient(player, "Carry upgraded with Robux! (" .. (currentCarry + product.Amount) .. ")", true)
			end
			if playSoundEvent then
				playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
			end
			return true
		else
			warn(player.Name, "is already at max carry capacity")
			if notificationEvent then
				notificationEvent:FireClient(player, "Already at max carry!", false)
			end
			return false
		end

	elseif product.Type == "WheelSpin" then
		-- Give wheel spins to player
		local WheelManager = require(game:GetService("ServerScriptService").GameManager.WheelManager)
		if WheelManager and WheelManager.AddSpins then
			WheelManager:AddSpins(player, product.Amount)
			if notificationEvent then
				notificationEvent:FireClient(player, "Received " .. product.Name .. "!", true)
			end
			if playSoundEvent then
				playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
			end
			return true
		else
			warn("[DevProducts] WheelManager not found or AddSpins missing")
			return false
		end

	elseif product.Type == "Steal" then
		-- Steal is processed differently - via RemoteEvent with victim/slot data
		-- This is just a fallback, actual steal logic is in BaseSlotManager
		warn("[DevProducts] Steal processed via special handler")
		return true

	elseif product.Type == "Pack" then
		-- Give speed boost (permanent addition to Speed attribute)
		local currentSpeed = player:GetAttribute("Speed") or 18
		player:SetAttribute("Speed", currentSpeed + product.SpeedBoost)

		-- Update character walk speed
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				local ServerScriptService = game:GetService("ServerScriptService")
				local GamepassManager = require(ServerScriptService.GameManager.GamepassManager)
				humanoid.WalkSpeed = GamepassManager.GetActualWalkSpeed(player)
			end
		end

	-- Give cash
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local money = leaderstats:FindFirstChild("Money")
		if money then
			money.Value = money.Value + product.Cash
		end
	end

	-- Give the thing to inventory (uses same logic as ThingInventoryManager for everything)
	local ServerScriptService = game:GetService("ServerScriptService")
	local ThingInventoryManager = require(ServerScriptService.Things.ThingInventoryManager)
	local ThingValueManager = require(ServerScriptService.Things.ThingValueManager)

	-- Get correct rate using ThingValueManager
	local rate = ThingValueManager.GetThingValueByName(product.Thing, product.Rarity)

	-- AddToInventory handles: cloning from ServerStorage, removing TimerGui/ProximityPrompt,
	-- applying correct colors, setting up GUI, and creating the Tool
		local success, message = ThingInventoryManager.AddToInventory(
			player,
			product.Thing,
			"", -- No mutation
			product.Rarity,
			rate, -- Correct rate from ThingValueManager
			{}, -- Empty guiData - ThingInventoryManager will apply correct rarity colors
			0 -- No upgrade level
		)

		if not success then
			warn("[DevProducts] Failed to give", product.Thing, "to", player.Name, "-", message)
			-- Still continue - don't fail the whole purchase just because inventory is full
		end

		-- Mark pack as owned (for client-side button state)
		local packAttributeName = "Owns" .. product.Name:gsub(" ", "") -- "OwnsProPack" or "OwnsOPPack"
		player:SetAttribute(packAttributeName, true)

		-- Save ownership to DataStore (for UI persistence only)
		local SaveManager = require(ServerScriptService.GameManager.SaveManager)
		local data = SaveManager:GetPlayerData(player)
		if data then
			if not data.OwnedPacks then
				data.OwnedPacks = {}
			end
			data.OwnedPacks[packAttributeName] = true
			SaveManager:SaveData(player, data)
		end

		-- Send notification
		if notificationEvent then
			notificationEvent:FireClient(
				player,
				product.Name .. " activated! +" .. product.SpeedBoost .. " Speed, $" .. product.Cash .. ", and " .. product.Thing .. "!",
				true
			)
		end

		if playSoundEvent then
			playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
		end

		return true

	elseif product.Type == "GodspeedSpawn" then
		-- Spawn Godspeed tsunami wave
		local ServerScriptService = game:GetService("ServerScriptService")
		local GodspeedSpawner = require(ServerScriptService.GameManager.GodspeedSpawner)

		local success = GodspeedSpawner.SpawnGodspeedWave(player)

		if success then
			if notificationEvent then
				notificationEvent:FireClient(player, "🌊 Godspeed Tsunami spawned!", true)
			end
			if playSoundEvent then
				playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
			end
			return true
		else
			warn("[DevProducts] Failed to spawn Godspeed wave for", player.Name)
			return false
		end

	elseif product.Type == "Thing" then
		-- Give regular Thing to inventory (no mutation)
		local ServerScriptService = game:GetService("ServerScriptService")
		local ThingInventoryManager = require(ServerScriptService.Things.ThingInventoryManager)
		local ThingValueManager = require(ServerScriptService.Things.ThingValueManager)
		local playSoundEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("PlaySoundEvent")

		-- Get correct rate using ThingValueManager
		local rate = ThingValueManager.GetThingValueByName(product.Thing, product.Rarity)

		-- AddToInventory handles: cloning from ServerStorage, removing TimerGui/ProximityPrompt,
		-- applying rarity colors, setting up GUI, and creating the Tool
		local success, message = ThingInventoryManager.AddToInventory(
			player,
			product.Thing,
			product.Mutation, -- "" (None)
			product.Rarity,
			rate,
			{}, -- Empty guiData - ThingInventoryManager will apply rarity colors
			0 -- No upgrade level
		)

		if success then
			if notificationEvent then
				notificationEvent:FireClient(player, product.Name .. " added to inventory!", true)
			end
			if playSoundEvent then
				playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
			end
			return true
		else
			warn("[DevProducts] Failed to give", product.Name, "to", player.Name, "-", message)
			if notificationEvent then
				notificationEvent:FireClient(player, "Failed: " .. (message or "Unknown error"), false)
			end
			return false
		end

	elseif product.Type == "SkipRebirth" then
		-- Skip rebirth requirements and rebirth immediately
		local forceRebirthBindable = remoteEventsFolder and remoteEventsFolder:FindFirstChild("ForceRebirthBindable")
		if forceRebirthBindable then
			forceRebirthBindable:Fire(player)
			return true
		else
			warn("[DevProducts] ForceRebirthBindable not found")
			if notificationEvent then
				notificationEvent:FireClient(player, "Rebirth system unavailable", false)
			end
			return false
		end

	elseif product.Type == "StopTsunamis" then
		-- Stop tsunamis from spawning for 30 seconds
		local stopTsunamisBindable = remoteEventsFolder and remoteEventsFolder:FindFirstChild("StopTsunamisBindable")
		if stopTsunamisBindable then
			stopTsunamisBindable:Fire(player, product.Duration)
			if notificationEvent then
				notificationEvent:FireClient(player, "🌊 Tsunamis stopped for " .. product.Duration .. " seconds!", true)
			end
			if playSoundEvent then
				playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
			end
			return true
		else
			warn("[DevProducts] StopTsunamisBindable not found")
			if notificationEvent then
				notificationEvent:FireClient(player, "Wave system unavailable", false)
			end
			return false
		end

	elseif product.Type == "Boost2xSpeed" then
		-- Grant 10-minute 2x Speed boost
		local hasSpeed2x = player:GetAttribute("HasSpeed2x")

		-- Don't allow purchase if they already have speed gamepass
		if hasSpeed2x then
			if notificationEvent then
				notificationEvent:FireClient(player, "You already have permanent 2x Speed!", false)
			end
			return false
		end

		local endTime = os.time() + product.Duration
		player:SetAttribute("Boost2xSpeedEndTime", endTime)

		-- Immediately update character walk speed
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				local ServerScriptService = game:GetService("ServerScriptService")
				local GamepassManager = require(ServerScriptService.GameManager.GamepassManager)
				humanoid.WalkSpeed = GamepassManager.GetActualWalkSpeed(player)
			end
		end
		
		if notificationEvent then
			notificationEvent:FireClient(player, "⚡ 2x Speed activated for 10 minutes!", true)
		end
		local playSoundEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("PlaySoundEvent")
		if playSoundEvent then
			playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
		end
		return true

	elseif product.Type == "Boost2xMoney" then
		-- Grant 10-minute 2x Money boost
		local endTime = os.time() + product.Duration
		player:SetAttribute("Boost2xMoneyEndTime", endTime)
		
		-- Immediately update RebirthMultiplier to show doubled value
		local ServerScriptService = game:GetService("ServerScriptService")
		local GamepassManager = require(ServerScriptService.GameManager.GamepassManager)
		local newMultiplier = GamepassManager.GetMoneyMultiplier(player)
		player:SetAttribute("RebirthMultiplier", newMultiplier)
		
		if notificationEvent then
			notificationEvent:FireClient(player, "💰 2x Money activated for 10 minutes!", true)
		end
		local playSoundEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("PlaySoundEvent")
		if playSoundEvent then
			playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
		end
		return true
	end

	warn("Failed to process purchase for", player.Name)
	return false
end

return DevProducts
