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

-- Find the Timer TextLabel in descendants
local timerLabel = nil
for _, descendant in ipairs(mainSign:GetDescendants()) do
	if descendant:IsA("TextLabel") and descendant.Name == "Timer" then
		timerLabel = descendant
		print("[CelestialTimer] Found Timer label at:", descendant:GetFullName())
		break
	end
end

if not timerLabel then
	warn("[CelestialTimer] Timer TextLabel not found in MainSign!")
	warn("[CelestialTimer] Searched in:", mainSign:GetFullName())
	return
end

-- Wait for RemoteEvent
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEventsFolder then
	warn("[CelestialTimer] RemoteEvents folder not found!")
	return
end

-- Create or find CelestialTimer RemoteEvent
local celestialTimerEvent = remoteEventsFolder:FindFirstChild("CelestialTimer")
if not celestialTimerEvent then
	celestialTimerEvent = Instance.new("RemoteEvent")
	celestialTimerEvent.Name = "CelestialTimer"
	celestialTimerEvent.Parent = remoteEventsFolder
	print("[CelestialTimer] Created CelestialTimer RemoteEvent")
end

-- Listen for timer updates from server
celestialTimerEvent.OnServerEvent:Connect(function(player, timeRemaining)
	-- This is actually for client->server, we need a different approach
end)

-- Since this is a server script and we want server-to-server communication,
-- we'll use a BindableEvent instead
local bindableEventsFolder = ReplicatedStorage:FindFirstChild("BindableEvents")
if not bindableEventsFolder then
	bindableEventsFolder = Instance.new("Folder")
	bindableEventsFolder.Name = "BindableEvents"
	bindableEventsFolder.Parent = ReplicatedStorage
end

local celestialTimerBindable = bindableEventsFolder:FindFirstChild("CelestialTimerUpdate")
if not celestialTimerBindable then
	celestialTimerBindable = Instance.new("BindableEvent")
	celestialTimerBindable.Name = "CelestialTimerUpdate"
	celestialTimerBindable.Parent = bindableEventsFolder
	print("[CelestialTimer] Created CelestialTimerUpdate BindableEvent")
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
