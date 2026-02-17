-- BaseSlotManager.lua
-- Manages slots in player bases where things can be placed

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BaseSlotManager = {}

local playerSlots = {} -- Track each player's base slots

-- Check if slot is unlocked for player
local function isSlotUnlocked(player, slotNumber)
	-- Slots 1-10 are always unlocked
	if slotNumber <= 10 then
		return true
	end

	-- Slots 11-30 require base upgrades
	-- Slot 11 = upgrade level 1, Slot 12 = upgrade level 2, etc.
	local baseUpgradeLevel = player:GetAttribute("BaseUpgradeLevel") or 0
	local requiredLevel = slotNumber - 10

	return baseUpgradeLevel >= requiredLevel
end

-- Initialize
function BaseSlotManager.Init()
	-- Setup collision group for placed things (no collision with players)
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered("PlacedThings") then
			PhysicsService:RegisterCollisionGroup("PlacedThings")
		end
		-- Disable collision between PlacedThings and Default (players and everything else)
		PhysicsService:CollisionGroupSetCollidable("PlacedThings", "Default", false)
	end)

	-- Create RemoteEvent for steal purchases
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEventsFolder then
		remoteEventsFolder = Instance.new("Folder")
		remoteEventsFolder.Name = "RemoteEvents"
		remoteEventsFolder.Parent = ReplicatedStorage
	end

	local stealEvent = remoteEventsFolder:FindFirstChild("StealThingEvent")
	if not stealEvent then
		stealEvent = Instance.new("RemoteEvent")
		stealEvent.Name = "StealThingEvent"
		stealEvent.Parent = remoteEventsFolder
	end

	-- Handle steal purchases
	stealEvent.OnServerEvent:Connect(function(player, victimUserId, slotName)
		BaseSlotManager.ProcessSteal(player, victimUserId, slotName)
	end)

	-- Create RemoteEvent for slot interactions
	local slotTriggeredEvent = remoteEventsFolder:FindFirstChild("SlotTriggered")
	if not slotTriggeredEvent then
		slotTriggeredEvent = Instance.new("RemoteEvent")
		slotTriggeredEvent.Name = "SlotTriggered"
		slotTriggeredEvent.Parent = remoteEventsFolder
	end

	-- Handle slot triggers from client
	slotTriggeredEvent.OnServerEvent:Connect(function(player, slot)
		if not slot or not slot:IsA("Model") then return end

		-- Get player's current base number
		local playerBaseNumber = player:GetAttribute("BaseNumber")
		if not playerBaseNumber then
			warn("[BaseSlotManager]", player.Name, "triggered slot but has no BaseNumber")
			return
		end

		-- Verify slot belongs to player's current base
		local slotBase = slot.Parent.Parent -- Slot -> Slots -> Base
		if not slotBase or not slotBase.Name:match("^Base%d+") then
			warn("[BaseSlotManager] Invalid slot structure for", slot.Name)
			return
		end

		local slotBaseNumber = tonumber(slotBase.Name:match("%d+"))
		if not slotBaseNumber then
			warn("[BaseSlotManager] Could not parse base number from", slotBase.Name)
			return
		end

		-- Verify this is the owner's slot
		local ownerUserId = slot:GetAttribute("OwnerUserId")
		if ownerUserId == player.UserId then
			-- Additional check: Player must own this base
			if slotBaseNumber ~= playerBaseNumber then
				warn("[BaseSlotManager]", player.Name, "tried to interact with old Base" .. slotBaseNumber, "but owns Base" .. playerBaseNumber)
				return
			end
			-- Owner interaction
			BaseSlotManager.OnSlotTriggered(player, slot)
		else
			-- Non-owner (steal attempt) - this is allowed on any base
			local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
			if ownerPlayer then
				BaseSlotManager.OnStealTriggered(player, ownerPlayer, slot)
			end
		end
	end)
	
	-- Create RemoteEvent for refreshing client prompts (used after LoadPlacedThings)
	local refreshPromptsEvent = remoteEventsFolder:FindFirstChild("RefreshSlotPrompts")
	if not refreshPromptsEvent then
		refreshPromptsEvent = Instance.new("RemoteEvent")
		refreshPromptsEvent.Name = "RefreshSlotPrompts"
		refreshPromptsEvent.Parent = remoteEventsFolder
	end

	-- Note: Player setup handled by PlayerSetup.lua - it will call SetupPlayerSlots directly
	-- No need for PlayerAdded event here since order is controlled by PlayerSetup
end

-- Setup player slots (use existing slot models)
function BaseSlotManager.SetupPlayerSlots(player)
	-- Find player's base using BaseNumber attribute
	local bases = Workspace:FindFirstChild("Bases")
	if not bases then
		warn("[BaseSlotManager] No Bases folder in workspace!")
		return
	end

	local baseNumber = player:GetAttribute("BaseNumber")
	if not baseNumber then
		warn("[BaseSlotManager] Player " .. player.Name .. " has no BaseNumber attribute!")
		return
	end

	local baseName = "Base" .. baseNumber
	local playerBase = bases:FindFirstChild(baseName)
	if not playerBase then
		warn("[BaseSlotManager] No base found for " .. player.Name .. " (looking for " .. baseName .. ")")
		return
	end

	-- Find existing slots folder
	local slotsFolder = playerBase:FindFirstChild("Slots")
	if not slotsFolder then
		warn("[BaseSlotManager] No Slots folder found in " .. player.Name .. "'s base!")
		return
	end

	-- Initialize player slot data
	playerSlots[player.UserId] = {
		Slots = {},
		Base = playerBase
	}

	-- Setup existing slots
	for _, slot in ipairs(slotsFolder:GetChildren()) do
		if slot:IsA("Model") and slot.Name:match("^Slot") then
			BaseSlotManager.SetupSlot(player, slot)
		end
	end

	-- Listen for BaseNumber changes (when player gets reassigned to a new base)
	player:GetAttributeChangedSignal("BaseNumber"):Connect(function()
		local newBaseNumber = player:GetAttribute("BaseNumber")
		if newBaseNumber and newBaseNumber ~= baseNumber then
			print("[BaseSlotManager]", player.Name, "base changed from", baseNumber, "to", newBaseNumber)

			-- Save current state before switching
			local ServerScriptService = game:GetService("ServerScriptService")
			local SaveManager = require(ServerScriptService.GameManager.SaveManager)
			local currentData = SaveManager:GetPlayerData(player)
			if currentData then
				SaveManager:SaveData(player, currentData)
				print("[BaseSlotManager] Saved", (#currentData.PlacedThings or 0), "placed things before base switch")
			end

			-- Clear OLD base
			local oldBaseName = "Base" .. baseNumber
			local oldPlayerBase = bases:FindFirstChild(oldBaseName)
			if oldPlayerBase then
				local oldSlotsFolder = oldPlayerBase:FindFirstChild("Slots")
				if oldSlotsFolder then
					for _, slot in ipairs(oldSlotsFolder:GetChildren()) do
						if slot:IsA("Model") and slot.Name:match("^Slot") then
							local baseModel = slot:FindFirstChild("Base")
							if baseModel then
								local placeHolder = baseModel:FindFirstChild("PlaceHolder")
								if placeHolder then
									-- Destroy thing
									local thing = placeHolder:FindFirstChildOfClass("Model")
									if thing then
										thing:Destroy()
									end
									-- Destroy prompts
									for _, child in ipairs(placeHolder:GetChildren()) do
										if child:IsA("ProximityPrompt") then
											child:Destroy()
										end
									end
								end
							end
							-- Clear attributes
							slot:SetAttribute("OwnerUserId", nil)
							slot:SetAttribute("Occupied", false)
							slot:SetAttribute("PlacedThingName", nil)
							slot:SetAttribute("PlacedThingMutation", nil)
							slot:SetAttribute("UpgradeLevel", 0)
							slot:SetAttribute("AccumulatedMoney", 0)
						end
					end
				end
			end

			-- Setup NEW base
			local newBaseName = "Base" .. newBaseNumber
			local newPlayerBase = bases:FindFirstChild(newBaseName)

			if newPlayerBase then
				local newSlotsFolder = newPlayerBase:FindFirstChild("Slots")
				if newSlotsFolder then
					-- Update base reference
					playerSlots[player.UserId].Base = newPlayerBase
					playerSlots[player.UserId].Slots = {}

					-- Setup new slots
					for _, slot in ipairs(newSlotsFolder:GetChildren()) do
						if slot:IsA("Model") and slot.Name:match("^Slot") then
							BaseSlotManager.SetupSlot(player, slot)
						end
					end

					-- Load placed things from saved data
					BaseSlotManager.LoadPlacedThings(player)

					print("[BaseSlotManager]", player.Name, "switched to", newBaseName)
				end
			end

			-- Update baseNumber for future checks
			baseNumber = newBaseNumber
		end
	end)

	-- Note: playerSlots cleanup handled by BaseManager:CleanupPlayer after save completes
end

-- Setup an existing slot
function BaseSlotManager.SetupSlot(player, slot)
	local playerData = playerSlots[player.UserId]
	if not playerData then return end

	-- Find Base model (contains ProximityPrompt and PlaceHolder)
	local baseModel = slot:FindFirstChild("Base")
	if not baseModel then return end

	-- Find PlaceHolder (where things will be placed)
	local placeHolder = baseModel:FindFirstChild("PlaceHolder")
	if not placeHolder then return end

	-- Initialize slot data attributes ONLY if not already set (preserve existing data)
	if slot:GetAttribute("Occupied") == nil then
		slot:SetAttribute("Occupied", false)
	end
	if slot:GetAttribute("PlacedThingName") == nil then
		slot:SetAttribute("PlacedThingName", nil)
	end
	if slot:GetAttribute("UpgradeLevel") == nil then
		slot:SetAttribute("UpgradeLevel", 0)
	end

	-- Set owner ID on slot for client-side prompt handler
	slot:SetAttribute("OwnerUserId", player.UserId)

	-- Find or create owner prompt (for place/remove)
	local ownerPrompt = placeHolder:FindFirstChild("OwnerPrompt")
	if not ownerPrompt then
		-- Check if there's an old prompt to reuse
		local oldPrompt = placeHolder:FindFirstChildOfClass("ProximityPrompt")
		if not oldPrompt then
			oldPrompt = baseModel:FindFirstChild("PlacePrompt")
		end
		if not oldPrompt then
			oldPrompt = baseModel:FindFirstChildOfClass("ProximityPrompt")
		end

		if oldPrompt then
			ownerPrompt = oldPrompt
			ownerPrompt.Name = "OwnerPrompt"
			ownerPrompt.Parent = placeHolder
		else
			-- Create new owner prompt
			ownerPrompt = Instance.new("ProximityPrompt")
			ownerPrompt.Name = "OwnerPrompt"
			ownerPrompt.Parent = placeHolder
		end
	end

	-- Create steal prompt (for non-owners)
	local stealPrompt = placeHolder:FindFirstChild("StealPrompt")
	if not stealPrompt then
		stealPrompt = Instance.new("ProximityPrompt")
		stealPrompt.Name = "StealPrompt"
		stealPrompt.Parent = placeHolder
	end

	-- Extract slot number from slot name (e.g., "Slot5" -> 5)
	local slotNumber = tonumber(slot.Name:match("%d+"))

	if slotNumber and isSlotUnlocked(player, slotNumber) then
		-- Setup owner prompt (place/remove)
		ownerPrompt.Enabled = true
		ownerPrompt.RequiresLineOfSight = false
		ownerPrompt.MaxActivationDistance = 7
		ownerPrompt.HoldDuration = 0.5
		ownerPrompt.KeyboardKeyCode = Enum.KeyCode.E
		ownerPrompt.ActionText = "" -- Empty, client controls it
		ownerPrompt.ObjectText = "Empty Slot"

		-- Prompt triggers for everyone, but routes based on ownership
		ownerPrompt.Triggered:Connect(function(triggerPlayer)
			if triggerPlayer == player then
				-- Owner removes or places
				BaseSlotManager.OnSlotTriggered(player, slot)
			else
				-- Non-owner tries to steal
				BaseSlotManager.OnStealTriggered(triggerPlayer, player, slot)
			end
		end)
	end

	-- Keep steal prompt disabled (not used)
	stealPrompt.Enabled = false

	-- Update prompt when slot occupation changes (client will customize ActionText)
	slot:GetAttributeChangedSignal("Occupied"):Connect(function()
		local occupied = slot:GetAttribute("Occupied")
		if occupied then
			local thingName = slot:GetAttribute("PlacedThingName") or "Thing"
			-- Don't set ActionText here - let client handle it per player
			ownerPrompt.ObjectText = thingName
			ownerPrompt.Enabled = true
		else
			-- Empty slot - don't set ActionText, let client handle it
			ownerPrompt.ObjectText = "Empty Slot"
			ownerPrompt.Enabled = true
		end
	end)

	-- Store slot reference
	table.insert(playerData.Slots, slot)

	-- Initialize money display to $0
	BaseSlotManager.UpdateSlotMoneyDisplay(slot, 0)
end

-- Handle when other player tries to steal from slot
function BaseSlotManager.OnStealTriggered(stealerPlayer, victimPlayer, slot)
	-- Check if slot is occupied
	local occupied = slot:GetAttribute("Occupied")
	if not occupied then
		return -- Nothing to steal
	end

	-- Prompt DevProduct purchase
	local MarketplaceService = game:GetService("MarketplaceService")
	local productId = 3538610589 -- Steal product (49 Robux)

	-- Store steal data temporarily
	if not stealerPlayer:GetAttribute("PendingSteal") then
		stealerPlayer:SetAttribute("PendingStealVictimUserId", victimPlayer.UserId)
		stealerPlayer:SetAttribute("PendingStealSlotName", slot.Name)

		-- Prompt purchase
		MarketplaceService:PromptProductPurchase(stealerPlayer, productId)
	end
end

-- Process steal after successful purchase
function BaseSlotManager.ProcessSteal(stealerPlayer, victimUserId, slotName)
	-- Find victim player
	local victimPlayer = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == victimUserId then
			victimPlayer = p
			break
		end
	end

	if not victimPlayer then
		warn("[BaseSlotManager] Victim player not found for steal")
		return
	end

	-- Find victim's slot
	local victimData = playerSlots[victimUserId]
	if not victimData then
		warn("[BaseSlotManager] Victim slot data not found")
		return
	end

	local slot = nil
	for _, s in ipairs(victimData.Slots) do
		if s.Name == slotName then
			slot = s
			break
		end
	end

	if not slot then
		warn("[BaseSlotManager] Slot not found for steal")
		return
	end

	-- Check if still occupied
	local occupied = slot:GetAttribute("Occupied")
	if not occupied then
		warn("[BaseSlotManager] Slot is no longer occupied")
		return
	end

	-- Get thing data
	local baseModel = slot:FindFirstChild("Base")
	if not baseModel then return end

	local placeHolder = baseModel:FindFirstChild("PlaceHolder")
	if not placeHolder then return end

	local thing = placeHolder:FindFirstChildOfClass("Model")
	if not thing then return end

	-- Get thing details
	local thingName = thing.Name
	local mutation = thing:GetAttribute("Mutation") or ""

	-- Filter out placeholder text from templates (Default, Normal, etc. are NOT real mutations)
	if mutation == "Default" or mutation == "Normal" or mutation == "" then
		mutation = ""
	end

	local upgradeLevel = slot:GetAttribute("UpgradeLevel") or 0

	local ThingValueManager = require(script.Parent.ThingValueManager)
	local rarity = "Common"
	local rate = ThingValueManager.GetThingValue(thing)

	local handle = thing:FindFirstChild("Handle")
	if handle then
		local statsGui = handle:FindFirstChild("StatsGui")
		if statsGui then
			local frame = statsGui:FindFirstChild("Frame")
			if frame then
				local classLabel = frame:FindFirstChild("Class")
				if classLabel then
					rarity = classLabel.Text
				end
			end
		end
	end

	-- Get GuiData
	local guiData = {}
	if handle then
		local statsGui = handle:FindFirstChild("StatsGui")
		if statsGui then
			local frame = statsGui:FindFirstChild("Frame")
			if frame then
				local mutationLabel = frame:FindFirstChild("Mutation")
				if mutationLabel then
					guiData.MutationText = mutationLabel.Text
					guiData.MutationColor = {mutationLabel.TextColor3.R, mutationLabel.TextColor3.G, mutationLabel.TextColor3.B}
				end

				local nameLabel = frame:FindFirstChild("Name")
				if nameLabel then
					guiData.NameColor = {nameLabel.TextColor3.R, nameLabel.TextColor3.G, nameLabel.TextColor3.B}
				end

				local classLabel = frame:FindFirstChild("Class")
				if classLabel then
					guiData.ClassColor = {classLabel.TextColor3.R, classLabel.TextColor3.G, classLabel.TextColor3.B}
				end

				local rateLabel = frame:FindFirstChild("Rate")
				if rateLabel then
					guiData.RateColor = {rateLabel.TextColor3.R, rateLabel.TextColor3.G, rateLabel.TextColor3.B}
				end
			end
		end
	end

	-- Add to stealer's inventory
	local ThingInventoryManager = require(script.Parent.ThingInventoryManager)
	local success, message = ThingInventoryManager.AddToInventory(stealerPlayer, thingName, mutation, rarity, rate, guiData, upgradeLevel)

	if not success then
		warn("[BaseSlotManager] Failed to add stolen thing to stealer's inventory:", message)
		-- Notify stealer
		local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		if remoteEventsFolder then
			local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
			if notificationEvent then
				notificationEvent:FireClient(stealerPlayer, "Failed to steal: " .. message, false)
			end
		end
		return
	end

	-- Remove thing from victim's slot
	thing:Destroy()

	-- Mark slot as empty
	slot:SetAttribute("Occupied", false)
	slot:SetAttribute("PlacedThingName", nil)
	slot:SetAttribute("PlacedThingMutation", nil)
	slot:SetAttribute("UpgradeLevel", 0)
	slot:SetAttribute("AccumulatedMoney", 0)

	-- Reset Collect part
	local collect = slot:FindFirstChild("Collect")
	if collect then
		collect.Transparency = 0
		local moneyGui = collect:FindFirstChild("MoneyGui")
		if moneyGui then
			moneyGui.Enabled = true
		end
	end

	-- Hide Upgrade part
	local upgrade = slot:FindFirstChild("Upgrade")
	if upgrade then
		upgrade.Transparency = 1
		local upgradeGui = upgrade:FindFirstChild("SurfaceGui")
		if upgradeGui then
			upgradeGui.Enabled = false
		end
	end

	BaseSlotManager.UpdateSlotMoneyDisplay(slot, 0)

	-- Update ProximityPrompt
	local prompt = placeHolder:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.ObjectText = "Empty Slot"
	end

	-- Notify both players
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEventsFolder then
		local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
		if notificationEvent then
			notificationEvent:FireClient(stealerPlayer, "Stole " .. thingName .. " from " .. victimPlayer.Name .. "!", true)
			notificationEvent:FireClient(victimPlayer, stealerPlayer.Name .. " stole your " .. thingName .. "!", false)

			-- Play sounds
			local playSoundEvent = remoteEventsFolder:FindFirstChild("PlaySoundEvent")
			if playSoundEvent then
				playSoundEvent:FireClient(stealerPlayer, "ClaimSound") -- Success sound for stealer
				playSoundEvent:FireClient(victimPlayer, "Error") -- Error sound for victim
			end
		end
	end
end

-- Handle when player triggers slot prompt
function BaseSlotManager.OnSlotTriggered(player, slot)
	-- CRITICAL: Verify player actually owns this slot's base
	local slotOwnerUserId = slot:GetAttribute("OwnerUserId")
	if not slotOwnerUserId or slotOwnerUserId ~= player.UserId then
		warn("[BaseSlotManager]", player.Name, "tried to interact with slot they don't own!")
		return
	end

	-- Additional check: Verify player's current base matches this slot's base
	local playerBaseNumber = player:GetAttribute("BaseNumber")
	if not playerBaseNumber then
		warn("[BaseSlotManager]", player.Name, "has no BaseNumber!")
		return
	end

	-- Find which base this slot belongs to
	local slotBase = slot.Parent.Parent -- Slot -> Slots -> Base
	if not slotBase or not slotBase.Name:match("^Base%d+") then
		warn("[BaseSlotManager] Could not determine base for slot", slot.Name)
		return
	end

	local slotBaseNumber = tonumber(slotBase.Name:match("%d+"))
	if slotBaseNumber ~= playerBaseNumber then
		warn("[BaseSlotManager]", player.Name, "tried to interact with Base" .. slotBaseNumber, "but they own Base" .. playerBaseNumber)
		return
	end

	-- Check if slot is occupied - if yes, remove thing, if no, try to place
	local occupied = slot:GetAttribute("Occupied")

	if occupied then
		-- Remove thing from slot
		BaseSlotManager.RemoveThing(player, slot)
	else
		-- Try to place equipped Tool
		local character = player.Character
		if not character then return end

		local equippedTool = character:FindFirstChildOfClass("Tool")
		if not equippedTool then return end

		-- Check if this is an inventory Tool (has InventoryIndex)
		local inventoryIndex = equippedTool:GetAttribute("InventoryIndex")
		if not inventoryIndex then return end

		-- Get the actual thing name (strip mutation prefix if present)
		local toolName = equippedTool:GetAttribute("ThingName") or equippedTool.Name
		-- Strip mutation prefix from display name if ThingName attribute doesn't exist
		if not equippedTool:GetAttribute("ThingName") then
			-- Remove "Gold ", "Diamond ", "Emerald " prefix
			toolName = toolName:gsub("^Gold ", ""):gsub("^Diamond ", ""):gsub("^Emerald ", "")
		end
		local ServerStorage = game:GetService("ServerStorage")
		local thingsFolder = ServerStorage:FindFirstChild("Things")

		if not thingsFolder then
			warn("[BaseSlotManager] Things folder not found in ServerStorage!")
			return
		end

		-- Search all rarity folders for the thing
		local toolTemplate = nil
		for _, rarityFolder in pairs(thingsFolder:GetChildren()) do
			if rarityFolder:IsA("Folder") then
				local foundThing = rarityFolder:FindFirstChild(toolName)
				if foundThing then
					toolTemplate = foundThing
					break
				end
			end
		end

		if not toolTemplate then
			warn("[BaseSlotManager] Could not find template for:", toolName)
			return
		end

		-- Unequip tool first
		equippedTool.Parent = player:FindFirstChild("Backpack")

		-- Clone fresh from template
		local toolClone = toolTemplate:Clone()

		-- Copy all saved attributes from equipped tool
		local mutation = equippedTool:GetAttribute("Mutation")
		local savedUpgradeLevel = equippedTool:GetAttribute("UpgradeLevel") or 0
		local savedRate = equippedTool:GetAttribute("Rate") or 0

		if mutation then
			toolClone:SetAttribute("Mutation", mutation)

			-- Update StatsGui to show mutation
			local handle = toolClone:FindFirstChild("Handle")
			if handle then
				local statsGui = handle:FindFirstChild("StatsGui")
				if statsGui then
					local frame = statsGui:FindFirstChild("Frame")
					if frame then
						local mutationLabel = frame:FindFirstChild("Mutation")
						if mutationLabel then
							if mutation and mutation ~= "" then
								-- Has mutation - show it
								mutationLabel.Text = mutation
								mutationLabel.Visible = true
								-- Color the mutation text
								local MutationEffects = require(script.Parent.MutationEffects)
								mutationLabel.TextColor3 = MutationEffects.GetMutationColor(mutation)
							else
								-- No mutation - hide label
								mutationLabel.Visible = false
							end
						end
					end
				end
			end

			-- Also update BillboardGui if present (for humanoid things)
			local billboardGui = toolClone:FindFirstChild("BillboardGui")
			if not billboardGui then
				-- Check in Handle
				if handle then
					billboardGui = handle:FindFirstChild("BillboardGui")
				end
			end
			if billboardGui then
				local frame = billboardGui:FindFirstChild("Frame")
				if frame then
					local mutationLabel = frame:FindFirstChild("Mutation")
					if mutationLabel then
						if mutation and mutation ~= "" then
							mutationLabel.Text = mutation
							mutationLabel.Visible = true
							local MutationEffects = require(script.Parent.MutationEffects)
							mutationLabel.TextColor3 = MutationEffects.GetMutationColor(mutation)
						else
							mutationLabel.Visible = false
						end
					end
				end
			end
		end

		-- Store saved upgrade level and rate for placement
		if savedUpgradeLevel > 0 then
			toolClone:SetAttribute("SavedUpgradeLevel", savedUpgradeLevel)
		end
		if savedRate > 0 then
			toolClone:SetAttribute("SavedRate", savedRate)
		end

		-- Place the cloned tool in the slot
		local success, message = BaseSlotManager.PlaceThing(player, toolClone, slot)

		if success then
			-- Remove from inventory data (not just the tool)
			local ThingInventoryManager = require(script.Parent.ThingInventoryManager)
			ThingInventoryManager.RemoveFromInventoryByIndex(player, inventoryIndex)

			-- Remove original tool completely
			equippedTool:Destroy()
		else
			-- Re-equip if placement failed
			equippedTool.Parent = character
			toolClone:Destroy()
		end
	end
end

-- Update money display on slot (shows accumulated money)
function BaseSlotManager.UpdateSlotMoneyDisplay(slot, accumulatedMoney)
	local collect = slot:FindFirstChild("Collect")
	if not collect then return end

	local moneyGui = collect:FindFirstChild("MoneyGui")
	if not moneyGui then return end

	local frame = moneyGui:FindFirstChild("Frame")
	if not frame then return end

	local moneyLabel = frame:FindFirstChild("Money")
	if moneyLabel and moneyLabel:IsA("TextLabel") then
		if accumulatedMoney > 0 then
			-- Format with extended suffixes matching MoneySpeedDisplay
			local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
			local tier = 1
			local num = accumulatedMoney

			while num >= 1000 and tier < #suffixes do
				num = num / 1000
				tier = tier + 1
			end

			-- Check if it's a whole number
			local isWhole = (num == math.floor(num))

			local formatted
			if isWhole then
				formatted = string.format("$%.0f%s", num, suffixes[tier])
			elseif num >= 100 then
				formatted = string.format("$%.0f%s", num, suffixes[tier])
			elseif num >= 10 then
				formatted = string.format("$%.1f%s", num, suffixes[tier])
			else
				formatted = string.format("$%.2f%s", num, suffixes[tier])
			end
			moneyLabel.Text = formatted
		else
			-- Check if slot has something placed - show $0 if occupied, blank if empty
			local isOccupied = slot:GetAttribute("Occupied")
			if isOccupied then
				moneyLabel.Text = "$0" -- Show $0 when placed thing has no accumulated money
			else
				moneyLabel.Text = "" -- Show blank for empty slots
			end
		end
	end
end

-- Check if player can place thing in slot
function BaseSlotManager.CanPlaceInSlot(player, slot)
	-- Check if slot is occupied
	local occupied = slot:GetAttribute("Occupied")
	if occupied then
		return false, "Slot is occupied"
	end

	return true, "OK"
end

-- Place thing in slot
function BaseSlotManager.PlaceThing(player, thing, slot)
	local canPlace, message = BaseSlotManager.CanPlaceInSlot(player, slot)

	if not canPlace then
		return false, message
	end

	-- Find Base model and PlaceHolder
	local baseModel = slot:FindFirstChild("Base")
	if not baseModel then
		return false, "Slot missing Base model"
	end

	local placeHolder = baseModel:FindFirstChild("PlaceHolder")
	if not placeHolder then
		return false, "Slot missing PlaceHolder"
	end

	-- Position thing on PlaceHolder using proper ground positioning (like spawner)
	thing.Parent = placeHolder

	-- Hide StatsGui temporarily to prevent showing old values
	local handle = thing:FindFirstChild("Handle")
	if handle then
		local statsGui = handle:FindFirstChild("StatsGui")
		if statsGui then
			statsGui.Enabled = false
		end
	end

	-- Find the lowest Y position of all parts in the model
	local lowestY = math.huge
	for _, part in ipairs(thing:GetDescendants()) do
		if part:IsA("BasePart") then
			local partBottom = part.Position.Y - (part.Size.Y / 2)
			if partBottom < lowestY then
				lowestY = partBottom
			end
		end
	end

	-- Get current model position
	local currentCFrame = thing:GetPivot()
	local currentY = currentCFrame.Position.Y

	-- Calculate offset needed to put bottom at PlaceHolder top surface
	local targetY = placeHolder.Position.Y + (placeHolder.Size.Y / 2)
	local yOffset = targetY - lowestY

	-- Determine rotation based on slot number
	local slotNumber = tonumber(slot.Name:match("%d+")) or 1
	local rotationAngle = 0

	-- Slots 1-5, 11-15, 21-25 = 180 degrees, others = 0 degrees
	if (slotNumber >= 1 and slotNumber <= 5) or 
		(slotNumber >= 11 and slotNumber <= 15) or 
		(slotNumber >= 21 and slotNumber <= 25) then
		rotationAngle = 180
	else
		rotationAngle = 0
	end

	-- Position with calculated rotation
	local finalPosition = Vector3.new(placeHolder.Position.X, currentY + yOffset, placeHolder.Position.Z)
	local rotation = CFrame.Angles(0, math.rad(rotationAngle), 0)
	thing:PivotTo(CFrame.new(finalPosition) * rotation)

	-- Anchor all parts and setup collision
	for _, part in ipairs(thing:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CollisionGroup = "PlacedThings" -- Use collision group to prevent player collision
		elseif part:IsA("ProximityPrompt") then
			-- Disable any ProximityPrompts from the ServerStorage model
			part.Enabled = false
		end
	end

	-- CRITICAL: Explicitly set Handle collision (ensure it's never collidable)
	local handle = thing:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.Anchored = true
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.CollisionGroup = "PlacedThings"
		handle.Transparency = 1 -- Make handle invisible
	end

	-- Disable humanoid collisions
	local humanoid = thing:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true

		-- Also set collision properties for humanoids
		local rootPart = thing:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.CanCollide = false
			rootPart.CanTouch = false
			rootPart.CanQuery = false
			rootPart.CollisionGroup = "PlacedThings"
		end
	end

	-- Mark slot as occupied (restore saved upgrade level or use existing/default to 0)
	slot:SetAttribute("Occupied", true)
	slot:SetAttribute("PlacedThingName", thing.Name)

	-- Check for saved upgrade level from previous placement
	local savedUpgradeLevel = thing:GetAttribute("SavedUpgradeLevel")
	if savedUpgradeLevel then
		-- Restore previous upgrade level
		slot:SetAttribute("UpgradeLevel", savedUpgradeLevel)
		-- Clear saved level now that it's restored
		thing:SetAttribute("SavedUpgradeLevel", nil)
		thing:SetAttribute("SavedRate", nil)
	elseif not slot:GetAttribute("UpgradeLevel") then
		-- New placement, default to 0
		slot:SetAttribute("UpgradeLevel", 0)
	end

	-- Store mutation if exists
	local mutation = thing:GetAttribute("Mutation")
	if mutation then
		slot:SetAttribute("PlacedThingMutation", mutation)

		-- Apply visual mutation effects
		local MutationEffects = require(script.Parent.MutationEffects)
		MutationEffects.ApplyEffects(thing)
	end

	-- Mark thing as placed (set these BEFORE rate calculation so ThingValueManager can find the slot)
	thing:SetAttribute("IsPlaced", true)
	thing:SetAttribute("OwnerUserId", player.UserId)
	thing:SetAttribute("SlotName", slot.Name)

	-- Initialize accumulated money to 0
	slot:SetAttribute("AccumulatedMoney", 0)

	-- Make Collect part visible and setup touch detection
	local collect = slot:FindFirstChild("Collect")
	if collect and collect:IsA("BasePart") then
		collect.Transparency = 0
		collect.CanCollide = false
		collect.CanTouch = true
		local moneyGui = collect:FindFirstChild("MoneyGui")
		if moneyGui then
			moneyGui.Enabled = true
		end

		-- Setup touch detection to collect money
		collect.Touched:Connect(function(hit)
			local touchedPlayer = game.Players:GetPlayerFromCharacter(hit.Parent)
			if touchedPlayer == player then
				local accumulated = slot:GetAttribute("AccumulatedMoney") or 0
				if accumulated > 0 then
					-- Give money to player
					local leaderstats = player:FindFirstChild("leaderstats")
					if leaderstats then
						local money = leaderstats:FindFirstChild("Money")
						if money then
							money.Value = money.Value + accumulated
						end
					end

					-- Play collect sound
					local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
					if remoteEvents then
						local playSoundEvent = remoteEvents:FindFirstChild("PlaySoundEvent")
						if playSoundEvent then
							playSoundEvent:FireClient(player, "CollectSound")
						end
					end

					-- Reset accumulated money
					slot:SetAttribute("AccumulatedMoney", 0)
					BaseSlotManager.UpdateSlotMoneyDisplay(slot, 0)
				end
			end
		end)
	end

	-- Make Upgrade part visible
	local upgrade = slot:FindFirstChild("Upgrade")
	if upgrade then
		upgrade.Transparency = 0
		local upgradeGui = upgrade:FindFirstChild("SurfaceGui")
		if upgradeGui then
			upgradeGui.Enabled = true
		end
	end

	-- Update prompt (client will set ActionText based on ownership)
	local ownerPrompt = placeHolder:FindFirstChild("OwnerPrompt")
	if ownerPrompt then
		-- Don't set ActionText here - let client handle it per player
		ownerPrompt.ObjectText = thing.Name
		ownerPrompt.Enabled = true
	end

	-- Keep steal prompt disabled
	local stealPrompt = placeHolder:FindFirstChild("StealPrompt")
	if stealPrompt then
		stealPrompt.Enabled = false
	end

	-- Update thing's GUI immediately (all at once) - rate will be set by update loop
	local handle = thing:FindFirstChild("Handle")
	if handle then
		local statsGui = handle:FindFirstChild("StatsGui")
		if statsGui then
			local frame = statsGui:FindFirstChild("Frame")
			if frame then
				-- Update mutation display (show actual mutation, not template default)
				local mutationLabel = frame:FindFirstChild("Mutation")
				if mutationLabel then
					local displayMutation = mutation or ""
					mutationLabel.Text = displayMutation

					-- Color the mutation text
					if displayMutation ~= "" then
						local MutationEffects = require(script.Parent.MutationEffects)
						mutationLabel.TextColor3 = MutationEffects.GetMutationColor(displayMutation)
					end
				end

				-- Ensure name and rarity are correct
				local nameLabel = frame:FindFirstChild("Name")
				if nameLabel then
					nameLabel.Text = thing.Name
					
					-- Special styling for Love Ram name label
					if thing.Name == "Love Ram" then
						nameLabel.TextColor3 = Color3.fromRGB(0, 0, 0) -- Black text
						
						-- Add white UIStroke
						local nameStroke = nameLabel:FindFirstChildOfClass("UIStroke")
						if not nameStroke then
							nameStroke = Instance.new("UIStroke")
							nameStroke.Parent = nameLabel
						end
						nameStroke.Color = Color3.fromRGB(255, 255, 255)
						nameStroke.Thickness = 1
						
						-- Add pink gradient
						local nameGradient = nameLabel:FindFirstChildOfClass("UIGradient")
						if not nameGradient then
							nameGradient = Instance.new("UIGradient")
							nameGradient.Parent = nameLabel
						end
						nameGradient.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 255)), -- #ffaaff
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 85, 255)) -- #ff55ff
						}
					end
				end

				local classLabel = frame:FindFirstChild("Class")
				if classLabel then
					-- Get rarity from template location
					local ServerStorage = game:GetService("ServerStorage")
					local thingsFolder = ServerStorage:FindFirstChild("Things")
					if thingsFolder then
						for _, rarityFolder in pairs(thingsFolder:GetChildren()) do
							if rarityFolder:IsA("Folder") then
								if rarityFolder:FindFirstChild(thing.Name) then
									local rarity = rarityFolder.Name
									classLabel.Text = rarity

									-- Apply rarity color (same as spawner)
									if rarity == "Common" then
										classLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
									elseif rarity == "Uncommon" then
										classLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
									elseif rarity == "Rare" then
										classLabel.TextColor3 = Color3.fromRGB(0, 112, 221)
									elseif rarity == "Epic" then
										classLabel.TextColor3 = Color3.fromRGB(163, 53, 238)
									elseif rarity == "Legendary" then
										classLabel.TextColor3 = Color3.fromRGB(255, 128, 0)
									elseif rarity == "Mythical" then
										classLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
									elseif rarity == "Divine" then
										classLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
									elseif rarity == "Secret" then
										classLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
										-- Add white UIStroke for Secret
										local uiStroke = classLabel:FindFirstChildOfClass("UIStroke")
										if not uiStroke then
											uiStroke = Instance.new("UIStroke")
											uiStroke.Parent = classLabel
										end
										uiStroke.Color = Color3.fromRGB(255, 255, 255)
										uiStroke.Thickness = 1
									elseif rarity == "Celestial" then
										-- Celestial uses gradient
										local uiGradient = classLabel:FindFirstChildOfClass("UIGradient")
										if not uiGradient then
											uiGradient = Instance.new("UIGradient")
											uiGradient.Parent = classLabel
										end
										uiGradient.Color = ColorSequence.new{
											ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 255)), -- #ffaaff
											ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 85, 255)) -- #ff55ff
										}
										classLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
									elseif rarity == "Limited" then
										classLabel.TextColor3 = Color3.fromRGB(0, 0, 0) -- Black text
										-- Add white UIStroke for Limited
										local uiStroke = classLabel:FindFirstChildOfClass("UIStroke")
										if not uiStroke then
											uiStroke = Instance.new("UIStroke")
											uiStroke.Parent = classLabel
										end
										uiStroke.Color = Color3.fromRGB(255, 255, 255)
										uiStroke.Thickness = 1
										-- Add green gradient for Limited
										local uiGradient = classLabel:FindFirstChildOfClass("UIGradient")
										if not uiGradient then
											uiGradient = Instance.new("UIGradient")
											uiGradient.Parent = classLabel
										end
										uiGradient.Color = ColorSequence.new{
											ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 255, 127)), -- #55ff7f
											ColorSequenceKeypoint.new(1, Color3.fromRGB(85, 255, 0)) -- #55ff00
										}
									end
									break
								end
							end
						end
					end
				end
			end
		end
	end

	-- Hide timer GUI immediately
	for _, desc in ipairs(thing:GetDescendants()) do
		if desc:IsA("BillboardGui") and desc.Name == "TimerGui" then
			desc.Enabled = false
		end
	end

	-- Set rate immediately from saved value (if available) or calculate
	local savedRate = thing:GetAttribute("SavedRate")
	local initialRate = savedRate
	if not initialRate or initialRate == 0 then
		local ThingValueManager = require(script.Parent.ThingValueManager)
		initialRate = ThingValueManager.GetThingValue(thing)
	end

	-- Display the rate immediately
	if handle then
		local statsGui = handle:FindFirstChild("StatsGui")
		if statsGui then
			local frame = statsGui:FindFirstChild("Frame")
			if frame then
				local rateLabel = frame:FindFirstChild("Rate")
				if rateLabel then
					-- Format with extended suffixes
					local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
					local tier = 1
					local num = initialRate

					while num >= 1000 and tier < #suffixes do
						num = num / 1000
						tier = tier + 1
					end

					-- Check if it's a whole number
					local isWhole = (num == math.floor(num))

					local formatted
					if isWhole then
						formatted = string.format("$%.0f%s/s", num, suffixes[tier])
					elseif num >= 100 then
						formatted = string.format("$%.0f%s/s", num, suffixes[tier])
					elseif num >= 10 then
						formatted = string.format("$%.1f%s/s", num, suffixes[tier])
					else
						formatted = string.format("$%.2f%s/s", num, suffixes[tier])
					end
					rateLabel.Text = formatted
				end
			end
			-- Now show the StatsGui with correct rate
			statsGui.Enabled = true
		end
	end

	-- Initialize upgrade UI with initial rate
	local UpgradeManager = require(script.Parent.UpgradeManager)
	local currentLevel = slot:GetAttribute("UpgradeLevel") or 0
	UpgradeManager.UpdateUpgradeUI(slot, initialRate, currentLevel)

	-- Start UI update loop for this slot (starts after 1 second, then updates every second for upgrades)
	task.spawn(function()
		local ThingValueManager = require(script.Parent.ThingValueManager)

		while thing and thing.Parent and slot:GetAttribute("Occupied") do
			task.wait(1) -- Wait 1 second before each update

			-- Update rate display and upgrade UI based on current upgrade level
			local currentRate = ThingValueManager.GetThingValue(thing)
			local currentLevel = slot:GetAttribute("UpgradeLevel") or 0

			-- Update upgrade UI
			UpgradeManager.UpdateUpgradeUI(slot, currentRate, currentLevel)

			-- Update rate display
			local handle = thing:FindFirstChild("Handle")
			if handle then
				local statsGui = handle:FindFirstChild("StatsGui")
				if statsGui then
					local frame = statsGui:FindFirstChild("Frame")
					if frame then
						local rateLabel = frame:FindFirstChild("Rate")
						if rateLabel then
							-- Format with extended suffixes
							local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
							local tier = 1
							local num = currentRate

							while num >= 1000 and tier < #suffixes do
								num = num / 1000
								tier = tier + 1
							end

							-- Check if it's a whole number
							local isWhole = (num == math.floor(num))

							local formatted
							if isWhole then
								formatted = string.format("$%.0f%s/s", num, suffixes[tier])
							elseif num >= 100 then
								formatted = string.format("$%.0f%s/s", num, suffixes[tier])
							elseif num >= 10 then
								formatted = string.format("$%.1f%s/s", num, suffixes[tier])
							else
								formatted = string.format("$%.2f%s/s", num, suffixes[tier])
							end
							rateLabel.Text = formatted
						end
					end
				end
			end
		end
	end)

	return true, "Placed!"
end

-- Remove thing from slot
function BaseSlotManager.RemoveThing(player, slot)
	local baseModel = slot:FindFirstChild("Base")
	if not baseModel then return false, "No Base model" end

	local placeHolder = baseModel:FindFirstChild("PlaceHolder")
	if not placeHolder then return false, "No PlaceHolder" end

	-- Find the thing
	local thing = placeHolder:FindFirstChildOfClass("Model")
	if not thing then
		return false, "No thing in slot"
	end

	-- First, collect any accumulated money
	local accumulated = slot:GetAttribute("AccumulatedMoney") or 0
	if accumulated > 0 then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local money = leaderstats:FindFirstChild("Money")
			if money then
				money.Value = money.Value + accumulated
			end
		end
	end

	-- Get thing data to return to inventory
	local thingName = thing.Name
	local mutation = thing:GetAttribute("Mutation") or ""

	-- Filter out placeholder text from templates (Default, Normal, etc. are NOT real mutations)
	if mutation == "Default" or mutation == "Normal" or mutation == "" then
		mutation = ""
	end

	local upgradeLevel = slot:GetAttribute("UpgradeLevel") or 0

	-- Get rarity and rate from the thing's GUI
	local ThingValueManager = require(script.Parent.ThingValueManager)
	local rarity = "Common"
	local rate = ThingValueManager.GetThingValue(thing)

	local handle = thing:FindFirstChild("Handle")
	if handle then
		local statsGui = handle:FindFirstChild("StatsGui")
		if statsGui then
			local frame = statsGui:FindFirstChild("Frame")
			if frame then
				local classLabel = frame:FindFirstChild("Class")
				if classLabel then
					rarity = classLabel.Text
				end
			end
		end
	end

	-- Get GuiData for preservation
	local guiData = {}
	if handle then
		local statsGui = handle:FindFirstChild("StatsGui")
		if statsGui then
			local frame = statsGui:FindFirstChild("Frame")
			if frame then
				-- Save mutation display
				local mutationLabel = frame:FindFirstChild("Mutation")
				if mutationLabel then
					guiData.MutationText = mutationLabel.Text
					guiData.MutationColor = {mutationLabel.TextColor3.R, mutationLabel.TextColor3.G, mutationLabel.TextColor3.B}
				end

				-- Save name color
				local nameLabel = frame:FindFirstChild("Name")
				if nameLabel then
					guiData.NameColor = {nameLabel.TextColor3.R, nameLabel.TextColor3.G, nameLabel.TextColor3.B}
				end

				-- Save class/rarity color
				local classLabel = frame:FindFirstChild("Class")
				if classLabel then
					guiData.ClassColor = {classLabel.TextColor3.R, classLabel.TextColor3.G, classLabel.TextColor3.B}
				end

				-- Save rate color
				local rateLabel = frame:FindFirstChild("Rate")
				if rateLabel then
					guiData.RateColor = {rateLabel.TextColor3.R, rateLabel.TextColor3.G, rateLabel.TextColor3.B}
				end
			end
		end
	end

	-- Add thing back to inventory with all stats preserved (including upgrade level)
	local ThingInventoryManager = require(script.Parent.ThingInventoryManager)
	local success, message = ThingInventoryManager.AddToInventory(player, thingName, mutation, rarity, rate, guiData, upgradeLevel)

	if not success then
		warn("[BaseSlotManager] Failed to return thing to inventory:", message)
		return false, message
	end

	-- Destroy the thing
	thing:Destroy()

	-- Mark slot as empty
	slot:SetAttribute("Occupied", false)
	slot:SetAttribute("PlacedThingName", nil)
	slot:SetAttribute("PlacedThingMutation", nil)
	slot:SetAttribute("UpgradeLevel", 0)

	-- Reset Collect part but keep it visible (for unlocked slots)
	local collect = slot:FindFirstChild("Collect")
	if collect then
		-- Keep visible for unlocked slots
		collect.Transparency = 0
		local moneyGui = collect:FindFirstChild("MoneyGui")
		if moneyGui then
			moneyGui.Enabled = true
		end
	end

	-- Hide Upgrade part
	local upgrade = slot:FindFirstChild("Upgrade")
	if upgrade then
		upgrade.Transparency = 1
		local upgradeGui = upgrade:FindFirstChild("SurfaceGui")
		if upgradeGui then
			upgradeGui.Enabled = false
		end
	end

	-- Update money display
	BaseSlotManager.UpdateSlotMoneyDisplay(slot, 0)

	-- Update prompt (one prompt for everyone)
	local ownerPrompt = placeHolder:FindFirstChild("OwnerPrompt")
	if ownerPrompt then
		ownerPrompt.ObjectText = "Empty Slot"
		ownerPrompt.Enabled = true
	end

	-- Keep steal prompt disabled
	local stealPrompt = placeHolder:FindFirstChild("StealPrompt")
	if stealPrompt then
		stealPrompt.Enabled = false
	end

	return true, thing
end

-- Get nearest empty slot to position
function BaseSlotManager.GetNearestEmptySlot(player, position)
	local playerData = playerSlots[player.UserId]
	if not playerData then return nil end

	local nearestSlot = nil
	local nearestDistance = math.huge

	for _, slot in ipairs(playerData.Slots) do
		local occupied = slot:GetAttribute("Occupied")
		if not occupied then
			local baseModel = slot:FindFirstChild("Base")
			if baseModel then
				local placeHolder = baseModel:FindFirstChild("PlaceHolder")
				if placeHolder then
					local distance = (placeHolder.Position - position).Magnitude
					if distance < nearestDistance then
						nearestDistance = distance
						nearestSlot = slot
					end
				end
			end
		end
	end

	return nearestSlot
end

-- Get all things placed by player
function BaseSlotManager.GetPlacedThings(player)
	local playerData = playerSlots[player.UserId]
	if not playerData then return {} end

	local placedThings = {}

	for _, slot in ipairs(playerData.Slots) do
		local baseModel = slot:FindFirstChild("Base")
		if baseModel then
			local placeHolder = baseModel:FindFirstChild("PlaceHolder")
			if placeHolder then
				local thing = placeHolder:FindFirstChildOfClass("Model")
				if thing then
					table.insert(placedThings, thing)
				end
			end
		end
	end

	return placedThings
end

-- Refresh slot prompts (call after base upgrade)
function BaseSlotManager.RefreshSlotPrompts(player)
	local playerData = playerSlots[player.UserId]
	if not playerData then return end

	for _, slot in ipairs(playerData.Slots) do
		local baseModel = slot:FindFirstChild("Base")
		if baseModel then
			local prompt = baseModel:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				-- Extract slot number
				local slotNumber = tonumber(slot.Name:match("%d+"))

				if slotNumber and isSlotUnlocked(player, slotNumber) then
					prompt.Enabled = true
				else
					prompt.Enabled = false
				end
			end
		end
	end
end

-- Get placed things data from slot attributes (for SaveManager)
function BaseSlotManager.GetPlacedThingsData(player)
	local playerData = playerSlots[player.UserId]
	if not playerData then 
		print("[GetPlacedThingsData] No slot data found for", player.Name)
		return {} 
	end

	local placedData = {}

	for _, slot in ipairs(playerData.Slots) do
		local slotNumber = tonumber(slot.Name:match("%d+"))
		if slotNumber then
			local occupied = slot:GetAttribute("Occupied")
			if occupied then
				placedData[slotNumber] = {
					ThingName = slot:GetAttribute("PlacedThingName"),
					Mutation = slot:GetAttribute("PlacedThingMutation"),
					UpgradeLevel = slot:GetAttribute("UpgradeLevel") or 0,
					AccumulatedMoney = slot:GetAttribute("AccumulatedMoney") or 0,
					LastSaveTime = os.time()
				}
			end
		end
	end

	-- Show count
	local count = 0
	for _ in pairs(placedData) do count = count + 1 end
	print("[GetPlacedThingsData] Found", count, "placed things for", player.Name)

	return placedData
end

-- Note: SavePlacedThings removed - SaveManager now calls GetPlacedThingsData directly

-- Load placed things from SaveManager
function BaseSlotManager.LoadPlacedThings(player)
	local ServerScriptService = game:GetService("ServerScriptService")
	local SaveManager = require(ServerScriptService.GameManager.SaveManager)

	local playerData = playerSlots[player.UserId]
	if not playerData then return end

	-- Get saved data
	-- Get saved data from DataStore (NOT GetPlayerData which reads empty slots)
	local data = SaveManager:LoadData(player)
	if not data or not data.PlacedThings then 
		print("[LoadPlacedThings]", player.Name, "has no saved placed things")
		return 
	end

	-- Count placed things
	local count = 0
	for _ in pairs(data.PlacedThings) do count = count + 1 end
	print("[LoadPlacedThings] Loading", count, "placed things for", player.Name)

	local ServerStorage = game:GetService("ServerStorage")
	local thingsFolder = ServerStorage:FindFirstChild("Things")
	if not thingsFolder then
		warn("[BaseSlotManager] No Things folder in ServerStorage")
		return
	end

	-- Restore each placed thing
	for slotNumber, thingData in pairs(data.PlacedThings) do
		-- Find the slot
		local slotName = "Slot" .. slotNumber
		local slot = nil

		for _, s in ipairs(playerData.Slots) do
			if s.Name == slotName then
				slot = s
				break
			end
		end

		if slot then
			-- Search all rarity folders for the thing
			local thingTemplate = nil
			for _, rarityFolder in pairs(thingsFolder:GetChildren()) do
				if rarityFolder:IsA("Folder") then
					local foundThing = rarityFolder:FindFirstChild(thingData.ThingName)
					if foundThing then
						thingTemplate = foundThing
						break
					end
				end
			end

			if thingTemplate then
				-- Clone and setup thing
				local thing = thingTemplate:Clone()

				-- Apply mutation if saved
				if thingData.Mutation and thingData.Mutation ~= "" then
					thing:SetAttribute("Mutation", thingData.Mutation)

					-- Apply visual mutation effects
					local MutationEffects = require(script.Parent.MutationEffects)
					MutationEffects.ApplyEffects(thing)

					-- Update StatsGui to show mutation
					local handle = thing:FindFirstChild("Handle")
					if handle then
						local statsGui = handle:FindFirstChild("StatsGui")
						if statsGui then
							local frame = statsGui:FindFirstChild("Frame")
							if frame then
								local mutationLabel = frame:FindFirstChild("Mutation")
								if mutationLabel then
									-- Show mutation
									mutationLabel.Text = thingData.Mutation
									mutationLabel.Visible = true
									-- Color the mutation text
									local MutationEffects = require(script.Parent.MutationEffects)
									mutationLabel.TextColor3 = MutationEffects.GetMutationColor(thingData.Mutation)
								end
							end
						end
					end

					-- Also update BillboardGui if present (for humanoid things)
					local billboardGui = thing:FindFirstChild("BillboardGui")
					if not billboardGui and handle then
						billboardGui = handle:FindFirstChild("BillboardGui")
					end
					if billboardGui then
						local frame = billboardGui:FindFirstChild("Frame")
						if frame then
							local mutationLabel = frame:FindFirstChild("Mutation")
							if mutationLabel then
								mutationLabel.Text = thingData.Mutation
								mutationLabel.Visible = true
								local MutationEffects = require(script.Parent.MutationEffects)
								mutationLabel.TextColor3 = MutationEffects.GetMutationColor(thingData.Mutation)
							end
						end
					end
				else
					-- No mutation - hide mutation label
					local handle = thing:FindFirstChild("Handle")
					if handle then
						local statsGui = handle:FindFirstChild("StatsGui")
						if statsGui then
							local frame = statsGui:FindFirstChild("Frame")
							if frame then
								local mutationLabel = frame:FindFirstChild("Mutation")
								if mutationLabel then
									mutationLabel.Visible = false
								end
							end
						end
					end

					-- Also hide BillboardGui mutation label if present (for humanoid things)
					local billboardGui = thing:FindFirstChild("BillboardGui")
					if not billboardGui and handle then
						billboardGui = handle:FindFirstChild("BillboardGui")
					end
					if billboardGui then
						local frame = billboardGui:FindFirstChild("Frame")
						if frame then
							local mutationLabel = frame:FindFirstChild("Mutation")
							if mutationLabel then
								mutationLabel.Visible = false
							end
						end
					end
				end

				-- Calculate offline earnings (0.25x rate with rebirth multiplier)
				local offlineEarnings = 0
				if thingData.LastSaveTime then
					local currentTime = os.time()
					local timeOffline = currentTime - thingData.LastSaveTime

					-- Get thing rate with upgrade level applied
					local ThingValueManager = require(script.Parent.ThingValueManager)
					local baseRate = ThingValueManager.GetThingValue(thing)

					-- Apply rebirth/gamepass multiplier
					local multiplier = player:GetAttribute("RebirthMultiplier") or 1

					-- Calculate offline earnings at 0.25x rate with multiplier
					offlineEarnings = baseRate * multiplier * 0.25 * timeOffline
				end

				-- Calculate total accumulated money (saved amount + offline earnings)
				local totalAccumulated = (thingData.AccumulatedMoney or 0) + offlineEarnings

				-- Set saved upgrade level on thing so PlaceThing can restore it
				if thingData.UpgradeLevel and thingData.UpgradeLevel > 0 then
					thing:SetAttribute("SavedUpgradeLevel", thingData.UpgradeLevel)
				end

				-- Place in slot (handles all UI updates automatically)
				local success = BaseSlotManager.PlaceThing(player, thing, slot)

				if success then
					-- Set the total accumulated money after placement
					slot:SetAttribute("AccumulatedMoney", totalAccumulated)
					BaseSlotManager.UpdateSlotMoneyDisplay(slot, totalAccumulated)
				else
					thing:Destroy()
				end
			else
				warn("[BaseSlotManager] Could not find thing template:", thingData.ThingName)
			end
		end
	end
	
	-- Wait a moment for attributes to replicate to client, then refresh prompts
	task.wait(0.5)
	
	-- Force refresh of all slot prompts on client to ensure they show correct ownership
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEventsFolder then
		local refreshPromptsEvent = remoteEventsFolder:FindFirstChild("RefreshSlotPrompts")
		if refreshPromptsEvent then
			refreshPromptsEvent:FireClient(player)
			print("[LoadPlacedThings] Refreshed slot prompts for", player.Name)
		end
	end
end

-- Wipe all slots for a player (full reset to default)
function BaseSlotManager.WipeAllSlots(player)
	local playerData = playerSlots[player.UserId]
	if not playerData then return end

	for _, slot in ipairs(playerData.Slots) do
		-- Remove any placed thing
		local baseModel = slot:FindFirstChild("Base")
		if baseModel then
			local placeHolder = baseModel:FindFirstChild("PlaceHolder")
			if placeHolder then
				local thing = placeHolder:FindFirstChildOfClass("Model")
				if thing then
					thing:Destroy()
				end
			end
		end

		-- Reset slot attributes (including ownership)
		slot:SetAttribute("Occupied", false)
		slot:SetAttribute("PlacedThingName", nil)
		slot:SetAttribute("PlacedThingMutation", nil)
		slot:SetAttribute("UpgradeLevel", 0)
		slot:SetAttribute("AccumulatedMoney", 0)
		slot:SetAttribute("OwnerUserId", nil)

		-- Reset Collect part UI (only if slot is unlocked)
		local slotNumber = tonumber(slot.Name:match("%d+"))
		local collect = slot:FindFirstChild("Collect")
		if collect then
			if slotNumber and isSlotUnlocked(player, slotNumber) then
				-- Slot is unlocked, keep collect part visible
				collect.Transparency = 0
				collect.CanCollide = false
				collect.CanTouch = true
				local moneyGui = collect:FindFirstChild("MoneyGui")
				if moneyGui then
					moneyGui.Enabled = true
				end
				-- Update money display to $0
				BaseSlotManager.UpdateSlotMoneyDisplay(slot, 0)
			else
				-- Slot is locked, hide collect part
				collect.Transparency = 1
				collect.CanCollide = false
				collect.CanTouch = false
				local moneyGui = collect:FindFirstChild("MoneyGui")
				if moneyGui then
					moneyGui.Enabled = false
				end
			end
		end

		-- Hide Upgrade part
		local upgrade = slot:FindFirstChild("Upgrade")
		if upgrade then
			upgrade.Transparency = 1
			local upgradeGui = upgrade:FindFirstChild("SurfaceGui")
			if upgradeGui then
				upgradeGui.Enabled = false
			end
		end

		-- Update ProximityPrompt
		if baseModel then
			local placeHolder = baseModel:FindFirstChild("PlaceHolder")
			if placeHolder then
				local prompt = placeHolder:FindFirstChildOfClass("ProximityPrompt")
				if prompt then
					prompt.ActionText = "Place"
					prompt.ObjectText = "Empty Slot"
					prompt.Enabled = true
				end
			end
		end
	end

	-- Note: Save happens via autosave or PlayerRemoving in SaveManager
end

-- Clear player slot data (called by BaseManager after save completes)
function BaseSlotManager.ClearPlayerSlots(player)
	playerSlots[player.UserId] = nil
	print("[BaseSlotManager] Cleared slot data for", player.Name)
end

return BaseSlotManager
