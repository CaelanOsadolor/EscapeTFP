-- Slow Walk Toggle Server Handler
-- Place in ServerScriptService/GameManager

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require GamepassManager to get actual speeds
local GamepassManager = require(script.Parent.GamepassManager)

-- Create RemoteEvent for slow walk toggle
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
	remoteEventsFolder = Instance.new("Folder")
	remoteEventsFolder.Name = "RemoteEvents"
	remoteEventsFolder.Parent = ReplicatedStorage
end

local slowWalkToggleEvent = remoteEventsFolder:FindFirstChild("SlowWalkToggleEvent")
if not slowWalkToggleEvent then
	slowWalkToggleEvent = Instance.new("RemoteEvent")
	slowWalkToggleEvent.Name = "SlowWalkToggleEvent"
	slowWalkToggleEvent.Parent = remoteEventsFolder
end

-- Handle slow walk toggle
slowWalkToggleEvent.OnServerEvent:Connect(function(player, enabled)
	-- Verify player exists
	if not player or not player.Parent then 
		warn("[SlowWalk] Player not found")
		return 
	end
	
	-- Get character (wait if needed)
	local character = player.Character
	if not character then
		warn("[SlowWalk] Character not loaded for", player.Name)
		return
	end
	
	-- Get humanoid (wait if needed)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 2)
		if not humanoid then
			warn("[SlowWalk] Humanoid not found for", player.Name)
			return
		end
	end
	
	-- Store state in player attribute
	player:SetAttribute("SlowWalkEnabled", enabled)
	
	-- Apply speed change
	if enabled then
		-- Slow walk ON: set speed to 18 (base slow speed)
		humanoid.WalkSpeed = 18
		print("[SlowWalk] Enabled for", player.Name, "- Speed set to 18")
	else
		-- Slow walk OFF: restore player's actual speed (including 2x gamepass)
		local actualSpeed = GamepassManager.GetActualWalkSpeed(player)
		humanoid.WalkSpeed = actualSpeed
		print("[SlowWalk] Disabled for", player.Name, "- Speed set to", actualSpeed)
	end
	
	-- Force a second update to ensure it sticks
	task.wait(0.1)
	if enabled then
		humanoid.WalkSpeed = 18
	else
		local actualSpeed = GamepassManager.GetActualWalkSpeed(player)
		humanoid.WalkSpeed = actualSpeed
	end
end)

-- Make sure slow walk state is restored on character respawn
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		
		-- Wait a moment for attributes to load
		task.wait(0.1)
		
		-- Check if slow walk is enabled
		local slowWalkEnabled = player:GetAttribute("SlowWalkEnabled")
		if slowWalkEnabled then
			humanoid.WalkSpeed = 18
		else
			-- Use actual speed including gamepass
			local actualSpeed = GamepassManager.GetActualWalkSpeed(player)
			humanoid.WalkSpeed = actualSpeed
		end
	end)
end)

print("Slow Walk Toggle Handler initialized!")
