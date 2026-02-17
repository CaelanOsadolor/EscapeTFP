-- Wave Manager Script
-- Place this in ServerScriptService

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local WAVE_SPAWN_POSITION = Vector3.new(2606.374, 12.933, 0)
local WAVE_END_POSITION = 177.5 -- X position where wave should be destroyed (the line)
local WAVE_DIRECTION = Vector3.new(-1, 0, 0) -- Direction the wave moves (adjust as needed)
local TIME_BETWEEN_WAVES = 3.5 -- Seconds between each wave

-- Wave Speeds (studs per second) - Map is 2427 studs long
local WAVE_SPEEDS = {
	["SuperSlow"] = 50,   -- Slowest (takes ~44 seconds to cross map)
	["Slow"] = 65,        -- Slow (takes ~32 seconds)
	["Medium"] = 90,      -- Medium (takes ~25 seconds)
	["Fast"] = 115,       -- Fast (takes ~19 seconds)
	["SuperFast"] = 140,  -- Very fast (takes ~16 seconds)
	["Lightning"] = 185,  -- Extremely fast (takes ~12 seconds)
	["Godspeed"] = 250    -- Insanely fast! (takes ~9 seconds)
}

-- Wave Rarity System (weights for random selection)
-- Higher weight = more common. Total = 1000
local WAVE_WEIGHTS = {
	["Slow"] = 198,        -- Most common (19.8%)
	["SuperSlow"] = 198,   -- Most common (19.8%)
	["Medium"] = 160,      -- Common (16%)
	["Fast"] = 148,        -- Less common (14.8%)
	["SuperFast"] = 148,   -- Less common (14.8%)
	["Lightning"] = 147,   -- Least common (14.7%)
	["Godspeed"] = 1       -- Super rare! 1/1000 chance (0.1%)
}

-- Get Waves folder from ServerStorage
local WavesFolder = ServerStorage:WaitForChild("Waves")

-- Pause system
local wavesPaused = false
local pauseEndTime = 0
local activeWaves = {} -- Track all active waves

-- Get RemoteEvents
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local stopTsunamisBindable = remoteEventsFolder:WaitForChild("StopTsunamisBindable")
local notificationEvent = remoteEventsFolder:WaitForChild("Notification")

-- Handle stop tsunamis requests
stopTsunamisBindable.Event:Connect(function(player, duration)
	print("[WaveManager] Stopping tsunamis for", duration, "seconds (requested by", player.Name, ")")
	wavesPaused = true
	pauseEndTime = tick() + duration
	
	-- Destroy all active waves on the map
	for wave, _ in pairs(activeWaves) do
		if wave and wave.Parent then
			wave:Destroy()
		end
	end
	-- Clear the tracking table
	activeWaves = {}
	print("[WaveManager] Cleared all active waves from map")
	
	-- Broadcast to all players
	for _, plr in pairs(Players:GetPlayers()) do
		notificationEvent:FireClient(plr, "🌊 " .. player.Name .. " stopped tsunamis for " .. duration .. " seconds!", true)
	end
	
	-- Start countdown timer
	task.spawn(function()
		while tick() < pauseEndTime do
			task.wait(1)
		end
		wavesPaused = false
		print("[WaveManager] Tsunamis resumed")
		
		-- Notify all players
		for _, plr in pairs(Players:GetPlayers()) do
			notificationEvent:FireClient(plr, "🌊 Tsunamis resumed!", false)
		end
	end)
end)

-- Function to handle hitbox touches
local function setupHitbox(hitbox)
	-- Make sure the hitbox can detect touches
	hitbox.CanCollide = false
	hitbox.Transparency = 1 -- Make invisible (optional)

	-- Create a touched connection
	local connection
	connection = hitbox.Touched:Connect(function(hit)
		-- Check if the thing we hit is part of a player
		local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")

		if humanoid and humanoid.Health > 0 then
			-- Kill the player
			humanoid.Health = 0
			print("Player killed by wave:", hit.Parent.Name)
		end
	end)

	return connection
end

-- Function to spawn and animate a wave
local function spawnWave(waveModel)
	-- Clone the wave
	local wave = waveModel:Clone()
	wave.Parent = Workspace
	
	-- Track this wave
	activeWaves[wave] = true

	-- Get the speed for this wave type
	local waveSpeed = WAVE_SPEEDS[waveModel.Name] or 50 -- Default to 50 if not found

	-- Position the wave at spawn point
	if wave:IsA("Model") and wave.PrimaryPart then
		wave:SetPrimaryPartCFrame(CFrame.new(WAVE_SPAWN_POSITION))
	elseif wave:IsA("Model") then
		-- If no PrimaryPart, move the whole model
		wave:MoveTo(WAVE_SPAWN_POSITION)
	end

-- Find all hitboxes in the wave
	local hitboxConnections = {}
	for _, child in pairs(wave:GetDescendants()) do
		if child:IsA("BasePart") and (child.Name:lower():find("hitbox") or child:GetAttribute("IsHitbox")) then
			table.insert(hitboxConnections, setupHitbox(child))
		end
	end

	-- Move the wave
	local RunService = game:GetService("RunService")
	local moveConnection
	moveConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if wave and wave.Parent then
			local movement = WAVE_DIRECTION * waveSpeed * deltaTime

			if wave:IsA("Model") and wave.PrimaryPart then
				-- Check if wave has passed the end line
				if wave.PrimaryPart.Position.X <= WAVE_END_POSITION then
					activeWaves[wave] = nil -- Remove from tracking
					wave:Destroy()
					moveConnection:Disconnect()
					return
				end

				wave:SetPrimaryPartCFrame(wave.PrimaryPart.CFrame + movement)
			elseif wave:IsA("Model") then
				-- Get approximate center position for models without PrimaryPart
				local center = wave:GetBoundingBox().Position
				if center.X <= WAVE_END_POSITION then
					activeWaves[wave] = nil -- Remove from tracking
					wave:Destroy()
					moveConnection:Disconnect()
					return
				end

				wave:TranslateBy(movement)
			end
		else
			-- Wave was destroyed, disconnect
			activeWaves[wave] = nil -- Remove from tracking
			moveConnection:Disconnect()
		end
	end)

	-- Return cleanup function
	return function()
		-- Disconnect all hitbox connections
		for _, conn in pairs(hitboxConnections) do
			conn:Disconnect()
		end

		-- Disconnect movement
		if moveConnection then
			moveConnection:Disconnect()
		end

		-- Destroy the wave
		if wave then
			activeWaves[wave] = nil -- Remove from tracking
			wave:Destroy()
		end
	end
end

-- Function to select a random wave based on rarity weights
local function selectRandomWave(waves)
	-- Calculate total weight
	local totalWeight = 0
	for waveName, weight in pairs(WAVE_WEIGHTS) do
		totalWeight = totalWeight + weight
	end

	-- Pick a random number between 1 and total weight
	local randomValue = math.random(1, totalWeight)

	-- Find which wave this random value corresponds to
	local currentWeight = 0
	for _, wave in pairs(waves) do
		local weight = WAVE_WEIGHTS[wave.Name] or 100 -- Default weight if not found
		currentWeight = currentWeight + weight

		if randomValue <= currentWeight then
			return wave
		end
	end

	-- Fallback: return a random wave
	return waves[math.random(1, #waves)]
end

-- Function to start wave cycle
local function startWaveSystem()
	local waves = WavesFolder:GetChildren()

	if #waves == 0 then
		warn("No waves found in ServerStorage.Waves folder!")
		return
	end



	while true do
		-- Check if waves are paused
		if not wavesPaused then
			-- Select a random wave based on rarity
			local selectedWave = selectRandomWave(waves)

			if selectedWave then
				spawnWave(selectedWave)

				-- Wait before spawning next wave
				wait(TIME_BETWEEN_WAVES)
			end
		else
			-- Waves paused, just wait
			wait(1)
		end

		wait(1) -- Small delay before next iteration
	end
end

-- Start the wave system
print("Wave Manager initialized!")
startWaveSystem()
