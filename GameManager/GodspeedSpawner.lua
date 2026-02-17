-- GodspeedSpawner.lua
-- Server script to handle spawning Godspeed tsunami when purchased
-- Place in: ServerScriptService/GameManager

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GodspeedSpawner = {}

-- Configuration (same as WaveManager)
local WAVE_SPAWN_POSITION = Vector3.new(2606.374, 12.933, 0)
local WAVE_END_POSITION = 177.5 -- X position where wave should be destroyed
local WAVE_DIRECTION = Vector3.new(-1, 0, 0)
local GODSPEED_SPEED = 250 -- Studs per second (insanely fast!)

-- Function to handle hitbox touches
local function setupHitbox(hitbox)
	hitbox.CanCollide = false
	hitbox.Transparency = 1

	local connection
	connection = hitbox.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
			print("Player killed by Godspeed wave:", hit.Parent.Name)
		end
	end)

	return connection
end

-- Function to spawn Godspeed wave
function GodspeedSpawner.SpawnGodspeedWave(player)
	-- Get Waves folder and find Godspeed wave
	local WavesFolder = ServerStorage:FindFirstChild("Waves")
	if not WavesFolder then
		warn("[GodspeedSpawner] Waves folder not found in ServerStorage!")
		return false
	end

	local godspeedWave = WavesFolder:FindFirstChild("Godspeed")
	if not godspeedWave then
		warn("[GodspeedSpawner] Godspeed wave not found in ServerStorage.Waves!")
		return false
	end

	-- Clone the wave
	local wave = godspeedWave:Clone()
	wave.Parent = Workspace

	-- Position the wave at spawn point
	if wave:IsA("Model") and wave.PrimaryPart then
		wave:SetPrimaryPartCFrame(CFrame.new(WAVE_SPAWN_POSITION))
	elseif wave:IsA("Model") then
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
			local movement = WAVE_DIRECTION * GODSPEED_SPEED * deltaTime

			if wave:IsA("Model") and wave.PrimaryPart then
				-- Check if wave has passed the end line
				if wave.PrimaryPart.Position.X <= WAVE_END_POSITION then
					wave:Destroy()
					moveConnection:Disconnect()
					-- Cleanup hitbox connections
					for _, conn in pairs(hitboxConnections) do
						conn:Disconnect()
					end
					return
				end

				wave:SetPrimaryPartCFrame(wave.PrimaryPart.CFrame + movement)
			elseif wave:IsA("Model") then
				local center = wave:GetBoundingBox().Position
				if center.X <= WAVE_END_POSITION then
					wave:Destroy()
					moveConnection:Disconnect()
					-- Cleanup hitbox connections
					for _, conn in pairs(hitboxConnections) do
						conn:Disconnect()
					end
					return
				end

				wave:TranslateBy(movement)
			end
		else
			-- Wave was destroyed, disconnect
			moveConnection:Disconnect()
			for _, conn in pairs(hitboxConnections) do
				conn:Disconnect()
			end
		end
	end)

	-- Send notification to ALL players
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEventsFolder then
		local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
		if notificationEvent then
			for _, plr in pairs(game:GetService("Players"):GetPlayers()) do
				notificationEvent:FireClient(plr, "🌊 " .. player.Name .. " spawned GODSPEED TSUNAMI! RUN!", true)
			end
		end
	end

	print("[GodspeedSpawner]", player.Name, "spawned a Godspeed wave!")
	return true
end

return GodspeedSpawner
