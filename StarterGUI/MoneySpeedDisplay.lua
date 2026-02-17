-- Money & Speed Display Script
-- Place this LocalScript in StarterGui/BottomLeft/Frame

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Get UI elements
local frame = script.Parent
local moneyLabel = frame:FindFirstChild("Money")
local speedLabel = frame:FindFirstChild("Speed")

-- Current displayed values (for smooth transitions)
local displayedMoney = 0
local displayedSpeed = 18

-- Target values
local targetMoney = 0
local targetSpeed = 18

-- Format large numbers
local function formatNumber(num)
	local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
	local tier = 1
	
	while num >= 1000 and tier < #suffixes do
		num = num / 1000
		tier = tier + 1
	end
	
	-- Check if it's a whole number
	local isWhole = (num == math.floor(num))
	
	if isWhole then
		return string.format("%.0f%s", num, suffixes[tier])
	elseif num >= 100 then
		return string.format("%.0f%s", num, suffixes[tier])
	elseif num >= 10 then
		return string.format("%.1f%s", num, suffixes[tier])
	else
		return string.format("%.2f%s", num, suffixes[tier])
	end
end

-- Update target money
local function updateMoney()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local money = leaderstats:FindFirstChild("Money")
		if money then
			targetMoney = money.Value
		end
	end
end

-- Update target speed (always from base Speed attribute, not actual walkspeed)
local function updateSpeed()
	local speed = player:GetAttribute("Speed")
	if speed then
		targetSpeed = speed
	end
end

-- Smooth number interpolation
local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Animate values smoothly
RunService.RenderStepped:Connect(function(deltaTime)
	-- Smooth money transition
	local moneyDiff = math.abs(targetMoney - displayedMoney)
	local moneyLerpSpeed = math.clamp(deltaTime * 16, 0, 1) -- Smoother, faster
	
	if moneyDiff > 0.5 then
		displayedMoney = lerp(displayedMoney, targetMoney, moneyLerpSpeed)
	else
		displayedMoney = targetMoney
	end
	
	-- Smooth speed transition
	local speedDiff = math.abs(targetSpeed - displayedSpeed)
	local speedLerpSpeed = math.clamp(deltaTime * 20, 0, 1) -- Smoother, faster
	
	if speedDiff > 0.1 then
		displayedSpeed = lerp(displayedSpeed, targetSpeed, speedLerpSpeed)
	else
		displayedSpeed = targetSpeed
	end
	
	-- Update labels
	if moneyLabel then
		moneyLabel.Text = "$" .. formatNumber(math.floor(displayedMoney))
	end
	
	if speedLabel then
		-- Always show base speed (not actual walkspeed)
		local baseSpeed = math.floor(displayedSpeed)
		
		-- Check if player has 2x speed gamepass or boost
		local hasSpeed2x = player:GetAttribute("HasSpeed2x")
		local boostEndTime = player:GetAttribute("Boost2xSpeedEndTime")
		local hasBoost = boostEndTime and os.time() < boostEndTime
		
		if hasSpeed2x or hasBoost then
			speedLabel.Text = "Speed: " .. baseSpeed .. " (2x)"
		else
			speedLabel.Text = "Speed: " .. baseSpeed
		end
	end
end)

-- Initial update
wait(0.5) -- Wait for player to load
updateMoney()
updateSpeed()

displayedMoney = targetMoney
displayedSpeed = targetSpeed

-- Connect to money changes
local leaderstats = player:WaitForChild("leaderstats")
local money = leaderstats:WaitForChild("Money")
money:GetPropertyChangedSignal("Value"):Connect(updateMoney)

player:GetAttributeChangedSignal("Speed"):Connect(updateSpeed)

player:GetAttributeChangedSignal("HasSpeed2x"):Connect(updateSpeed)

player:GetAttributeChangedSignal("Boost2xSpeedEndTime"):Connect(updateSpeed)


-- Listen for slow walk toggles (attribute or event)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if remoteEvents then
	local slowWalkToggleEvent = remoteEvents:FindFirstChild("SlowWalkToggleEvent")
	if slowWalkToggleEvent then
		slowWalkToggleEvent.OnClientEvent:Connect(function()
			updateSpeed()
		end)
	end
end

-- Listen for SlowWalkEnabled attribute changes
player:GetAttributeChangedSignal("SlowWalkEnabled"):Connect(updateSpeed)
