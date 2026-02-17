-- ThingInteractionHandler.lua (LocalScript)
-- Handles player interactions with things (pickup, place, drop)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- UI Elements
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ThingInteractionUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Create interaction hint
local interactionFrame = Instance.new("Frame")
interactionFrame.Name = "InteractionFrame"
interactionFrame.Size = UDim2.new(0, 300, 0, 120)
interactionFrame.Position = UDim2.new(0.5, -150, 0.8, -60)
interactionFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
interactionFrame.BackgroundTransparency = 0.3
interactionFrame.BorderSizePixel = 0
interactionFrame.Visible = false
interactionFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = interactionFrame

-- Thing name
local thingNameLabel = Instance.new("TextLabel")
thingNameLabel.Name = "ThingName"
thingNameLabel.Size = UDim2.new(1, -20, 0, 25)
thingNameLabel.Position = UDim2.new(0, 10, 0, 5)
thingNameLabel.BackgroundTransparency = 1
thingNameLabel.Text = "Common Thing"
thingNameLabel.TextColor3 = Color3.new(1, 1, 1)
thingNameLabel.TextScaled = true
thingNameLabel.Font = Enum.Font.SourceSansBold
thingNameLabel.Parent = interactionFrame

-- Thing info
local thingInfoLabel = Instance.new("TextLabel")
thingInfoLabel.Name = "ThingInfo"
thingInfoLabel.Size = UDim2.new(1, -20, 0, 40)
thingInfoLabel.Position = UDim2.new(0, 10, 0, 30)
thingInfoLabel.BackgroundTransparency = 1
thingInfoLabel.Text = "Passive: $50/min\nSell Value: $3,000"
thingInfoLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
thingInfoLabel.TextSize = 16
thingInfoLabel.Font = Enum.Font.SourceSans
thingInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
thingInfoLabel.Parent = interactionFrame

-- Action hint
local actionLabel = Instance.new("TextLabel")
actionLabel.Name = "ActionLabel"
actionLabel.Size = UDim2.new(1, -20, 0, 30)
actionLabel.Position = UDim2.new(0, 10, 1, -35)
actionLabel.BackgroundTransparency = 1
actionLabel.Text = "[E] Pick Up"
actionLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
actionLabel.TextScaled = true
actionLabel.Font = Enum.Font.SourceSansBold
actionLabel.Parent = interactionFrame

-- Carry capacity display
local carryDisplay = Instance.new("TextLabel")
carryDisplay.Name = "CarryDisplay"
carryDisplay.Size = UDim2.new(0, 200, 0, 30)
carryDisplay.Position = UDim2.new(0, 10, 0, 10)
carryDisplay.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
carryDisplay.BackgroundTransparency = 0.3
carryDisplay.BorderSizePixel = 0
carryDisplay.Text = "Carrying: 0/1"
carryDisplay.TextColor3 = Color3.new(1, 1, 1)
carryDisplay.TextScaled = true
carryDisplay.Font = Enum.Font.SourceSansBold
carryDisplay.Visible = false
carryDisplay.Parent = screenGui

local carryCorner = Instance.new("UICorner")
carryCorner.CornerRadius = UDim.new(0, 8)
carryCorner.Parent = carryDisplay

-- State
local nearbyThing = nil
local nearbySlot = nil
local canInteract = true

-- Remote events (create these in ReplicatedStorage)
local pickupEvent = ReplicatedStorage:FindFirstChild("PickupThing")
local placeEvent = ReplicatedStorage:FindFirstChild("PlaceThing")
local dropEvent = ReplicatedStorage:FindFirstChild("DropThing")

if not pickupEvent then
	pickupEvent = Instance.new("RemoteEvent")
	pickupEvent.Name = "PickupThing"
	pickupEvent.Parent = ReplicatedStorage
end

if not placeEvent then
	placeEvent = Instance.new("RemoteEvent")
	placeEvent.Name = "PlaceThing"
	placeEvent.Parent = ReplicatedStorage
end

if not dropEvent then
	dropEvent = Instance.new("RemoteEvent")
	dropEvent.Name = "DropThing"
	dropEvent.Parent = ReplicatedStorage
end

-- Get thing info from server
local getThingInfoFunc = ReplicatedStorage:FindFirstChild("GetThingInfo")
if not getThingInfoFunc then
	getThingInfoFunc = Instance.new("RemoteFunction")
	getThingInfoFunc.Name = "GetThingInfo"
	getThingInfoFunc.Parent = ReplicatedStorage
end

-- Update carry display
local function updateCarryDisplay()
	-- Get carry info from leaderstats or server
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local carryCapacity = leaderstats:FindFirstChild("CarryCapacity")
		if carryCapacity then
			-- We need to get current load from server
			-- For now, we'll just show capacity
			carryDisplay.Visible = true
			-- This should be updated via a RemoteEvent from server
		end
	end
end

-- Find nearby thing
local function findNearbyThing()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	
	local activeThings = Workspace:FindFirstChild("ActiveThings")
	if not activeThings then return nil end
	
	local closestThing = nil
	local closestDistance = 10 -- Max distance to interact
	
	for _, thing in ipairs(activeThings:GetChildren()) do
		if thing:IsA("Model") then
			local handle = thing:FindFirstChild("Handle")
			if handle then
				local distance = (rootPart.Position - handle.Position).Magnitude
				if distance < closestDistance then
					-- Check if thing is not picked up
					if not thing:GetAttribute("IsPickedUp") then
						closestDistance = distance
						closestThing = thing
					end
				end
			end
		end
	end
	
	return closestThing
end

-- Find nearby slot
local function findNearbySlot()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	
	local bases = Workspace:FindFirstChild("Bases")
	if not bases then return nil end
	
	local playerBase = bases:FindFirstChild(player.Name)
	if not playerBase then return nil end
	
	local slots = playerBase:FindFirstChild("Slots")
	if not slots then return nil end
	
	local closestSlot = nil
	local closestDistance = 8 -- Max distance to place
	
	for _, slot in ipairs(slots:GetChildren()) do
		if slot:IsA("BasePart") then
			local distance = (rootPart.Position - slot.Position).Magnitude
			if distance < closestDistance then
				-- Check if slot is empty
				local slotData = slot:FindFirstChild("SlotData")
				if slotData then
					local occupied = slotData:FindFirstChild("Occupied")
					if occupied and not occupied.Value then
						closestDistance = distance
						closestSlot = slot
					end
				end
			end
		end
	end
	
	return closestSlot
end

-- Update interaction UI
local function updateInteractionUI()
	nearbyThing = findNearbyThing()
	nearbySlot = findNearbySlot()
	
	if nearbyThing then
		-- Show thing info
		local success, info = pcall(function()
			return getThingInfoFunc:InvokeServer(nearbyThing)
		end)
		
		if success and info then
			thingNameLabel.Text = info.Name .. " [" .. info.Rarity .. "]"
			thingInfoLabel.Text = "Passive: " .. info.PassiveValue .. "\nSell Value: " .. info.SellValue
			actionLabel.Text = "[E] Pick Up"
			
			-- Color based on rarity
			local rarityColors = {
				Common = Color3.fromRGB(200, 200, 200),
				Uncommon = Color3.fromRGB(0, 255, 0),
				Rare = Color3.fromRGB(0, 150, 255),
				Epic = Color3.fromRGB(180, 0, 255),
				Legendary = Color3.fromRGB(255, 170, 0),
				Mythical = Color3.fromRGB(255, 0, 255),
				Cosmic = Color3.fromRGB(0, 255, 255),
				Secret = Color3.fromRGB(255, 215, 0)
			}
			thingNameLabel.TextColor3 = rarityColors[info.Rarity] or Color3.new(1, 1, 1)
		end
		
		interactionFrame.Visible = true
	elseif nearbySlot then
		-- Show place hint
		thingNameLabel.Text = "Place Thing Here"
		thingInfoLabel.Text = "Place carried things in slots to earn passive income"
		actionLabel.Text = "[E] Place Thing"
		interactionFrame.Visible = true
	else
		interactionFrame.Visible = false
	end
end

-- Handle input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not canInteract then return end
	
	if input.KeyCode == Enum.KeyCode.E then
		if nearbyThing then
			-- Pick up thing
			pickupEvent:FireServer(nearbyThing)
		elseif nearbySlot then
			-- Place thing
			placeEvent:FireServer(nearbySlot)
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		-- Drop all things
		dropEvent:FireServer()
	end
end)

-- Update loop
task.spawn(function()
	while task.wait(0.1) do
		updateInteractionUI()
		updateCarryDisplay()
	end
end)

print("[ThingInteractionHandler] Loaded for " .. player.Name)
