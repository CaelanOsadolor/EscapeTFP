-- GamepassManager.lua (Game 3)
-- Handles all gamepass functionality
-- Place in ServerScriptService/GameManager

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")

local GamepassManager = {}

-- Gamepass IDs (Game 3)
local GAMEPASSES = {
	Speed2x = 1713015348,     -- 2x Speed (99 Robux)
	Money2x = 1713015347,     -- 2x Money (99 Robux)
	VIP = 1713083304          -- VIP (79 Robux)
}

-- Check if player owns a gamepass
local function ownsGamepass(player, gamepassId)
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)

	if success then
		return owns
	else
		warn("Failed to check gamepass ownership for", player.Name, "- Gamepass ID:", gamepassId)
		return false
	end
end

-- Setup VIP walls for player
local function setupVIPWalls(player)
	local hasVIP = ownsGamepass(player, GAMEPASSES.VIP)

	print(player.Name, "VIP check:", hasVIP)

	if hasVIP then
		-- Find all VIPWall parts in workspace and make them invisible for VIP players (client-side)
		local vipWalls = Workspace:FindFirstChild("VIPWalls")
		print("VIPWalls folder found:", vipWalls ~= nil)

		if vipWalls then
			-- Create RemoteEvent if it doesn't exist
			local remoteEvents = game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvents")
			if not remoteEvents then
				remoteEvents = Instance.new("Folder")
				remoteEvents.Name = "RemoteEvents"
				remoteEvents.Parent = game:GetService("ReplicatedStorage")
			end

			local vipWallEvent = remoteEvents:FindFirstChild("VIPWallEvent")
			if not vipWallEvent then
				vipWallEvent = Instance.new("RemoteEvent")
				vipWallEvent.Name = "VIPWallEvent"
				vipWallEvent.Parent = remoteEvents
			end

			-- Tell client to hide all VIP walls
			local wallCount = 0
			for _, wall in ipairs(vipWalls:GetDescendants()) do
				if wall:IsA("BasePart") then
					wallCount = wallCount + 1
					vipWallEvent:FireClient(player, wall, true) -- true = make invisible
				end
			end
			print("Sent", wallCount, "VIP wall events to", player.Name)
		end
	end
end

-- Apply speed gamepass
local function applySpeedGamepass(player)
	local hasSpeed2x = ownsGamepass(player, GAMEPASSES.Speed2x)
	player:SetAttribute("HasSpeed2x", hasSpeed2x)

	-- Update character speed if they have the gamepass
	if hasSpeed2x then
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				local baseSpeed = player:GetAttribute("Speed") or 18
				humanoid.WalkSpeed = baseSpeed * 2
			end
		end
	end
end

-- Apply money gamepass
local function applyMoneyGamepass(player)
	local hasMoney2x = ownsGamepass(player, GAMEPASSES.Money2x)
	player:SetAttribute("HasMoney2x", hasMoney2x)

	-- Update rebirth multiplier to use 2x base instead of 1x
	if hasMoney2x then
		local rebirths = player:GetAttribute("Rebirths") or 0
		-- Base is 2x instead of 1x, then add rebirth bonuses
		player:SetAttribute("RebirthMultiplier", 2 + (rebirths * 0.5))
	end
end

-- Initialize gamepasses for a player
function GamepassManager.InitializePlayer(player)
	-- Apply money gamepass
	applyMoneyGamepass(player)

	-- Apply speed gamepass
	applySpeedGamepass(player)

	-- Setup VIP walls
	setupVIPWalls(player)

	-- Update on character spawn
	player.CharacterAdded:Connect(function(character)
		applySpeedGamepass(player)
	end)
end

-- Get speed multiplier text for UI
function GamepassManager.GetSpeedMultiplierText(player)
	local hasSpeed2x = player:GetAttribute("HasSpeed2x")
	local boostEndTime = player:GetAttribute("Boost2xSpeedEndTime")

	-- Check if boost is still active
	local hasBoost = false
	if boostEndTime and os.time() < boostEndTime then
		hasBoost = true
	else
		-- Clear expired boost
		if boostEndTime then
			player:SetAttribute("Boost2xSpeedEndTime", nil)
			-- Update walk speed back to normal
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = GamepassManager.GetActualWalkSpeed(player)
				end
			end
		end
	end

	if hasSpeed2x or hasBoost then
		return " (2x)"
	end
	return ""
end

-- Get actual walk speed (for character)
function GamepassManager.GetActualWalkSpeed(player)
	local baseSpeed = player:GetAttribute("Speed") or 18
	local hasSpeed2x = player:GetAttribute("HasSpeed2x")
	local boostEndTime = player:GetAttribute("Boost2xSpeedEndTime")

	-- Check if boost is still active
	local hasBoost = false
	if boostEndTime and os.time() < boostEndTime then
		hasBoost = true
	end

	-- Don't stack: if they have gamepass, boost does nothing
	if hasSpeed2x then
		return baseSpeed * 2
	elseif hasBoost then
		return baseSpeed * 2
	end

	return baseSpeed
end

-- Get money multiplier
function GamepassManager.GetMoneyMultiplier(player)
	local hasMoney2x = player:GetAttribute("HasMoney2x")
	local rebirths = player:GetAttribute("Rebirths") or 0
	local boostEndTime = player:GetAttribute("Boost2xMoneyEndTime")

	-- Check if boost is still active
	local hasBoost = false
	if boostEndTime and os.time() < boostEndTime then
		hasBoost = true
	else
		-- Clear expired boost and update RebirthMultiplier back to normal
		if boostEndTime then
			player:SetAttribute("Boost2xMoneyEndTime", nil)
			-- Recalculate and update RebirthMultiplier to non-boosted value
			local normalMultiplier
			if hasMoney2x then
				normalMultiplier = 2 + (rebirths * 0.5)
			else
				normalMultiplier = 1 + (rebirths * 0.5)
			end
			player:SetAttribute("RebirthMultiplier", normalMultiplier)
		end
	end

	-- Calculate base multiplier
	local baseMultiplier
	if hasMoney2x then
		-- Base 2x + rebirth bonuses (0.5x per rebirth)
		baseMultiplier = 2 + (rebirths * 0.5)
	else
		-- Base 1x + rebirth bonuses (0.5x per rebirth)
		baseMultiplier = 1 + (rebirths * 0.5)
	end

	-- If boost is active, double whatever the current multiplier is
	if hasBoost then
		return baseMultiplier * 2
	end

	return baseMultiplier
end

-- Handle gamepass purchases (optional - for immediate application)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
	if wasPurchased then
		-- Play success sound and show notification
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		if remoteEventsFolder then
			local playSoundEvent = remoteEventsFolder:FindFirstChild("PlaySoundEvent")
			if playSoundEvent then
				playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
			end

			local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
			if notificationEvent then
				local gamepassName = ""
				if gamepassId == GAMEPASSES.Speed2x then
					gamepassName = "2x Speed"
				elseif gamepassId == GAMEPASSES.Money2x then
					gamepassName = "2x Money"
				elseif gamepassId == GAMEPASSES.VIP then
					gamepassName = "VIP"
				end
				if gamepassName ~= "" then
					notificationEvent:FireClient(player, gamepassName .. " gamepass activated!", true)
				end
			end
		end

		if gamepassId == GAMEPASSES.Speed2x then
			applySpeedGamepass(player)
		elseif gamepassId == GAMEPASSES.Money2x then
			applyMoneyGamepass(player)
		elseif gamepassId == GAMEPASSES.VIP then
			setupVIPWalls(player)
		end
	end
end)

return GamepassManager
