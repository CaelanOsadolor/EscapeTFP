-- CollectionZoneManager.lua
-- Handles converting carried things into inventory items when player crosses collection line
-- Place in: ServerScriptService/GameManager/

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionZoneManager = {}

-- Get required modules
local ThingCarryManager
local ThingInventoryManager
local SaveManager

-- Reference to collection zone in workspace
local collectionZone

-- Simple cooldown to prevent multiple triggers (0.5 second per player)
local playerCooldowns = {}

-- Play collection sound for player
local function PlayCollectionSound(player) 
	-- Use existing LocalHandler sound system
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEventsFolder then
		local playSoundEvent = remoteEventsFolder:FindFirstChild("PlaySoundEvent")
		if playSoundEvent then
			-- Play collection/claim sound with default settings from ReplicatedStorage
			playSoundEvent:FireClient(player, "ClaimSound")
		end
	end
end

-- Convert carried things to inventory when player crosses line
local function OnPlayerCrossedZone(player)
	-- Check cooldown to prevent multiple triggers
	if playerCooldowns[player.UserId] then return end

	-- ALWAYS stop carry animation when touching wall (before any checks)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChild("Animator")
			if animator then
				local playingTracks = animator:GetPlayingAnimationTracks()
				for _, track in pairs(playingTracks) do
					track:Stop(0) -- Stop immediately
				end
			end
		end
	end

	if not ThingCarryManager or not ThingInventoryManager then return end

	-- Get player's carried things
	local playerData = ThingCarryManager.GetCarriedThings and ThingCarryManager.GetCarriedThings(player)
	if not playerData or #playerData == 0 then 
		-- Clear cooldown if no items being carried
		playerCooldowns[player.UserId] = nil
		return 
	end

	-- Check if player can collect (inventory not full)
	local canCollect, currentCount, maxCount = ThingInventoryManager.CanCollect(player)
	if not canCollect then
		-- TODO: Show UI message that inventory is full
		warn("[CollectionZone]", player.Name, "inventory full!")
		playerCooldowns[player.UserId] = nil
		return
	end

	-- Set cooldown now (prevents double-trigger during collection)
	playerCooldowns[player.UserId] = true

	-- Convert each carried thing into inventory item
	local collected = 0
	local thingsCopy = {}
	for i, thing in ipairs(playerData) do
		table.insert(thingsCopy, thing)
	end

	for _, thing in ipairs(thingsCopy) do
		if thing and thing.Parent then
			-- Get thing name
			local thingName = thing.Name

			-- Get rarity from thing's Rarity attribute OR from GUI (since attributes might not be set)
			local rarity = thing:GetAttribute("Rarity") or "Common"

			-- Get mutation from thing's Mutation attribute ONLY (NEVER from GUI)
			local mutation = thing:GetAttribute("Mutation") or ""

			-- Filter out placeholder text from templates (Default, Normal, etc. are NOT real mutations)
			if mutation == "Default" or mutation == "Normal" or mutation == "" then
				mutation = ""
			end

			local guiData = {}  -- Capture GUI properties (cosmetic only - NO gameplay values)

			-- Get StatsGui data from Handle (COSMETIC ONLY - colors and display text)
			local handle = thing:FindFirstChild("Handle")
			if handle then
				local statsGui = handle:FindFirstChild("StatsGui")
				if statsGui then
					local frame = statsGui:FindFirstChild("Frame")
					if frame then
						-- Save label colors (NOT values - those are calculated server-side)
						local nameLabel = frame:FindFirstChild("Name")
						if nameLabel then
							-- Only save color, not text (text comes from thing name)
							guiData.NameColor = {nameLabel.TextColor3.R, nameLabel.TextColor3.G, nameLabel.TextColor3.B}
						end

						local classLabel = frame:FindFirstChild("Class")
						if classLabel then
							-- Get rarity from GUI text (authoritative source since attribute might not be set)
							if classLabel.Text and classLabel.Text ~= "" then
								rarity = classLabel.Text
							end
							-- Save rarity color
							guiData.ClassColor = {classLabel.TextColor3.R, classLabel.TextColor3.G, classLabel.TextColor3.B}
						end

						-- Don't save mutation label from GUI (mutation comes from attribute only)
					end
				end
			end

			-- SECURITY: Calculate Rate server-side based on thing properties (NEVER trust GUI)
			-- This prevents exploits where players modify GUI to show fake rates
			local rate = 0
			local ThingValueManager = require(script.Parent.Parent.Things.ThingValueManager)
			if ThingValueManager and ThingValueManager.GetThingValueByName then
				-- Get base rate for this thing + rarity
				local baseRate = ThingValueManager.GetThingValueByName(thingName, rarity)

				-- Apply mutation multiplier (server-side calculation)
				local mutationMultiplier = 1
				if mutation == "Gold" then
					mutationMultiplier = 1.5
				elseif mutation == "Diamond" then
					mutationMultiplier = 2
				elseif mutation == "Emerald" then
					mutationMultiplier = 3
				elseif mutation == "Shiny" then
					mutationMultiplier = 2.5
				end

				rate = baseRate * mutationMultiplier
			end

			-- Add to inventory with all data (name, mutation, rarity, rate, guiData)
			local success, message = ThingInventoryManager.AddToInventory(player, thingName, mutation, rarity, rate, guiData)
			if success then
				-- Destroy the physical thing
				thing:Destroy()
				collected = collected + 1
			else
				warn("[CollectionZone] Failed to add", thingName, ":", message)
				break -- Stop if inventory full
			end
		end
	end

	-- Clear player's carrying data
	if ThingCarryManager.ClearCarried then
		ThingCarryManager.ClearCarried(player)
	end

	-- Save immediately (mutex prevents race conditions)
	if SaveManager and SaveManager.SaveData then
		local data = SaveManager:GetPlayerData(player)
		if data then
			SaveManager:SaveData(player, data)
		end
	end

	-- Play collection sound only once
	PlayCollectionSound(player)

	-- Clear cooldown after 0.5 seconds
	task.delay(0.5, function()
		playerCooldowns[player.UserId] = nil
	end)
end

-- Setup collection zone
local function SetupCollectionZone()
	-- Look for CollectWall in Map/Collect folder
	local map = workspace:FindFirstChild("Map")
	if not map then
		warn("[CollectionZone] Map folder not found in workspace!")
		return
	end

	local collect = map:FindFirstChild("Collect")
	if not collect then
		warn("[CollectionZone] Collect folder not found in Map!")
		return
	end

	collectionZone = collect:FindFirstChild("CollectWall")
	if not collectionZone then
		warn("[CollectionZone] CollectWall not found in Map/Collect folder!")
		return
	end

	-- Make sure wall is set up correctly
	if collectionZone:IsA("BasePart") then
		collectionZone.CanCollide = false
		collectionZone.Anchored = true

		-- Setup touched event
		collectionZone.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				OnPlayerCrossedZone(player)
			end
		end)
	else
		warn("[CollectionZone] CollectWall must be a BasePart!")
	end
end

-- Initialize
function CollectionZoneManager.Init()
	-- Get required modules
	local Things = game:GetService("ServerScriptService"):FindFirstChild("Things")
	if Things then
		ThingCarryManager = require(Things:FindFirstChild("ThingCarryManager"))
		ThingInventoryManager = require(Things:FindFirstChild("ThingInventoryManager"))
	end

	local GameManager = game:GetService("ServerScriptService"):FindFirstChild("GameManager")
	if GameManager then
		SaveManager = require(GameManager:FindFirstChild("SaveManager"))
	end

	-- Setup zone
	SetupCollectionZone()
end

return CollectionZoneManager
