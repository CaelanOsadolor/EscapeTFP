-- Base Multiplier Display Script
-- Place as LocalScript in StarterGui
-- Updates the Multiplier BillboardGui for player's base

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local basesFolder = Workspace:WaitForChild("Bases")

-- Wait for player to have a base assigned
repeat
	task.wait(0.5)
until player:GetAttribute("BaseNumber")

local baseNumber = player:GetAttribute("BaseNumber")
local baseName = "Base" .. baseNumber
local base = basesFolder:WaitForChild(baseName)

-- Find the Multiplier BillboardGui
local multiplier = base:WaitForChild("Multiplier")
local billboardGui = multiplier:WaitForChild("BillboardGui")
local textLabel = billboardGui:WaitForChild("TextLabel")

-- Function to update multiplier display
local function updateMultiplier()
	local rebirthMultiplier = player:GetAttribute("RebirthMultiplier") or 1
	textLabel.Text = rebirthMultiplier .. "x Money"
end

-- Initial update
updateMultiplier()

-- Update when RebirthMultiplier changes
player:GetAttributeChangedSignal("RebirthMultiplier"):Connect(updateMultiplier)

-- Update when Rebirths changes (server will update RebirthMultiplier)
player:GetAttributeChangedSignal("Rebirths"):Connect(updateMultiplier)

-- Update when money boost changes
player:GetAttributeChangedSignal("Boost2xMoneyEndTime"):Connect(updateMultiplier)

print("Base Multiplier Display initialized for Base" .. baseNumber)
