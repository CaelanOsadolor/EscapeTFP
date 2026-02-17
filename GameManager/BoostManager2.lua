-- BoostManager.lua
-- Handles automatic expiration of 10-minute boosts
-- Place in ServerScriptService/GameManager

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BoostManager = {}

-- Check and expire boosts for all players
local function checkBoostExpiration()
	for _, player in ipairs(Players:GetPlayers()) do
		local currentTime = os.time()

		-- Check Speed Boost expiration
		local speedBoostEnd = player:GetAttribute("Boost2xSpeedEndTime")
		if speedBoostEnd and currentTime >= speedBoostEnd then
			player:SetAttribute("Boost2xSpeedEndTime", nil)

			-- Update character walk speed back to normal
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid then
					local GamepassManager = require(script.Parent.GamepassManager)
					humanoid.WalkSpeed = GamepassManager.GetActualWalkSpeed(player)
				end
			end

			-- Notify player
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
			if remoteEventsFolder then
				local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
				if notificationEvent then
					notificationEvent:FireClient(player, "2x Speed boost expired!", false)
				end
			end
		end

		-- Check Money Boost expiration
		local moneyBoostEnd = player:GetAttribute("Boost2xMoneyEndTime")
		if moneyBoostEnd and currentTime >= moneyBoostEnd then
			player:SetAttribute("Boost2xMoneyEndTime", nil)

			-- Restore to base multiplier (stored when boost was applied)
			local baseMultiplier = player:GetAttribute("BaseMoneyMultiplier")
			if baseMultiplier then
				player:SetAttribute("RebirthMultiplier", baseMultiplier)
				player:SetAttribute("BaseMoneyMultiplier", nil)
			else
				-- Fallback: recalculate from GamepassManager
				local GamepassManager = require(script.Parent.GamepassManager)
				local normalMultiplier = GamepassManager.GetMoneyMultiplier(player)
				player:SetAttribute("RebirthMultiplier", normalMultiplier)
			end

			-- Notify player
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
			if remoteEventsFolder then
				local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
				if notificationEvent then
					notificationEvent:FireClient(player, "2x Money boost expired!", false)
				end
			end
		end
	end
end

-- Start boost expiration checker (runs every 1 second)
function BoostManager.Initialize()
	task.spawn(function()
		while true do
			task.wait(1)
			checkBoostExpiration()
		end
	end)

	print("[BoostManager] Initialized - checking boost expirations every 1 second")
end

-- Apply money boost to player
function BoostManager.ApplyMoneyBoost(player, multiplier, duration)
	-- Store base multiplier if not already stored (first boost application)
	if not player:GetAttribute("BaseMoneyMultiplier") then
		local currentMultiplier = player:GetAttribute("RebirthMultiplier") or 1
		player:SetAttribute("BaseMoneyMultiplier", currentMultiplier)
	end
	
	-- Set boost end time
	local endTime = os.time() + duration
	player:SetAttribute("Boost2xMoneyEndTime", endTime)
	
	-- Apply the multiplier from base (prevents stacking issues)
	local baseMultiplier = player:GetAttribute("BaseMoneyMultiplier")
	player:SetAttribute("RebirthMultiplier", baseMultiplier * multiplier)
	
	-- Notify player
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEventsFolder then
		local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
		if notificationEvent then
			local minutes = math.floor(duration / 60)
			notificationEvent:FireClient(player, multiplier .. "x Money boost activated for " .. minutes .. " minutes!", true)
		end
	end
	
	print(player.Name, "received", multiplier .. "x money boost for", duration, "seconds")
	return true
end

-- Apply speed boost to player
function BoostManager.ApplySpeedBoost(player, multiplier, duration)
	-- Set boost end time
	local endTime = os.time() + duration
	player:SetAttribute("Boost2xSpeedEndTime", endTime)
	
	-- Apply the speed boost immediately
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			local GamepassManager = require(script.Parent.GamepassManager)
			humanoid.WalkSpeed = GamepassManager.GetActualWalkSpeed(player) * multiplier
		end
	end
	
	-- Notify player
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEventsFolder then
		local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
		if notificationEvent then
			local minutes = math.floor(duration / 60)
			notificationEvent:FireClient(player, multiplier .. "x Speed boost activated for " .. minutes .. " minutes!", true)
		end
	end
	
	print(player.Name, "received", multiplier .. "x speed boost for", duration, "seconds")
	return true
end

return BoostManager
