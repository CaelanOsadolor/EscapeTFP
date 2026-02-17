-- ThingInventoryManager.lua
-- Manages player inventory of collected things
-- Place in: ServerScriptService/Things/
--
-- SECURITY NOTES:
-- - Rate values are ALWAYS calculated server-side (never from GUI)
-- - GuiData only stores COSMETIC properties (colors, mutation display text)
-- - All gameplay values (Rate, Name, Rarity, Mutation) come from server authority
-- - Uses SaveManager for persistence (single DataStore: "PlayerData_V1")
-- - Auto-saves every 60 seconds + on player leave + BindToClose
-- - Backwards compatible with old saves (adds missing fields)

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsService = game:GetService("PhysicsService")

local ThingInventoryManager = {}

-- Get SaveManager reference (single source of truth for all saves)
local SaveManager = require(ServerScriptService.GameManager.SaveManager)

local playerInventories = {} -- Cache of player inventories (in-memory for fast access)

local MAX_INVENTORY = 100 -- Maximum items a player can have

-- Load player's inventory from SaveManager (single source of truth)
local function LoadInventory(player)
	-- Get data from SaveManager
	local data = SaveManager:LoadData(player)

	if data and data.OwnedItems then
		-- Handle backwards compatibility - add missing fields
		for _, item in ipairs(data.OwnedItems) do
			if not item.Rate then
				item.Rate = 0
			end
			if not item.Mutation then
				item.Mutation = ""
			end
			if not item.GuiData then
				item.GuiData = {} -- Empty table for old items
			end
			if not item.UpgradeLevel then
				item.UpgradeLevel = 0 -- Default upgrade level for old items
			end
		end

		playerInventories[player.UserId] = data.OwnedItems
	else
		-- New player
		playerInventories[player.UserId] = {}
	end

	return playerInventories[player.UserId]
end

-- Add a thing to player's inventory and create Tool in Backpack
function ThingInventoryManager.AddToInventory(player, thingName, mutation, rarity, rate, guiData, upgradeLevel)
	local inventory = playerInventories[player.UserId]
	if not inventory then return false, "No inventory found" end

	-- Check capacity
	if #inventory >= MAX_INVENTORY then
		return false, "Inventory full! (Max: " .. MAX_INVENTORY .. ")"
	end

	-- Add item to inventory with all data including rate and upgrade level
	local itemData = {
		Name = thingName,
		Mutation = mutation or "",  -- Empty string instead of "None"
		Rarity = rarity or "Common",
		Rate = rate or 0, -- Money generation rate ($/sec)
		UpgradeLevel = upgradeLevel or 0, -- Upgrade level from slot
		Timestamp = os.time(),
		GuiData = guiData or {} -- Store GUI appearance data (colors, text, etc.)
	}

	table.insert(inventory, itemData)

	-- Get the index of the newly added item
	local itemIndex = #inventory

	-- Create Tool in player's Backpack
	CreateToolFromItem(player, itemData, itemIndex)

	-- Display name: "Mutation Name" or just "Name"
	local displayName = thingName
	if mutation and mutation ~= "" then
		displayName = mutation .. " " .. thingName
	end
	return true
end

-- Create a Tool from item data and add to Backpack
function CreateToolFromItem(player, itemData, itemIndex)
	-- Ensure CarriedThings collision group exists
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered("CarriedThings") then
			PhysicsService:RegisterCollisionGroup("CarriedThings")
			PhysicsService:CollisionGroupSetCollidable("CarriedThings", "Default", false)
		end
	end)

	local tool = Instance.new("Tool")

	-- Set tool name (Mutation + Name or just Name)
	local displayName = itemData.Name
	local hasMutation = itemData.Mutation and itemData.Mutation ~= ""
	if hasMutation then
		displayName = itemData.Mutation .. " " .. itemData.Name
	end
	tool.Name = displayName
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	-- Store data as attributes
	tool:SetAttribute("ThingName", itemData.Name)
	tool:SetAttribute("Mutation", itemData.Mutation)
	tool:SetAttribute("Rarity", itemData.Rarity)
	tool:SetAttribute("Rate", itemData.Rate or 0)
	tool:SetAttribute("UpgradeLevel", itemData.UpgradeLevel or 0)
	tool:SetAttribute("Timestamp", itemData.Timestamp)
	tool:SetAttribute("InventoryIndex", itemIndex) -- Track position in inventory

	-- Find and clone the actual thing model from ServerStorage
	local thingsFolder = ServerStorage:FindFirstChild("Things")
	if thingsFolder then
		-- Search all rarity folders for the thing
		local thingTemplate = nil
		for _, rarityFolder in pairs(thingsFolder:GetChildren()) do
			if rarityFolder:IsA("Folder") then
				local foundThing = rarityFolder:FindFirstChild(itemData.Name)
				if foundThing then
					thingTemplate = foundThing
					break
				end
			end
		end

		if thingTemplate then
			-- Clone the actual thing model
			local thingClone = thingTemplate:Clone()

			-- Apply mutation attribute first (before visual effects)
			if itemData.Mutation and itemData.Mutation ~= "" then
				thingClone:SetAttribute("Mutation", itemData.Mutation)

				-- Apply visual mutation effects
				local MutationEffects = require(script.Parent.MutationEffects)
				MutationEffects.ApplyEffects(thingClone)
			end

			-- Remove timer GUI and proximity prompts (like carry script)
			for _, desc in pairs(thingClone:GetDescendants()) do
				if desc:IsA("BillboardGui") and desc.Name == "TimerGui" then
					desc:Destroy()
				elseif desc:IsA("ProximityPrompt") then
					desc:Destroy()
				end
			end

			-- Apply saved GUI properties from GuiData
			local guiData = itemData.GuiData or {}

			-- Setup BillboardGui mutation label (hide if no mutation)
			for _, desc in pairs(thingClone:GetDescendants()) do
				if desc:IsA("BillboardGui") then
					local mutationLabel = desc:FindFirstChild("MutationLabel")
					if mutationLabel and mutationLabel:IsA("TextLabel") then
						if itemData.Mutation and itemData.Mutation ~= "" then
							-- Has mutation - show it
							mutationLabel.Text = itemData.Mutation
							mutationLabel.Visible = true
							-- Get color from MutationEffects
							local MutationEffects = require(script.Parent.MutationEffects)
							mutationLabel.TextColor3 = MutationEffects.GetMutationColor(itemData.Mutation)
						else
							-- No mutation - hide label
							mutationLabel.Visible = false
						end
					end
				end
			end

			-- Restore StatsGui properties from GuiData
			local handle = thingClone:FindFirstChild("Handle")
			if handle then
				local statsGui = handle:FindFirstChild("StatsGui")
				if statsGui then
					local frame = statsGui:FindFirstChild("Frame")
					if frame then
						-- Restore Name label (text from itemData, color from guiData)
						local nameLabel = frame:FindFirstChild("Name")
						if nameLabel and itemData.Name then
							nameLabel.Text = itemData.Name -- Always use authoritative data
							
							-- Special styling for Love Ram name label
							if itemData.Name == "Love Ram" then
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
							elseif guiData.NameColor then
								nameLabel.TextColor3 = Color3.new(guiData.NameColor[1], guiData.NameColor[2], guiData.NameColor[3])
							end
						end

						-- Restore Class label (text from itemData, color from guiData)
						local classLabel = frame:FindFirstChild("Class")
						if classLabel and itemData.Rarity then
							classLabel.Text = itemData.Rarity -- Always use authoritative rarity

							-- Apply rarity color (same as spawner)
							if itemData.Rarity == "Common" then
								classLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
							elseif itemData.Rarity == "Uncommon" then
								classLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
							elseif itemData.Rarity == "Rare" then
								classLabel.TextColor3 = Color3.fromRGB(0, 112, 221)
							elseif itemData.Rarity == "Epic" then
								classLabel.TextColor3 = Color3.fromRGB(163, 53, 238)
							elseif itemData.Rarity == "Legendary" then
								classLabel.TextColor3 = Color3.fromRGB(255, 128, 0)
							elseif itemData.Rarity == "Mythical" then
								classLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
							elseif itemData.Rarity == "Divine" then
								classLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
							elseif itemData.Rarity == "Secret" then
								classLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
								-- Add white UIStroke for Secret
								local uiStroke = classLabel:FindFirstChildOfClass("UIStroke")
								if not uiStroke then
									uiStroke = Instance.new("UIStroke")
									uiStroke.Parent = classLabel
								end
								uiStroke.Color = Color3.fromRGB(255, 255, 255)
								uiStroke.Thickness = 1
							elseif itemData.Rarity == "Celestial" then
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
							elseif itemData.Rarity == "Limited" then
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

							-- Override with saved color if available
							if guiData.ClassColor then
								classLabel.TextColor3 = Color3.new(guiData.ClassColor[1], guiData.ClassColor[2], guiData.ClassColor[3])
							end
						end

						-- Restore Rate label - ALWAYS use itemData.Rate (server-calculated, exploit-proof)
						local rateLabel = frame:FindFirstChild("Rate")
						if rateLabel and itemData.Rate then
							-- SECURITY: Always calculate from server-side Rate value
							-- Format with extended suffixes matching MoneySpeedDisplay
							local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
							local tier = 1
							local num = itemData.Rate

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

						-- Restore Mutation label in StatsGui
						local mutLabel = frame:FindFirstChild("Mutation")
						if mutLabel then
							if itemData.Mutation and itemData.Mutation ~= "" then
								-- Has mutation - show it
								mutLabel.Text = itemData.Mutation
								mutLabel.Visible = true
								-- Color the mutation text
								local MutationEffects = require(script.Parent.MutationEffects)
								mutLabel.TextColor3 = MutationEffects.GetMutationColor(itemData.Mutation)
							else
								-- No mutation - hide label
								mutLabel.Visible = false
							end
						end
					end
				end
			end

			-- If it's a Model, set the PrimaryPart as Handle or find a main part
			if thingClone:IsA("Model") then
				-- Find or create a handle part
				local handlePart = thingClone.PrimaryPart or thingClone:FindFirstChildWhichIsA("BasePart")
				if handlePart then
					handlePart.Name = "Handle"

					-- Apply physics settings to all parts (exact same as carry system)
					for _, part in pairs(thingClone:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Anchored = false
							part.CanCollide = false
							part.CanTouch = false
							part.CanQuery = false
							part.Massless = true
							-- Set custom physical properties for true weightless feel
							part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)
							-- Use same collision group as carry system
							pcall(function()
								part.CollisionGroup = "CarriedThings"
							end)
							-- Set network ownership to player for smooth physics
							pcall(function()
								part:SetNetworkOwner(player)
							end)
						end
					end

					-- Weld all parts to handle
					for _, part in pairs(thingClone:GetDescendants()) do
						if part:IsA("BasePart") and part ~= handlePart then
							local weld = Instance.new("WeldConstraint")
							weld.Part0 = handlePart
							weld.Part1 = part
							weld.Parent = handlePart
						end
					end

					-- Parent model contents to tool
					for _, child in pairs(thingClone:GetChildren()) do
						child.Parent = tool
					end
				end
			else
				-- It's a single part - apply exact same physics as carry system
				thingClone.Name = "Handle"
				thingClone.Anchored = false
				thingClone.CanCollide = false
				thingClone.CanTouch = false
				thingClone.CanQuery = false
				thingClone.Massless = true
				-- Set custom physical properties for true weightless feel
				thingClone.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)
				pcall(function()
					thingClone.CollisionGroup = "CarriedThings"
				end)
				-- Set network ownership to player for smooth physics
				pcall(function()
					thingClone:SetNetworkOwner(player)
				end)
				thingClone.Parent = tool
			end

			-- Remove certain attributes from the cloned thing (prevent pickup conflicts)
			for _, desc in pairs(tool:GetDescendants()) do
				if desc:GetAttribute("Rarity") then
					desc:SetAttribute("Rarity", nil)
				end
				if desc:GetAttribute("IsPickedUp") then
					desc:SetAttribute("IsPickedUp", nil)
				end
				if desc:GetAttribute("SpawnTime") then
					desc:SetAttribute("SpawnTime", nil)
				end
			end
		else
			-- Fallback: create invisible handle if template not found
			warn("[ThingInventory] Template not found for", itemData.Name)
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(1, 1, 1)
			handle.Transparency = 1
			handle.CanCollide = false
			handle.Parent = tool
		end
	end

	-- CRITICAL: Add Equipped event to enforce physics when tool is held
	-- Roblox's Tool system can override physics properties when equipped
	tool.Equipped:Connect(function()
		task.wait() -- Small delay to let Tool system finish
		-- Force all parts to stay non-collidable
		for _, part in pairs(tool:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
				part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)
				pcall(function()
					part.CollisionGroup = "CarriedThings"
				end)
			end
		end
	end)

	-- Add to player's Backpack
	tool.Parent = player:WaitForChild("Backpack")

	return tool
end

-- Get player's inventory
function ThingInventoryManager.GetInventory(player)
	return playerInventories[player.UserId] or {}
end

-- Get inventory count
function ThingInventoryManager.GetInventoryCount(player)
	local inventory = playerInventories[player.UserId]
	return inventory and #inventory or 0
end

-- Check if player can collect more
function ThingInventoryManager.CanCollect(player)
	local count = ThingInventoryManager.GetInventoryCount(player)
	return count < MAX_INVENTORY, count, MAX_INVENTORY
end

-- Remove item from inventory (for placing/selling later)
function ThingInventoryManager.RemoveFromInventory(player, index)
	local inventory = playerInventories[player.UserId]
	if not inventory or not inventory[index] then return false end

	local item = table.remove(inventory, index)
	return true, item
end

-- Update Rate for an item (for upgrades)
function ThingInventoryManager.UpdateItemRate(player, itemIndex, newRate)
	local inventory = playerInventories[player.UserId]
	if not inventory or not inventory[itemIndex] then return false end

	inventory[itemIndex].Rate = newRate

	-- Update the Tool in backpack if it exists
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local toolIndex = tool:GetAttribute("InventoryIndex")
				if toolIndex == itemIndex then
					tool:SetAttribute("Rate", newRate)
					-- Update the Rate label in StatsGui
					local handle = tool:FindFirstChild("Handle")
					if handle then
						local statsGui = handle:FindFirstChild("StatsGui")
						if statsGui then
							local frame = statsGui:FindFirstChild("Frame")
							if frame then
								local rateLabel = frame:FindFirstChild("Rate")
								if rateLabel then
									rateLabel.Text = "$" .. tostring(newRate) .. "/sec"
								end
							end
						end
					end
					break
				end
			end
		end
	end

	return true
end

-- Setup player
local function OnPlayerAdded(player)
	-- Load inventory FIRST (priority)
	LoadInventory(player)

	-- Function to restore tools to backpack
	local function RestoreInventoryTools()
		local inventory = playerInventories[player.UserId]
		if inventory then
			for i, itemData in ipairs(inventory) do
				CreateToolFromItem(player, itemData, i) -- Pass index
			end
		end
	end

	-- Wait for character to fully load
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local backpack = player:WaitForChild("Backpack")

	-- Wait for character to be fully loaded and ready
	if humanoid.Health == 0 then
		humanoid.Died:Wait()
		character = player.CharacterAdded:Wait()
		humanoid = character:WaitForChild("Humanoid")
	end

	-- Additional small wait for laggy connections
	task.wait(0.5)

	-- Restore Tools from saved inventory (first spawn)
	RestoreInventoryTools()

	-- Restore tools on every respawn (when player resets/dies)
	player.CharacterAdded:Connect(function()
		task.wait(0.5) -- Wait for backpack to be ready
		RestoreInventoryTools()
	end)

	-- Note: Auto-save handled by SaveManager (every 3 minutes)
end

-- Initialize
function ThingInventoryManager.Init()
	-- Setup existing players
	for _, player in ipairs(Players:GetPlayers()) do
		OnPlayerAdded(player)
	end

	-- Setup future players
	Players.PlayerAdded:Connect(OnPlayerAdded)

	-- Note: PlayerRemoving cleanup handled by BaseManager after save completes
	-- Note: BindToClose save handled by SaveManager
end

-- Remove item from inventory by index (used when placing in slot)
function ThingInventoryManager.RemoveFromInventoryByIndex(player, itemIndex)
	local inventory = playerInventories[player.UserId]
	if not inventory then return false end

	-- Remove the item at this index
	table.remove(inventory, itemIndex)

	-- Refresh all tools in backpack to update indices
	ThingInventoryManager.RefreshInventoryTools(player)

	-- Note: Save handled by SaveManager autosave (every 3 minutes) or on leave

	return true
end

-- Refresh all inventory tools (used after removing items)
function ThingInventoryManager.RefreshInventoryTools(player)
	local inventory = playerInventories[player.UserId]
	if not inventory then return end

	-- Clear backpack
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("InventoryIndex") then
				tool:Destroy()
			end
		end
	end

	-- Clear equipped tool
	local character = player.Character
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("InventoryIndex") then
				tool:Destroy()
			end
		end
	end

	-- Recreate all tools with correct indices
	for i, itemData in ipairs(inventory) do
		CreateToolFromItem(player, itemData, i)
	end
end

-- Clear entire inventory (used for rebirth)
function ThingInventoryManager.ClearInventory(player)
	-- Clear in-memory inventory
	playerInventories[player.UserId] = {}

	-- Clear all inventory tools from backpack
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("InventoryIndex") then
				tool:Destroy()
			end
		end
	end

	-- Clear equipped inventory tool
	local character = player.Character
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("InventoryIndex") then
				tool:Destroy()
			end
		end
	end

	-- Note: StarterPack tools (permanent tools) are not touched
end

-- Clear player inventory cache (called by BaseManager after save completes)
function ThingInventoryManager.ClearInventoryCache(player)
	playerInventories[player.UserId] = nil
	print("[ThingInventory] Cleared inventory cache for", player.Name)
end

return ThingInventoryManager
