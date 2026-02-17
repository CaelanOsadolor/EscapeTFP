-- Base Upgrade Button Handler
-- Place as LocalScript in StarterGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer

-- Wait for RemoteEvent
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local baseUpgradeEvent = remoteEventsFolder:WaitForChild("BaseUpgradeEvent")
local errorSoundEvent = remoteEventsFolder:WaitForChild("ErrorSound")

-- Sounds
local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://9083627113"
clickSound.Volume = 0.1
clickSound.Parent = SoundService

local errorSound = Instance.new("Sound")
errorSound.SoundId = "rbxassetid://9066167010"
errorSound.Volume = 0.25
errorSound.Parent = SoundService

-- Listen for error sound event
errorSoundEvent.OnClientEvent:Connect(function()
	errorSound:Play()
end)

-- Wait for player to have a base
repeat
	task.wait(0.5)
until player:GetAttribute("BaseNumber")

local baseNumber = player:GetAttribute("BaseNumber")
local baseName = "Base" .. baseNumber
local base = workspace:WaitForChild("Bases"):WaitForChild(baseName)

-- Find the upgrade button
local upgradeBase = base:WaitForChild("UpgradeBase")
local sign = upgradeBase:WaitForChild("Sign")
local surfaceGui = sign:WaitForChild("SurfaceGui")
local frame = surfaceGui:WaitForChild("Frame")
local imageButton = frame:WaitForChild("ImageButton")

print("Found upgrade button for Base" .. baseNumber)

-- Handle button click
imageButton.MouseButton1Click:Connect(function()
	-- Play click sound
	clickSound:Play()

	-- Send upgrade request to server
	baseUpgradeEvent:FireServer()

	print("Clicked upgrade button")
end)

-- Update display when BaseUpgradeLevel changes
player:GetAttributeChangedSignal("BaseUpgradeLevel"):Connect(function()
	task.wait(0.1) -- Small delay to let server update

	local currentLevel = player:GetAttribute("BaseUpgradeLevel") or 0

	-- Update SlotCount label
	local slotCount = frame:FindFirstChild("SlotCount")
	if slotCount then
		slotCount.Text = currentLevel .. "/20"
	end
end)

print("Base Upgrade Button Handler initialized")
