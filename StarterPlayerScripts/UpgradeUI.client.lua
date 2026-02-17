-- UpgradeUI.client.lua
-- Handles upgrade button clicks on slots
-- Place in: StarterPlayer/StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Get remote function
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local upgradeSlotFunc = remoteEvents:WaitForChild("UpgradeSlot")

-- Track connected buttons to avoid duplicate connections
local connectedButtons = {}

-- Setup upgrade button for a slot
local function setupUpgradeButton(slot)
	local upgrade = slot:FindFirstChild("Upgrade")
	if not upgrade then return end
	
	local surfaceGui = upgrade:FindFirstChild("SurfaceGui")
	if not surfaceGui then return end
	
	local frame = surfaceGui:FindFirstChild("Frame")
	if not frame then return end
	
	local imageButton = frame:FindFirstChild("ImageButton")
	if not imageButton then return end
	
	-- Check if already connected
	if connectedButtons[imageButton] then return end
	connectedButtons[imageButton] = true
	
	-- Connect button click
	imageButton.MouseButton1Click:Connect(function()
		-- Quick client-side check to avoid unnecessary server calls
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then return end
		
		local money = leaderstats:FindFirstChild("Money")
		if not money then return end
		
		-- Get slot's current upgrade level and thing info to estimate cost
		local occupied = slot:GetAttribute("Occupied")
		if not occupied then return end
		
		-- Request upgrade from server
		local success, result = upgradeSlotFunc:InvokeServer(slot)
		
		if success then
			print("[UpgradeUI] Upgraded to level", result)
		else
			-- Only warn if it's not a "not enough money" error (to reduce spam)
			if result ~= "Not enough money" then
				warn("[UpgradeUI] Upgrade failed:", result)
			end
		end
	end)
end

-- Find player's base and setup all upgrade buttons
local function setupPlayerSlots()
	-- Wait for player's base number
	local baseNumber = player:GetAttribute("BaseNumber")
	local attempts = 0
	while not baseNumber and attempts < 20 do
		task.wait(0.5)
		baseNumber = player:GetAttribute("BaseNumber")
		attempts = attempts + 1
	end
	
	if not baseNumber then
		warn("[UpgradeUI] Could not find player's BaseNumber")
		return
	end
	
	-- Find player's base
	local bases = Workspace:WaitForChild("Bases")
	local baseName = "Base" .. baseNumber
	local playerBase = bases:WaitForChild(baseName, 10)
	
	if not playerBase then
		warn("[UpgradeUI] Could not find player's base:", baseName)
		return
	end
	
	-- Find slots folder
	local slotsFolder = playerBase:FindFirstChild("Slots")
	if not slotsFolder then
		warn("[UpgradeUI] No Slots folder in base")
		return
	end
	
	-- Setup each slot
	for _, slot in ipairs(slotsFolder:GetChildren()) do
		if slot:IsA("Model") and slot.Name:match("^Slot") then
			setupUpgradeButton(slot)
		end
	end
	
	-- Listen for new slots added
	slotsFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") and child.Name:match("^Slot") then
			task.wait(0.1) -- Wait for slot to fully load
			setupUpgradeButton(child)
		end
	end)
	
	print("[UpgradeUI] Setup complete for", player.Name)
end

-- Wait for character then setup
player.CharacterAdded:Connect(function()
	task.wait(1) -- Wait for base assignment
	setupPlayerSlots()
end)

-- Setup immediately if already spawned
if player.Character then
	task.wait(1)
	setupPlayerSlots()
end
