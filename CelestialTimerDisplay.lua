-- CelestialTimerDisplay.lua
-- Server Script - Place in: Workspace > Map > MainSign
-- Updates the Celestial spawn countdown timer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the script's parent (MainSign)
local mainSign = script.Parent
if not mainSign then
	warn("[CelestialTimer] Script parent not found!")
	return
end

-- Find the Celestial part (not Event)
local celestialPart = mainSign:FindFirstChild("Celestial")
if not celestialPart then
	warn("[CelestialTimer] Celestial part not found in MainSign!")
	return
end

-- Find the Timer TextLabel in Celestial part's descendants
local timerLabel = nil
for _, descendant in ipairs(celestialPart:GetDescendants()) do
	if descendant:IsA("TextLabel") and descendant.Name == "Timer" then
		timerLabel = descendant
		print("[CelestialTimer] Found Timer label at:", descendant:GetFullName())
		break
	end
end

if not timerLabel then
	warn("[CelestialTimer] Timer TextLabel not found in Celestial part!")
	return
end

-- Wait for RemoteEvents folder
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEventsFolder then
	warn("[CelestialTimer] RemoteEvents folder not found!")
	return
end

local celestialTimerBindable = remoteEventsFolder:FindFirstChild("CelestialTimerUpdate")
if not celestialTimerBindable then
	warn("[CelestialTimer] CelestialTimerUpdate BindableEvent not found!")
	return
end

-- Listen for timer updates
celestialTimerBindable.Event:Connect(function(timeRemaining)
	if timerLabel and timeRemaining then
		-- Format as MM:SS
		local minutes = math.floor(timeRemaining / 60)
		local seconds = timeRemaining % 60
		timerLabel.Text = string.format("%d:%02d", minutes, seconds)
	end
end)

print("[CelestialTimer] Timer display script initialized successfully!")
