-- Carry Shop Server Script
-- Place in ServerScriptService/GameManager/Shops

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local MAX_CARRY = 10
local MIN_CARRY = 1
local BASE_COST = 500000 -- $500k for first upgrade (1->2)
local COST_MULTIPLIER = 85 -- Aggressive scaling: 5->6 costs ~26T

-- Create RemoteEvents folder if it doesn't exist
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
	remoteEventsFolder = Instance.new("Folder")
	remoteEventsFolder.Name = "RemoteEvents"
	remoteEventsFolder.Parent = ReplicatedStorage
end

-- Create RemoteEvent for carry purchases
local carryPurchaseEvent = remoteEventsFolder:FindFirstChild("CarryPurchaseEvent")
if not carryPurchaseEvent then
	carryPurchaseEvent = Instance.new("RemoteEvent")
	carryPurchaseEvent.Name = "CarryPurchaseEvent"
	carryPurchaseEvent.Parent = remoteEventsFolder
end

-- Calculate cost for next carry level
local function getCarryCost(currentCarry)
	if currentCarry >= MAX_CARRY then
		return nil -- Already at max
	end
	
	-- Cost formula: BASE_COST * (MULTIPLIER ^ (carry - MIN_CARRY))
	local carryLevel = currentCarry - MIN_CARRY + 1
	local cost = math.floor(BASE_COST * (COST_MULTIPLIER ^ (carryLevel - 1)))
	
	return cost
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

-- Handle carry purchase requests
carryPurchaseEvent.OnServerEvent:Connect(function(player, purchaseType)
	-- Validate purchase type
	if purchaseType ~= "Money" and purchaseType ~= "Robux" then
		warn("Invalid purchase type from", player.Name, ":", purchaseType)
		return
	end
	
	-- Get player's current carry capacity
	local currentCarry = player:GetAttribute("CarryCapacity") or MIN_CARRY
	
	-- Check if already at max carry
	if currentCarry >= MAX_CARRY then
		warn(player.Name, "is already at max carry capacity")
		-- Send error notification
		local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
		if notificationEvent then
			notificationEvent:FireClient(player, "Already at max carry!", false)
		end
		return
	end
	
	-- Calculate cost
	local cost = getCarryCost(currentCarry)
	if not cost then
		warn("Could not calculate carry cost for", player.Name)
		return
	end
	
	-- Only check money if purchasing with money (Robux purchases handled by DevProducts)
	if purchaseType == "Money" then
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
			warn(player.Name, "doesn't have enough money. Need:", formatNumber(cost), "Has:", formatNumber(money.Value))
			-- Send error notification
			local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
			if notificationEvent then
				notificationEvent:FireClient(player, "Not enough money!", false)
			end
			return
		end
		
		-- Deduct money
		print("[CarryShop:117] Subtracting cost:", cost, "| Current:", money.Value, "| New:", money.Value - cost)
		money.Value = money.Value - cost
	end
	
	-- Increase carry capacity (this function is also called by DevProducts for Robux purchases)
	local newCarry = currentCarry + 1
	player:SetAttribute("CarryCapacity", newCarry)
	
	-- Send success notification
	local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
	if notificationEvent then
		if purchaseType == "Money" then
			notificationEvent:FireClient(player, "Carry upgraded! (" .. newCarry .. ")", true)
		else
			notificationEvent:FireClient(player, "Carry upgraded with Robux! (" .. newCarry .. ")", true)
		end
	end
end)

-- Function to get cost for UI updates (can be called by other scripts)
local CarryShop = {}

function CarryShop:GetCost(player)
	local currentCarry = player:GetAttribute("CarryCapacity") or MIN_CARRY
	return getCarryCost(currentCarry)
end

function CarryShop:GetMaxCarry()
	return MAX_CARRY
end

return CarryShop
