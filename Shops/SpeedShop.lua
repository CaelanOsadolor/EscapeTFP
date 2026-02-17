-- Speed Shop Server Script
-- Place in ServerScriptService/GameManager/Shops

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local MAX_SPEED = 2000
local MIN_SPEED = 18
local BASE_COST = 250 -- Cost for first upgrade (18->19)
local COST_MULTIPLIER = 1.15 -- Cost increases by 15% per speed point

-- Create RemoteEvents folder if it doesn't exist
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
	remoteEventsFolder = Instance.new("Folder")
	remoteEventsFolder.Name = "RemoteEvents"
	remoteEventsFolder.Parent = ReplicatedStorage
end

-- Create RemoteEvent for speed purchases
local speedPurchaseEvent = remoteEventsFolder:FindFirstChild("SpeedPurchaseEvent")
if not speedPurchaseEvent then
	speedPurchaseEvent = Instance.new("RemoteEvent")
	speedPurchaseEvent.Name = "SpeedPurchaseEvent"
	speedPurchaseEvent.Parent = remoteEventsFolder
end

-- Calculate cost for a specific speed level
local function getSpeedCost(currentSpeed, speedIncrease)
	local totalCost = 0
	
	for i = 1, speedIncrease do
		local targetSpeed = currentSpeed + i
		if targetSpeed > MAX_SPEED then
			break
		end
		
		-- Cost formula: BASE_COST * (MULTIPLIER ^ (speed - MIN_SPEED))
		local speedLevel = targetSpeed - MIN_SPEED
		local cost = math.floor(BASE_COST * (COST_MULTIPLIER ^ speedLevel))
		totalCost = totalCost + cost
	end
	
	return totalCost
end

-- Format number with extended suffixes
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

-- Handle speed purchase requests
speedPurchaseEvent.OnServerEvent:Connect(function(player, speedIncrease)
	-- Validate speed increase amount
	if speedIncrease ~= 1 and speedIncrease ~= 5 and speedIncrease ~= 10 then
		warn("Invalid speed increase amount from", player.Name, ":", speedIncrease)
		return
	end
	
	-- Get player's current speed
	local currentSpeed = player:GetAttribute("Speed") or MIN_SPEED
	
	-- Check if already at max speed
	if currentSpeed >= MAX_SPEED then
		warn(player.Name, "is already at max speed")
		-- Send error notification
		local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
		if notificationEvent then
			notificationEvent:FireClient(player, "Already at max speed!", false)
		end
		return
	end
	
	-- Calculate how much speed can actually be purchased
	local actualIncrease = math.min(speedIncrease, MAX_SPEED - currentSpeed)
	
	-- Calculate cost
	local cost = getSpeedCost(currentSpeed, actualIncrease)
	
	-- Get player's money
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		warn("No leaderstats found for", player.Name)
		return
	end
	
	local money = leaderstats:FindFirstChild("Money")
	if not money then
		warn("No Money value found for", player.Name)
		return
	end
	
	-- Check if player has enough money
	if money.Value < cost then
		warn(player.Name, "doesn't have enough money. Need:", formatNumber(cost), "Has:", formatNumber(money.Value))		-- Send error notification
		local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
		if notificationEvent then
			notificationEvent:FireClient(player, "Not enough money!", false)
		end		return
	end
	
	-- Deduct money
	print("[SpeedShop:118] Subtracting cost:", cost, "| Current:", money.Value, "| New:", money.Value - cost)
	money.Value = money.Value - cost
	
	-- Increase speed
	local newSpeed = currentSpeed + actualIncrease
	player:SetAttribute("Speed", newSpeed)
	
	-- Update WalkSpeed if character exists
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = newSpeed
		end
	end
	
	-- Send success notification
	local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
	if notificationEvent then
		notificationEvent:FireClient(player, "Speed upgraded! +" .. actualIncrease .. " (" .. newSpeed .. ")", true)
	end
end)

-- Function to get cost for UI updates (can be called by other scripts)
local SpeedShop = {}

function SpeedShop:GetCost(player, speedIncrease)
	local currentSpeed = player:GetAttribute("Speed") or MIN_SPEED
	return getSpeedCost(currentSpeed, speedIncrease)
end

function SpeedShop:GetMaxSpeed()
	return MAX_SPEED
end

return SpeedShop
