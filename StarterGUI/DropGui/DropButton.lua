-- DropButton.lua
-- Handles dropping the currently carried thing
-- Place in: StarterGui/DropGui

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- Get the Frame and ImageButton
local dropGui = script.Parent
local dropFrame = dropGui:FindFirstChild("Frame")
if not dropFrame then
	warn("[DropButton] Frame not found in DropGui!")
	return
end

local dropButton = dropFrame:FindFirstChild("ImageButton")
if not dropButton then
	warn("[DropButton] ImageButton not found in Frame!")
	return
end

-- Get or create RemoteEvent for dropping
local dropEvent = ReplicatedStorage:FindFirstChild("DropThing")
if not dropEvent then
	warn("[DropButton] DropThing RemoteEvent not found!")
	return
end

-- Handle button click
dropButton.MouseButton1Click:Connect(function()
	-- Fire to server to drop the thing
	dropEvent:FireServer()
end)
