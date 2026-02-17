-- Base Manager Script
-- Place this in ServerScriptService (in GameManager folder)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Configuration
local BASES_FOLDER = Workspace:WaitForChild("Bases")
local MAX_BASES = 5
local HOME_ICON_DISTANCE = 50 -- Distance before home icon appears
local FORCE_RANDOM_BASE = false -- SET TO FALSE FOR PRODUCTION! Forces random base each join for testing

-- Store which bases are claimed
local claimedBases = {} -- [baseNumber] = playerUserId

-- Module
local BaseManager = {}

-- Initialize a single slot (for upgrades)
local function initializeSingleSlot(slot)
	if not slot then return end

	-- Check if slot is occupied - if so, skip it to preserve placed things
	local isOccupied = slot:GetAttribute("Occupied")
	if isOccupied then
		return
	end

	-- Find specific parts
	local baseModel = slot:FindFirstChild("Base")
	local collect = slot:FindFirstChild("Collect")
	local upgrade = slot:FindFirstChild("Upgrade")
	local placeHolder = slot:FindFirstChild("PlaceHolder")
	local part = slot:FindFirstChild("Part")
	local placePrompt = slot:FindFirstChild("PlacePrompt")

	-- Set Upgrade to transparent by default (will be shown when item placed)
	if upgrade then
		if upgrade:IsA("BasePart") then
			upgrade.Transparency = 1
			upgrade.CanCollide = false
		end

		-- Hide all Upgrade descendants
		for _, desc in pairs(upgrade:GetDescendants()) do
			if desc:IsA("SurfaceGui") or desc:IsA("BillboardGui") or desc:IsA("ScreenGui") then
				desc.Enabled = false
			end
			if desc:IsA("BasePart") then
				desc.Transparency = 1
				desc.CanCollide = false
			end
		end
	end

	-- Make Base and Collect visible for the newly unlocked slot
	if baseModel then
		-- Handle Base model and its descendants
		for _, desc in pairs(baseModel:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Transparency = 0
				desc.CanCollide = true
			end
		end

		-- Also handle Base itself if it's a BasePart
		if baseModel:IsA("BasePart") then
			baseModel.Transparency = 0
			baseModel.CanCollide = true
		end
	end

	if collect and collect:IsA("BasePart") then
		collect.Transparency = 0
		collect.CanCollide = true

		-- Handle Collect descendants (MoneyGui)
		for _, desc in pairs(collect:GetDescendants()) do
			if desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
				desc.Enabled = true
			end
			-- Clear money text labels
			if desc:IsA("TextLabel") and desc.Name == "Money" then
				desc.Text = ""
			end
		end
	end

	-- Hide Part, PlaceHolder, PlacePrompt by default
	if part and part:IsA("BasePart") then
		part.Transparency = 1
		part.CanCollide = false
	end

	if placeHolder and placeHolder:IsA("BasePart") then
		placeHolder.Transparency = 1
		placeHolder.CanCollide = false
	end

	if placePrompt and placePrompt:IsA("BasePart") then
		placePrompt.Transparency = 1
		placePrompt.CanCollide = false
	end
end

-- Initialize slots based on upgrade level
local function initializeSlots(base, upgradeLevel)
	local slotsFolder = base:FindFirstChild("Slots")
	if not slotsFolder then return end

	upgradeLevel = upgradeLevel or 0
	local slotsToShow = 10 + upgradeLevel -- Default 10 slots, +1 per upgrade

	for i = 1, 30 do
		local slotName = "Slot" .. i
		local slot = slotsFolder:FindFirstChild(slotName)

		if slot then
			-- Check if slot has something placed in it - if so, skip it to preserve the placed thing
			local isOccupied = slot:GetAttribute("Occupied")
			if isOccupied then
				-- Skip this slot - don't modify anything when something is placed
				continue
			end

			local shouldBeVisible = (i <= slotsToShow)

			-- Find specific parts
			local baseModel = slot:FindFirstChild("Base")
			local collect = slot:FindFirstChild("Collect")
			local upgrade = slot:FindFirstChild("Upgrade")
			local placeHolder = slot:FindFirstChild("PlaceHolder")
			local part = slot:FindFirstChild("Part")
			local placePrompt = slot:FindFirstChild("PlacePrompt")

			-- Set Upgrade to transparent by default (will be shown when item placed)
			if upgrade then
				if upgrade:IsA("BasePart") then
					upgrade.Transparency = 1
					upgrade.CanCollide = false
				end

				-- Hide all Upgrade descendants
				for _, desc in pairs(upgrade:GetDescendants()) do
					if desc:IsA("SurfaceGui") or desc:IsA("BillboardGui") or desc:IsA("ScreenGui") then
						desc.Enabled = false
					end
					if desc:IsA("BasePart") then
						desc.Transparency = 1
						desc.CanCollide = false
					end
				end
			end

			-- Only Base and Collect should be visible if slot is unlocked
			if baseModel then
				-- Handle Base model and its descendants
				for _, desc in pairs(baseModel:GetDescendants()) do
					if desc:IsA("BasePart") then
						if shouldBeVisible then
							desc.Transparency = 0
							desc.CanCollide = true
						else
							desc.Transparency = 1
							desc.CanCollide = false
						end
					end
				end

				-- Also handle Base itself if it's a BasePart
				if baseModel:IsA("BasePart") then
					if shouldBeVisible then
						baseModel.Transparency = 0
						baseModel.CanCollide = true
					else
						baseModel.Transparency = 1
						baseModel.CanCollide = false
					end
				end
			end

			if collect and collect:IsA("BasePart") then
				if shouldBeVisible then
					collect.Transparency = 0
					collect.CanCollide = true
				else
					collect.Transparency = 1
					collect.CanCollide = false
				end

				-- Handle Collect descendants (MoneyGui)
				for _, desc in pairs(collect:GetDescendants()) do
					if desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
						desc.Enabled = shouldBeVisible
					end
					-- Clear money text labels
					if desc:IsA("TextLabel") and desc.Name == "Money" then
						desc.Text = ""
					end
				end
			end

			-- Hide Part, PlaceHolder, PlacePrompt by default
			if part and part:IsA("BasePart") then
				part.Transparency = 1
				part.CanCollide = false
			end

			if placeHolder and placeHolder:IsA("BasePart") then
				placeHolder.Transparency = 1
				placeHolder.CanCollide = false
			end

			if placePrompt and placePrompt:IsA("BasePart") then
				placePrompt.Transparency = 1
				placePrompt.CanCollide = false
			end
		end
	end
end

-- Setup base floors based on upgrade level
local function setupBaseFloors(base, upgradeLevel)
	local floors = base:FindFirstChild("Floors")
	if not floors then return end

	local floor1 = floors:FindFirstChild("Floor1")
	local floor2 = floors:FindFirstChild("Floor2")
	local floor3 = floors:FindFirstChild("Floor3")

	-- Helper function to set floor visibility
	local function setFloorVisibility(floor, visible)
		if not floor then return end

		-- Set Floors parts
		local floorsParts = floor:FindFirstChild("Floors")
		if floorsParts then
			for _, part in pairs(floorsParts:GetDescendants()) do
				if part:IsA("BasePart") then
					if visible then
						part.Transparency = 0
						part.CanCollide = true
					else
						part.Transparency = 1
						part.CanCollide = false
					end
				end
			end
		end

		-- Set Supports, Ladder, OuterLines
		for _, folderName in pairs({"Supports", "Ladder", "OuterLines"}) do
			local folder = floor:FindFirstChild(folderName)
			if folder then
				for _, part in pairs(folder:GetDescendants()) do
					if part:IsA("BasePart") then
						if visible then
							part.Transparency = 0
							part.CanCollide = true
						else
							part.Transparency = 1
							part.CanCollide = false
						end
					end
				end
			end
		end
	end

	-- Floor visibility based on slots
	-- Floor1 (Slots 1-10): Always visible since everyone starts with 10 slots
	setFloorVisibility(floor1, true)

	-- Floor2 (Slots 11-20): Only visible if player has unlocked 11+ slots (upgrade level 1+)
	local hasFloor2Slots = (10 + upgradeLevel) >= 11
	setFloorVisibility(floor2, hasFloor2Slots)

	-- Floor3 (Slots 21-30): Only visible if player has unlocked 21+ slots (upgrade level 11+)
	local hasFloor3Slots = (10 + upgradeLevel) >= 21
	setFloorVisibility(floor3, hasFloor3Slots)
end

-- Setup player title (avatar face)
local function setupBaseTitle(base, player)
	local title = base:FindFirstChild("Title")
	if not title then return end

	local titleGui = title:FindFirstChild("TitleGui")
	if not titleGui then return end

	local frame = titleGui:FindFirstChild("Frame")
	if not frame then return end

	-- Set player icon (avatar thumbnail)
	local playerIcon = frame:FindFirstChild("PlayerIcon")
	if playerIcon and playerIcon:IsA("ImageLabel") then
		local userId = player.UserId
		local thumbType = Enum.ThumbnailType.HeadShot
		local thumbSize = Enum.ThumbnailSize.Size150x150
		local content, isReady = Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)
		playerIcon.Image = content
	end

	-- Set player name
	local playerName = frame:FindFirstChild("PlayerName")
	if playerName and playerName:IsA("TextLabel") then
		playerName.Text = player.Name
	end
end

-- Setup home icon (only visible to owner when far from base)
local function setupHomeIcon(base, player)
	local home = base:FindFirstChild("Home")
	if not home then return end

	local homeGui = home:FindFirstChild("HomeGui")
	if not homeGui then return end

	local icon = homeGui:FindFirstChild("Icon")
	if not icon then return end

	-- Initially hide the icon
	icon.Enabled = false

	-- Monitor distance from base
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not player or not player.Parent then
			connection:Disconnect()
			return
		end

		local character = player.Character
		if not character then
			icon.Enabled = false
			return
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			icon.Enabled = false
			return
		end

		-- Calculate distance from base
		local distance = (humanoidRootPart.Position - home.Position).Magnitude

		-- Show icon only if player is far enough from home
		icon.Enabled = distance >= HOME_ICON_DISTANCE
	end)

	-- Cleanup when player leaves
	player.AncestryChanged:Connect(function()
		if not player.Parent then
			connection:Disconnect()
		end
	end)
end

-- Find an available base
function BaseManager:FindAvailableBase()
	-- First, rebuild claimedBases from all online players
	for _, onlinePlayer in ipairs(Players:GetPlayers()) do
		local theirBaseNumber = onlinePlayer:GetAttribute("BaseNumber")
		if theirBaseNumber then
			claimedBases[theirBaseNumber] = onlinePlayer.UserId
		end
	end

	-- Collect all available bases
	local availableBases = {}
	for i = 1, MAX_BASES do
		if not claimedBases[i] then
			-- Double-check no other player has this base
			local baseTaken = false
			for _, onlinePlayer in ipairs(Players:GetPlayers()) do
				if onlinePlayer:GetAttribute("BaseNumber") == i then
					baseTaken = true
					break
				end
			end

			if not baseTaken then
				table.insert(availableBases, i)
			end
		end
	end

	-- Return random available base instead of first one
	if #availableBases > 0 then
		return availableBases[math.random(1, #availableBases)]
	end

	return nil -- No available bases
end

-- Claim a base for a player
function BaseManager:ClaimBase(player, baseNumber)
	-- Check if another online player already has this base
	for _, onlinePlayer in ipairs(Players:GetPlayers()) do
		if onlinePlayer ~= player and onlinePlayer:GetAttribute("BaseNumber") == baseNumber then
			warn("Base", baseNumber, "is already claimed by", onlinePlayer.Name)
			return false
		end
	end

	if claimedBases[baseNumber] and claimedBases[baseNumber] ~= player.UserId then
		warn("Base", baseNumber, "is already claimed!")
		return false
	end

	local baseName = "Base" .. baseNumber
	local base = BASES_FOLDER:FindFirstChild(baseName)

	if not base then
		warn("Base", baseName, "not found in Workspace!")
		return false
	end

	-- CRITICAL FIX: Force cleanup all slots BEFORE claiming to prevent stale data
	-- This ensures slots are empty even if previous player's cleanup failed
	local slotsFolder = base:FindFirstChild("Slots")
	if slotsFolder then
		for _, slot in ipairs(slotsFolder:GetChildren()) do
			if slot:IsA("Model") and slot.Name:match("^Slot") then
				-- Reset ALL slot attributes to default
				slot:SetAttribute("Occupied", false)
				slot:SetAttribute("PlacedThingName", nil)
				slot:SetAttribute("PlacedThingMutation", nil)
				slot:SetAttribute("UpgradeLevel", 0)
				slot:SetAttribute("AccumulatedMoney", 0)
				slot:SetAttribute("OwnerUserId", nil)
				
				-- Remove any placed things
				local baseModel = slot:FindFirstChild("Base")
				if baseModel then
					local placeHolder = baseModel:FindFirstChild("PlaceHolder")
					if placeHolder then
						for _, child in ipairs(placeHolder:GetChildren()) do
							if child:IsA("Model") then
								pcall(function() child:Destroy() end)
							end
						end
					end
				end
			end
		end
		print("[BaseManager] Force-cleaned all slots in Base", baseNumber, "before claiming")
	end

	-- Claim the base
	claimedBases[baseNumber] = player.UserId
	player:SetAttribute("BaseNumber", baseNumber)

	-- Setup base with player's upgrade level
	local upgradeLevel = player:GetAttribute("BaseUpgradeLevel") or 0
	-- Don't call initializeSlots here - SetupPlayerSlots and LoadPlacedThings handle everything
	setupBaseFloors(base, upgradeLevel)
	setupBaseTitle(base, player)
	setupHomeIcon(base, player)

	print("Claimed Base" .. baseNumber .. " for " .. player.Name .. " with upgrade level " .. upgradeLevel)

	return true
end

-- Setup player's spawn point at their base
function BaseManager:SetupSpawn(player)
	local baseNumber = player:GetAttribute("BaseNumber")
	if not baseNumber then return end

	local baseName = "Base" .. baseNumber
	local base = BASES_FOLDER:FindFirstChild(baseName)
	if not base then return end

	local spawn = base:FindFirstChild("Spawn")
	if not spawn then return end

	-- Teleport player to their base spawn
	local character = player.Character
	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			humanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
end

-- Upgrade base (unlock new floors)
function BaseManager:UpgradeBase(player)
	local baseNumber = player:GetAttribute("BaseNumber")
	if not baseNumber then
		warn("Player doesn't own a base!")
		return false
	end

	local upgradeLevel = player:GetAttribute("BaseUpgradeLevel") or 0

	if upgradeLevel >= 20 then
		warn("Base already at max upgrade level!")
		return false
	end

	-- Increment upgrade level
	upgradeLevel = upgradeLevel + 1
	player:SetAttribute("BaseUpgradeLevel", upgradeLevel)

	-- Update floor visibility (BaseUpgrade.unlockSlot handles the new slot)
	local baseName = "Base" .. baseNumber
	local base = BASES_FOLDER:FindFirstChild(baseName)
	if base then
		setupBaseFloors(base, upgradeLevel)
	end

	return true
end

-- Initialize player's base on join
function BaseManager:InitializePlayerBase(player)
	local baseNumber = player:GetAttribute("BaseNumber")

	-- TESTING MODE: Force random base assignment
	if FORCE_RANDOM_BASE then
		print("[TESTING] Forcing random base for", player.Name)
		local availableBase = self:FindAvailableBase()
		if availableBase then
			player:SetAttribute("BaseNumber", availableBase)
			self:ClaimBase(player, availableBase)
			print("[TESTING]", player.Name, "assigned to Base", availableBase)

			-- Teleport to the new random base immediately
			task.wait(0.5)
			self:SetupSpawn(player)
		else
			warn("No available bases for", player.Name)
		end
		return
	end

	-- If player doesn't have a base, try to claim one
	if not baseNumber then
		local availableBase = self:FindAvailableBase()
		if availableBase then
			self:ClaimBase(player, availableBase)
		else
			warn("No available bases for", player.Name)
		end
	else
		-- Player has a saved base number, but check if it's available
		local baseIsTaken = false
		local takenByPlayer = nil

		-- Check if any other online player is using this base
		for _, onlinePlayer in ipairs(Players:GetPlayers()) do
			if onlinePlayer ~= player and onlinePlayer:GetAttribute("BaseNumber") == baseNumber then
				baseIsTaken = true
				takenByPlayer = onlinePlayer
				break
			end
		end

		if baseIsTaken then
			-- Their saved base is taken, find them a new one
			warn(player.Name, "'s saved base", baseNumber, "is taken by", takenByPlayer.Name, "- finding new base")
			local availableBase = self:FindAvailableBase()
			if availableBase then
				-- Update BaseNumber attribute so the system uses the new base
				player:SetAttribute("BaseNumber", availableBase)
				self:ClaimBase(player, availableBase)
				print("[BaseReassign] Reassigned", player.Name, "to Base", availableBase, "- PlacedThings will be loaded by PlayerSetup")

				-- Teleport player to new base spawn
				task.wait(0.5)
				self:SetupSpawn(player)

				-- LoadPlacedThings will be called by PlayerSetup and will restore items to the new base
				-- The new BaseNumber will be saved to DataStore on next auto-save or when player leaves
			else
				warn("No available bases for", player.Name)
			end
		else
			-- Base is available, reclaim it using ClaimBase (which force-cleans slots)
			self:ClaimBase(player, baseNumber)
			
			-- Setup base with player's upgrade level
			local baseName = "Base" .. baseNumber
			local base = BASES_FOLDER:FindFirstChild(baseName)
			if base then
				local upgradeLevel = player:GetAttribute("BaseUpgradeLevel") or 0
				-- Don't call initializeSlots here - it will run before LoadPlacedThings
				-- and wipe occupied slots since attributes aren't set yet
				-- SetupPlayerSlots and LoadPlacedThings will handle everything properly
				setupBaseFloors(base, upgradeLevel)
				setupBaseTitle(base, player)
				setupHomeIcon(base, player)
				print("Reclaimed Base" .. baseNumber .. " for " .. player.Name .. " (force-cleaned slots)")
			end
		end
	end

	-- Listen for upgrade level changes to update slots dynamically
	player:GetAttributeChangedSignal("BaseUpgradeLevel"):Connect(function()
		local currentBaseNumber = player:GetAttribute("BaseNumber")
		if currentBaseNumber then
			local baseName = "Base" .. currentBaseNumber
			local base = BASES_FOLDER:FindFirstChild(baseName)
			if base then
				local upgradeLevel = player:GetAttribute("BaseUpgradeLevel") or 0
				-- Only update floors, NOT slots (BaseUpgrade.unlockSlot handles the new slot)
				setupBaseFloors(base, upgradeLevel)
			end
		end
	end)
end

-- Cleanup when player leaves
function BaseManager:CleanupPlayer(player)
	local baseNumber = player:GetAttribute("BaseNumber")
	if baseNumber then
		-- ALWAYS unclaim the base when player leaves, regardless of claimedBases state
		-- (claimedBases can be out of sync due to errors/disconnects)
		claimedBases[baseNumber] = nil

		-- Clear the title and remove all physical things from slots
		local baseName = "Base" .. baseNumber
		local base = BASES_FOLDER:FindFirstChild(baseName)
		if base then
			-- Clear title display
			local title = base:FindFirstChild("Title")
			if title then
				local titleGui = title:FindFirstChild("TitleGui")
				if titleGui then
					local frame = titleGui:FindFirstChild("Frame")
					if frame then
						local playerIcon = frame:FindFirstChild("PlayerIcon")
						if playerIcon then
							playerIcon.Image = ""
						end
						local playerName = frame:FindFirstChild("PlayerName")
						if playerName then
							playerName.Text = ""
						end
					end
				end
			end

			-- Remove all physical things from slots and reset attributes
			local slotsFolder = base:FindFirstChild("Slots")
			if slotsFolder then
				for _, slot in ipairs(slotsFolder:GetChildren()) do
					if slot:IsA("Model") and slot.Name:match("^Slot") then
						-- Reset slot attributes
						slot:SetAttribute("Occupied", false)
						slot:SetAttribute("PlacedThingName", nil)
						slot:SetAttribute("PlacedThingMutation", nil)
						slot:SetAttribute("UpgradeLevel", 0)
						slot:SetAttribute("AccumulatedMoney", 0)
						slot:SetAttribute("OwnerUserId", nil)

						-- Clear Collect money display text
						local collect = slot:FindFirstChild("Collect")
						if collect then
							for _, desc in ipairs(collect:GetDescendants()) do
								if desc:IsA("TextLabel") and desc.Name == "Money" then
									desc.Text = ""
								end
							end
						end

						local baseModel = slot:FindFirstChild("Base")
						if baseModel then
							local placeHolder = baseModel:FindFirstChild("PlaceHolder")
							if placeHolder then
								-- Destroy any placed thing
								local thing = placeHolder:FindFirstChildOfClass("Model")
								if thing then
								local thingName = thing.Name
								local success, err = pcall(function()
									thing:Destroy()
								end)
								if not success then
									warn("[BaseManager] Failed to destroy", thingName, "in", slot.Name, "Error:", err)
								else
									print("[BaseManager] Destroyed", thingName, "from", slot.Name, "for", player.Name)
								end
								end
							end
						end

						-- Hide upgrade part
						local upgrade = slot:FindFirstChild("Upgrade")
						if upgrade then
							upgrade.Transparency = 1
							local upgradeGui = upgrade:FindFirstChild("SurfaceGui")
							if upgradeGui then
								upgradeGui.Enabled = false
							end
						end
					end
				end
			end

			-- NOW reset base to default state (10 slots, Floor 1 only) AFTER destroying all items
			initializeSlots(base, 0)
			setupBaseFloors(base, 0)
		end

		-- Additional safety check: Destroy any items in workspace with this player's OwnerId
		local destroyedCount = 0
		for _, folder in ipairs({Workspace:FindFirstChild("ActiveThings"), Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Things")}) do
			if folder then
				for _, item in ipairs(folder:GetChildren()) do
					if item:IsA("Model") and item:GetAttribute("OwnerId") == player.UserId then
						local itemName = item.Name
						item:Destroy()
						destroyedCount = destroyedCount + 1
						warn("[BaseManager] Found and destroyed stray item:", itemName, "with OwnerId", player.UserId)
					end
				end
			end
		end
		if destroyedCount > 0 then
			warn("[BaseManager] Destroyed", destroyedCount, "stray items for", player.Name, "that weren't in slots!")
		end

		print("Cleaned up Base" .. baseNumber .. " for " .. player.Name)

		-- Clear slot data from BaseSlotManager (after save completes)
		local ServerScriptService = game:GetService("ServerScriptService")
		local success, BaseSlotManager = pcall(function()
			return require(ServerScriptService.Things.BaseSlotManager)
		end)
		if success and BaseSlotManager and BaseSlotManager.ClearPlayerSlots then
			BaseSlotManager.ClearPlayerSlots(player)
		end

		-- Clear inventory cache from ThingInventoryManager (after save completes)
		local success2, ThingInventoryManager = pcall(function()
			return require(ServerScriptService.Things.ThingInventoryManager)
		end)
		if success2 and ThingInventoryManager and ThingInventoryManager.ClearInventoryCache then
			ThingInventoryManager.ClearInventoryCache(player)
		end
	end
end

-- Export function to initialize a single slot (used by BaseUpgrade)
function BaseManager:InitializeSingleSlot(slot)
	initializeSingleSlot(slot)
end

return BaseManager
