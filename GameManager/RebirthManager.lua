-- Rebirth Manager Script
-- Place in ServerScriptService/GameManager

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Get GamepassManager
local GamepassManager = require(ServerScriptService.GameManager.GamepassManager)

-- Configuration
local BASE_SPEED_REQUIREMENT = 50 -- Speed needed for first rebirth
local SPEED_INCREMENT = 25 -- Additional speed per rebirth (50, 75, 100, 125, 150...)
local MAX_SPEED = 2000 -- Maximum speed
local MAX_REBIRTHS = 10 -- Maximum number of rebirths (at rebirth 10: speed 275)
local MONEY_MULTIPLIER_PER_REBIRTH = 0.5 -- Each rebirth adds 0.5x (1.5x, 2x, 2.5x, etc.)
local MIN_SPEED = 18 -- Reset speed
local MIN_CARRY = 1 -- Reset carry capacity

-- Get RemoteEvents
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local rebirthEvent = remoteEventsFolder:WaitForChild("RebirthEvent")
local rebirthInfoFunction = remoteEventsFolder:WaitForChild("RebirthInfoFunction")
local forceRebirthBindable = remoteEventsFolder:WaitForChild("ForceRebirthBindable")
local notificationEvent = remoteEventsFolder:WaitForChild("Notification")
local playSoundEvent = remoteEventsFolder:WaitForChild("PlaySoundEvent")

-- Calculate speed requirement for next rebirth
local function getSpeedRequirement(currentRebirths)
	return BASE_SPEED_REQUIREMENT + (currentRebirths * SPEED_INCREMENT)
end

-- Calculate money multiplier based on rebirths
local function getMoneyMultiplier(rebirths)
	return 1 + (rebirths * MONEY_MULTIPLIER_PER_REBIRTH)
end

-- Check if player can rebirth
local function canRebirth(player)
	local currentSpeed = player:GetAttribute("Speed") or MIN_SPEED
	local currentRebirths = player:GetAttribute("Rebirths") or 0

	-- Check if already at max rebirths
	if currentRebirths >= MAX_REBIRTHS then
		return false, MAX_SPEED, "Max rebirths reached!"
	end

	local requiredSpeed = getSpeedRequirement(currentRebirths)

	return currentSpeed >= requiredSpeed, requiredSpeed
end

-- Perform rebirth
local function doRebirth(player)
	local canRebirthNow, requiredSpeed, errorMessage = canRebirth(player)

	print("[SERVER] DoRebirth called for", player.Name, "- Can rebirth:", canRebirthNow, "Required speed:", requiredSpeed)

	if not canRebirthNow then
		if errorMessage then
			warn(player.Name, errorMessage)
			return false, errorMessage
		else
			warn(player.Name, "doesn't have enough speed to rebirth. Required:", requiredSpeed)
			return false, "Not enough speed! Need: " .. requiredSpeed
		end
	end

	-- Get current values
	local currentRebirths = player:GetAttribute("Rebirths") or 0

	-- Update rebirths leaderstat
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rebirthsLeaderstat = leaderstats:FindFirstChild("Rebirths")
		if rebirthsLeaderstat then
			rebirthsLeaderstat.Value = currentRebirths + 1
		end
	end

	-- Update attributes - only reset speed
	local newRebirths = currentRebirths + 1
	player:SetAttribute("Speed", MIN_SPEED)
	player:SetAttribute("Rebirths", newRebirths)
	-- Use GamepassManager to calculate correct multiplier (handles 2x Money gamepass)
	player:SetAttribute("RebirthMultiplier", GamepassManager.GetMoneyMultiplier(player))

	-- Reset character's WalkSpeed (use GamepassManager for 2x Speed gamepass)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = GamepassManager.GetActualWalkSpeed(player)
		end
	end

	-- Send success notification
	if notificationEvent then
		local multiplier = GamepassManager.GetMoneyMultiplier(player)
		notificationEvent:FireClient(player, "Rebirth! Now at " .. multiplier .. "x money multiplier!", true)
	end

	return true, "Rebirth successful!"
end

-- Force rebirth (skip speed requirements) - for Robux purchase
local function forceRebirth(player)
	local currentRebirths = player:GetAttribute("Rebirths") or 0

	-- Check if already at max rebirths
	if currentRebirths >= MAX_REBIRTHS then
		return false, "Max rebirths reached!"
	end

	-- Update rebirths leaderstat
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rebirthsLeaderstat = leaderstats:FindFirstChild("Rebirths")
		if rebirthsLeaderstat then
			rebirthsLeaderstat.Value = currentRebirths + 1
		end
	end

	-- Update attributes - only reset speed
	local newRebirths = currentRebirths + 1
	player:SetAttribute("Speed", MIN_SPEED)
	player:SetAttribute("Rebirths", newRebirths)
	-- Use GamepassManager to calculate correct multiplier (handles 2x Money gamepass)
	player:SetAttribute("RebirthMultiplier", GamepassManager.GetMoneyMultiplier(player))

	-- Reset character's WalkSpeed (use GamepassManager for 2x Speed gamepass)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = GamepassManager.GetActualWalkSpeed(player)
		end
	end

	local multiplier = GamepassManager.GetMoneyMultiplier(player)
	return true, "Now at " .. multiplier .. "x money multiplier!"
end

-- Handle rebirth requests
rebirthEvent.OnServerEvent:Connect(function(player)
	print("[SERVER] Rebirth event received from", player.Name)
	local success, message = doRebirth(player)

	if not success then
		print("[SERVER] Rebirth failed for", player.Name, "-", message)
		-- Send error notification
		if notificationEvent then
			notificationEvent:FireClient(player, message, false)
		end
	else
		print("[SERVER] Rebirth successful for", player.Name)
	end
end)

-- Handle force rebirth requests from server (DevProducts)
forceRebirthBindable.Event:Connect(function(player)
	print("[SERVER] Force rebirth event received from server for", player.Name)
	local success, message = forceRebirth(player)

	if not success then
		print("[SERVER] Force rebirth failed for", player.Name, "-", message)
		-- Send error notification
		if notificationEvent then
			notificationEvent:FireClient(player, message, false)
		end
	else
		print("[SERVER] Force rebirth successful for", player.Name)
		-- Send success notification
		if notificationEvent then
			notificationEvent:FireClient(player, "Rebirth purchased! " .. message, true)
		end
		-- Play success sound
		if playSoundEvent then
			playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
		end
	end
end)

-- Handle info requests from UI
rebirthInfoFunction.OnServerInvoke = function(player)
	local currentRebirths = player:GetAttribute("Rebirths") or 0
	local currentSpeed = player:GetAttribute("Speed") or MIN_SPEED
	local requiredSpeed = getSpeedRequirement(currentRebirths)
	local nextMultiplier = getMoneyMultiplier(currentRebirths + 1)

	return {
		CurrentRebirths = currentRebirths,
		CurrentSpeed = currentSpeed,
		RequiredSpeed = requiredSpeed,
		CanRebirth = currentSpeed >= requiredSpeed,
		NextMultiplier = nextMultiplier
	}
end

print("Rebirth Manager initialized!")