-- Save Manager Script
-- Place this in GameManager folder

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- Configuration
local DATASTORE_NAME = "PlayerData_V1" -- Change version number if you need to reset data
local AUTOSAVE_INTERVAL = 180 -- Auto-save every 3 minutes

-- Get DataStore
local PlayerDataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

-- Module
local SaveManager = {}

-- Default player data
local function getDefaultData()
	return {
		Money = 0,

		-- Player stats
		Speed = 18,           -- Starting speed
		Rebirths = 0,         -- Number of rebirths
		RebirthMultiplier = 1, -- Money multiplier from rebirths

		-- Shop upgrades (for future implementation)
		SpeedLevel = 1,       -- Speed shop upgrade level
		CarryCapacity = 1,    -- Carry shop upgrade level

		-- Base system
		BaseNumber = nil,     -- Which base (1-5) the player owns
		BaseUpgradeLevel = 0, -- Base upgrade level (0-20)

		-- Inventory system (things owned but not placed)
		OwnedItems = {},      -- Table storing items in inventory: {Name, Mutation, Rarity, Rate, UpgradeLevel, Timestamp, GuiData}

		-- Placed things system (things placed on slots)
		PlacedThings = {},    -- Table storing placed items: {[slotNumber] = {ThingName, Mutation, UpgradeLevel}}

		-- Pack ownership (for UI only, doesn't block purchases)
		OwnedPacks = {},      -- Table storing owned packs: {OwnsProPack = true, OwnsOPPack = true}

		-- Group reward
		LastGroupClaimTime = 0, -- Timestamp of last claim (0 = never claimed)
		
		-- Wheel spins
		WheelSpins = 0        -- Number of available wheel spins
	}
end

-- Load player data
function SaveManager:LoadData(player)
	local success, data
	local userId = "Player_" .. player.UserId

	-- Try to load data with retries (faster retry delay)
	for i = 1, 3 do
		success, data = pcall(function()
			return PlayerDataStore:GetAsync(userId)
		end)

		if success then
			break
		else
			warn("Failed to load data for", player.Name, "- Attempt", i, "/3")
			if i < 3 then
				task.wait(0.1) -- Much shorter delay (was 1 second)
			end
		end
	end

	-- If data doesn't exist or failed to load, use default
	if not success or not data then
		return getDefaultData()
	end

	-- Merge with default data to ensure all fields exist (for backwards compatibility)
	local defaultData = getDefaultData()
	for key, value in pairs(defaultData) do
		if data[key] == nil then
			data[key] = value
		end
	end

	return data
end

-- Save player data
function SaveManager:SaveData(player, data)
	-- Validate player object first
	if not player or not player.UserId then
		warn("[SaveData] Invalid player object")
		return false
	end

	local success
	local userId = "Player_" .. player.UserId

	-- Try to save data with retries (faster retry delay)
	for i = 1, 3 do
		success = pcall(function()
			PlayerDataStore:SetAsync(userId, data)
		end)

		if success then
			return true
		else
			warn("Failed to save data for", player.Name or "Unknown", "- Attempt", i, "/3")
			if i < 3 then
				task.wait(0.1) -- Much shorter delay (was 1 second)
			end
		end
	end

	return false
end

-- Get player data from leaderstats
function SaveManager:GetPlayerData(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	local money = leaderstats:FindFirstChild("Money")
	if not money then
		return nil
	end

	-- Get inventory from ThingInventoryManager if available (no require to avoid circular dependency)
	local ownedItems = {}
	local ThingInventory = game:GetService("ServerScriptService"):FindFirstChild("Things")
	if ThingInventory then
		local ThingInventoryModule = ThingInventory:FindFirstChild("ThingInventoryManager")
		if ThingInventoryModule and ThingInventoryModule:IsA("ModuleScript") then
			-- Access the already-loaded module (don't require again to prevent circular dependency)
			local success, ThingInventoryManager = pcall(function()
				return require(ThingInventoryModule)
			end)
			if success and ThingInventoryManager and ThingInventoryManager.GetInventory then
				ownedItems = ThingInventoryManager.GetInventory(player)
			end
		end
	end

	-- Get additional data from player attributes
	-- PlacedThings built fresh from slot attributes
	local placedThings = {}

	-- Get fresh PlacedThings from BaseSlotManager (reads from slot attributes, NOT DataStore)
	local ThingsFolder = game:GetService("ServerScriptService"):FindFirstChild("Things")
	if ThingsFolder then
		local BaseSlotModule = ThingsFolder:FindFirstChild("BaseSlotManager")
		if BaseSlotModule and BaseSlotModule:IsA("ModuleScript") then
			local success, BaseSlotManager = pcall(function()
				return require(BaseSlotModule)
			end)
			if success and BaseSlotManager and BaseSlotManager.GetPlacedThingsData then
				placedThings = BaseSlotManager.GetPlacedThingsData(player)
			end
		end
	end

	-- Get OwnedPacks from player attributes (don't load from DataStore to avoid race conditions)
	local ownedPacks = {}
	for _, packName in pairs({"OwnsProPack", "OwnsOPPack"}) do
		if player:GetAttribute(packName) then
			ownedPacks[packName] = true
		end
	end

	return {
		Money = money.Value,
		Speed = player:GetAttribute("Speed") or 18,
		Rebirths = player:GetAttribute("Rebirths") or 0,
		SpeedLevel = player:GetAttribute("SpeedLevel") or 1,
		CarryCapacity = player:GetAttribute("CarryCapacity") or 1,
		BaseNumber = player:GetAttribute("BaseNumber"),
		BaseUpgradeLevel = player:GetAttribute("BaseUpgradeLevel") or 0,
		OwnedItems = ownedItems,
		PlacedThings = placedThings,
		OwnedPacks = ownedPacks,
		WheelSpins = player:GetAttribute("WheelSpins") or 0
	}
end

-- Auto-save for all players
function SaveManager:AutoSaveAll()
	for _, player in pairs(Players:GetPlayers()) do
		local data = self:GetPlayerData(player)
		if data then
			self:SaveData(player, data)
		end
	end
end

-- Start auto-save loop
function SaveManager:StartAutoSave()
	spawn(function()
		while true do
			wait(AUTOSAVE_INTERVAL)
			self:AutoSaveAll()
		end
	end)
end

-- Save player data when they leave, THEN cleanup
Players.PlayerRemoving:Connect(function(player)
	print("[PlayerLeave] Saving data for", player.Name)

	-- Wrap everything in pcall to prevent any errors from blocking other players
	local success, errorMsg = pcall(function()
		-- Get and save all data BEFORE cleanup destroys slots
		local data = SaveManager:GetPlayerData(player)
		if data then
			-- Show count
			local count = 0
			if data.PlacedThings then
				for _ in pairs(data.PlacedThings) do count = count + 1 end
			end
			print("[PlayerLeave] Found", count, "placed things to save")

			local saveSuccess = SaveManager:SaveData(player, data)
			if saveSuccess then
				print("[PlayerLeave] Data saved for", player.Name)
			else
				warn("[PlayerLeave] FAILED TO SAVE DATA FOR", player.Name)
			end
		else
			warn("[PlayerLeave] Failed to get player data for", player.Name)
		end

		-- NOW cleanup base (destroy physical things) AFTER save completes
		local BaseManager = require(script.Parent.BaseManager)
		if BaseManager and BaseManager.CleanupPlayer then
			BaseManager:CleanupPlayer(player)
			print("[PlayerLeave] Cleanup complete for", player.Name)
		else
			warn("[PlayerLeave] BaseManager.CleanupPlayer not found!")
		end

		-- FALLBACK: Aggressively destroy any remaining items tagged with this player
		-- This is a safety net in case BaseManager cleanup fails
		local workspace = game:GetService("Workspace")
		local playerId = player.UserId
		local destroyedCount = 0

		-- Check Map > Things folder for any items still tagged with this player
		local map = workspace:FindFirstChild("Map")
		if map then
			local thingsFolder = map:FindFirstChild("Things")
			if thingsFolder then
				for _, item in pairs(thingsFolder:GetChildren()) do
					if item:GetAttribute("OwnerId") == playerId then
						item:Destroy()
						destroyedCount = destroyedCount + 1
					end
				end
				if destroyedCount > 0 then
					warn("[PlayerLeave] FALLBACK: Destroyed", destroyedCount, "leftover items for", player.Name)
				end
			end
		end

		-- Also clear base slot attributes to prevent slot reuse issues
		local baseNumber = player:GetAttribute("BaseNumber")
		if baseNumber then
			local bases = workspace:FindFirstChild("Bases")
			if bases then
				local base = bases:FindFirstChild("Base" .. baseNumber)
				if base then
					-- Clear all slot attributes
					for i = 1, 50 do
						local slot = base:FindFirstChild("Slot" .. i)
						if slot then
							slot:SetAttribute("OccupiedBy", nil)
							slot:SetAttribute("ThingName", nil)
							slot:SetAttribute("ThingMutation", nil)
							slot:SetAttribute("ThingUpgradeLevel", nil)
						end
					end
					print("[PlayerLeave] Cleared all slot attributes for Base", baseNumber)
				end
			end
		end
	end)

	if not success then
		warn("[PlayerLeave] Error during save/cleanup for", player.Name, ":", errorMsg)
	end
end)

-- Save all players on shutdown
game:BindToClose(function()
	print("Server shutting down - saving all player data...")

	-- Save all players synchronously (one at a time) to ensure completion
	for _, player in pairs(Players:GetPlayers()) do
		pcall(function()
			local data = SaveManager:GetPlayerData(player)
			if data then
				local success = SaveManager:SaveData(player, data)
				if success then
					print("[Shutdown] Saved", player.Name)
				else
					warn("[Shutdown] Failed to save data for", player.Name)
				end
			else
				warn("[Shutdown] Failed to get data for", player.Name)
			end
		end)
	end

	print("All player data saved!")
	task.wait(2) -- Give DataStore time to process
end)

return SaveManager
