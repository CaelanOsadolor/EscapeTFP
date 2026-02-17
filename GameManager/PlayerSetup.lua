-- Player Setup Script
-- Place this in GameManager folder
--!nolint

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Require SaveManager and BaseManager (make sure they're in the same folder)
local SaveManager = require(script.Parent.SaveManager)
local BaseManager = require(script.Parent.BaseManager)
local CollectionZoneManager = require(script.Parent.CollectionZoneManager)
local SellingManager = require(script.Parent.SellingManager)
local GamepassManager = require(script.Parent.GamepassManager)
local GroupRewardManager = require(script.Parent.GroupRewardManager)
local BoostManager = require(script.Parent.BoostManager)
local WheelManager = require(script.Parent.WheelManager)

-- Require Thing System
local ThingSystemHandler = require(ServerScriptService.Things.ThingSystemHandler)
local ThingInventoryManager = require(ServerScriptService.Things.ThingInventoryManager)
local UpgradeManager = require(ServerScriptService.Things.UpgradeManager)
local BaseSlotManager = require(ServerScriptService.Things.BaseSlotManager)

-- Note: MarketplaceHandler.lua in Monetization folder runs automatically (it's a Script, not ModuleScript)

-- Configuration
local STARTING_MONEY = 0

-- Setup player when they join
local function setupPlayer(player)
	print("[PlayerSetup] Starting setup for", player.Name)

	-- STEP 1: Create leaderstats folder
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Create Money value (NumberValue supports values beyond 2 billion)
	local money = Instance.new("NumberValue")
	money.Name = "Money"
	money.Value = STARTING_MONEY
	money.Parent = leaderstats

	-- Create Rebirth value
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = leaderstats

	-- STEP 2: Load player data from DataStore
	print("[PlayerSetup] Loading save data for", player.Name)
	local data = SaveManager:LoadData(player)

	-- STEP 3: Apply loaded data to player
	if data then
		money.Value = data.Money or STARTING_MONEY
		rebirths.Value = data.Rebirths or 0

		-- Store player stats and data as attributes (only simple values, no tables)
		player:SetAttribute("Speed", data.Speed or 18)
		player:SetAttribute("Rebirths", data.Rebirths or 0)
		player:SetAttribute("SpeedLevel", data.SpeedLevel or 1)
		player:SetAttribute("CarryCapacity", data.CarryCapacity or 1)
		player:SetAttribute("BaseNumber", data.BaseNumber)
		player:SetAttribute("BaseUpgradeLevel", data.BaseUpgradeLevel or 0)

		-- Calculate and set RebirthMultiplier based on rebirths (handles 2x Money gamepass)
		player:SetAttribute("RebirthMultiplier", GamepassManager.GetMoneyMultiplier(player))

		-- Restore owned packs (for UI display only, doesn't block purchases)
		if data.OwnedPacks then
			for packName, owned in pairs(data.OwnedPacks) do
				if owned then
					player:SetAttribute(packName, true)
				end
			end
		end
		print("[PlayerSetup] Applied save data for", player.Name)
	end

	-- STEP 4: Initialize gamepasses (must be done after attributes are set)
	GamepassManager.InitializePlayer(player)
	
	-- STEP 5: Initialize WheelManager with saved spins
	WheelManager:InitializePlayer(player, data and data.WheelSpins or 0)

	-- Track if this is the first spawn (for base teleport)
	local isFirstSpawn = true

	-- Wait for character and set walkspeed
	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		-- Use GamepassManager to get actual walk speed (applies 2x if they have gamepass)
		humanoid.WalkSpeed = GamepassManager.GetActualWalkSpeed(player)

		-- Only teleport to base on FIRST spawn, not on respawn after death
		if isFirstSpawn then
			wait(0.5)
			BaseManager:SetupSpawn(player)
			isFirstSpawn = false
		end
	end

	-- Connect to current and future characters
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- STEP 5: Initialize player's base (assigns BaseNumber if needed)
	print("[PlayerSetup] Initializing base for", player.Name)
	BaseManager:InitializePlayerBase(player)

	-- Wait for base assignment to complete before allowing character spawn
	task.wait(0.2)

	-- STEP 6: Wait for BaseNumber to be set, then setup slots
	print("[PlayerSetup] Waiting for BaseNumber for", player.Name)
	local baseNumber = player:GetAttribute("BaseNumber")
	local attempts = 0
	while not baseNumber and attempts < 50 do
		task.wait(0.1)
		baseNumber = player:GetAttribute("BaseNumber")
		attempts = attempts + 1
	end

	if not baseNumber then
		warn("[PlayerSetup] Failed to get BaseNumber for", player.Name, "after 5 seconds!")
		return
	end

	print("[PlayerSetup] BaseNumber confirmed for", player.Name, "- Base", baseNumber)

	-- STEP 7: Setup base slots (this must happen before loading placed things)
	print("[PlayerSetup] Setting up slots for", player.Name)
	BaseSlotManager.SetupPlayerSlots(player)

	-- STEP 8: Load inventory (this must happen before loading placed things)
	print("[PlayerSetup] Loading inventory for", player.Name)
	-- Inventory is already loaded from data, but ensure it's ready
	if data and data.OwnedItems then
		-- Inventory system will handle this in its Init
		print("[PlayerSetup] Found", #data.OwnedItems, "items in inventory for", player.Name)
	end

	-- STEP 9: Load placed things (this is the final step after everything else is ready)
	print("[PlayerSetup] Loading placed things for", player.Name)
	BaseSlotManager.LoadPlacedThings(player)

	print("[PlayerSetup] Completed full setup for", player.Name)
end

-- Connect events
Players.PlayerAdded:Connect(setupPlayer)
-- Note: PlayerRemoving (save + cleanup) handled by SaveManager

-- Setup existing players (in case script runs after players join)
for _, player in pairs(Players:GetPlayers()) do
	setupPlayer(player)
end

-- Start auto-save system
SaveManager:StartAutoSave()

-- Initialize Base Slot System (must be before Thing System)
BaseSlotManager.Init()

-- Initialize Thing System
ThingSystemHandler.Init()

-- Initialize Inventory and Collection Zone
ThingInventoryManager.Init()
CollectionZoneManager.Init()

-- Initialize Selling System
SellingManager.Init()

-- Initialize Upgrade System
UpgradeManager.Init()

-- Initialize Group Reward System
GroupRewardManager.Init()

-- Initialize Boost Manager (10-minute speed/money boosts)
BoostManager.Initialize()

print("Player Setup system initialized!")
