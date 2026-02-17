-- SellingManager.lua
-- Server-side selling system that handles item sales and gives money to players
-- Place in: ServerScriptService/GameManager/

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SellingManager = {}

-- Get required modules
local ThingInventoryManager = require(ServerScriptService.Things.ThingInventoryManager)
local SaveManager = require(ServerScriptService.GameManager.SaveManager)
local ThingValueManager = require(ServerScriptService.Things.ThingValueManager)

-- Calculate selling price (Rate × 10)
local function CalculateSellingPrice(rate)
	return math.floor(rate * 10)
end

-- Give money to player
local function GiveMoney(player, amount)
	-- Always add to leaderstat value, not overwrite
	local leaderstats = player:FindFirstChild("leaderstats")
	local currentMoney = 0
	if leaderstats then
		local moneyValue = leaderstats:FindFirstChild("Money")
		if moneyValue then
			currentMoney = moneyValue.Value
			moneyValue.Value = currentMoney + amount
		end
	end
	-- Also update attribute for consistency
	player:SetAttribute("Money", currentMoney + amount)
end

-- Sell a single item by inventory index
function SellingManager.SellItem(player, itemIndex)
	local inventory = ThingInventoryManager.GetInventory(player)
	if not inventory or not inventory[itemIndex] then
		return false, 0
	end
	
	local item = inventory[itemIndex]
	local sellingPrice = CalculateSellingPrice(item.Rate or 0)
	
	-- Remove from inventory
	local success = ThingInventoryManager.RemoveFromInventory(player, itemIndex)
	if not success then
		return false, 0
	end
	
	-- Remove the Tool from Backpack/Character
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("InventoryIndex") == itemIndex then
				tool:Destroy()
				break
			end
		end
	end
	
	if character then
		for _, tool in pairs(character:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("InventoryIndex") == itemIndex then
				tool:Destroy()
				break
			end
		end
	end
	
	-- Give money
	GiveMoney(player, sellingPrice)
	
	-- Save
	local data = SaveManager:GetPlayerData(player)
	if data then
		data.OwnedItems = ThingInventoryManager.GetInventory(player)
		SaveManager:SaveData(player, data)
	end
	
	return true, sellingPrice
end

-- Sell all items in inventory
function SellingManager.SellAllItems(player)
	local inventory = ThingInventoryManager.GetInventory(player)
	if not inventory or #inventory == 0 then
		return false, 0, 0
	end
	
	local totalMoney = 0
	local itemsSold = 0
	
	-- Calculate total value
	for i = #inventory, 1, -1 do
		local item = inventory[i]
		totalMoney = totalMoney + CalculateSellingPrice(item.Rate or 0)
		itemsSold = itemsSold + 1
	end
	
	-- Clear inventory
	for i = #inventory, 1, -1 do
		ThingInventoryManager.RemoveFromInventory(player, i)
	end
	
	-- Remove all Tools from Backpack/Character
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("InventoryIndex") then
				tool:Destroy()
			end
		end
	end
	
	if character then
		for _, tool in pairs(character:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("InventoryIndex") then
				tool:Destroy()
			end
		end
	end
	
	-- Give money
	GiveMoney(player, totalMoney)
	
	-- Save
	local data = SaveManager:GetPlayerData(player)
	if data then
		data.OwnedItems = ThingInventoryManager.GetInventory(player)
		SaveManager:SaveData(player, data)
	end
	
	return true, totalMoney, itemsSold
end

-- Get item value without selling
function SellingManager.GetItemValue(player, itemIndex)
	local inventory = ThingInventoryManager.GetInventory(player)
	if not inventory or not inventory[itemIndex] then
		return nil, nil
	end
	
	local item = inventory[itemIndex]
	local sellingPrice = CalculateSellingPrice(item.Rate or 0)
	
	-- Build display name
	local displayName = item.Name
	if item.Mutation and item.Mutation ~= "" then
		displayName = item.Mutation .. " " .. item.Name
	end
	
	return sellingPrice, displayName
end

-- Initialize remote events
function SellingManager.Init()
	local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
	if not remoteEvents then
		warn("[SellingManager] RemoteEvents folder not found!")
		return
	end
	
	-- Connect to existing RemoteFunctions
	local sellItemEvent = remoteEvents:WaitForChild("SellItem", 10)
	if not sellItemEvent then
		warn("[SellingManager] SellItem RemoteFunction not found!")
		return
	end
	
	sellItemEvent.OnServerInvoke = function(player, itemIndex)
		return SellingManager.SellItem(player, itemIndex)
	end
	
	local sellInventoryEvent = remoteEvents:WaitForChild("SellInventory", 10)
	if not sellInventoryEvent then
		warn("[SellingManager] SellInventory RemoteFunction not found!")
		return
	end
	
	sellInventoryEvent.OnServerInvoke = function(player)
		return SellingManager.SellAllItems(player)
	end
	
	local getItemValueEvent = remoteEvents:WaitForChild("GetItemValue", 10)
	if not getItemValueEvent then
		warn("[SellingManager] GetItemValue RemoteFunction not found!")
		return
	end
	
	getItemValueEvent.OnServerInvoke = function(player, itemIndex)
		return SellingManager.GetItemValue(player, itemIndex)
	end
end

return SellingManager
