-- LocalSoundHandler.client.luau
-- Plays sounds locally for the player from ReplicatedStorage.Sounds

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local soundsFolder = ReplicatedStorage:WaitForChild("Sounds")

-- Remote event to trigger sounds (create this in ReplicatedStorage)
local playSoundEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("PlaySoundEvent")

-- Function to play a sound locally
local function playSound(soundName, volume, playbackSpeed, parent)
	-- Get the sound from ReplicatedStorage
	local soundTemplate = soundsFolder:FindFirstChild(soundName)
	if not soundTemplate then
		warn("Sound not found: " .. soundName)
		return
	end
	
	-- Clone and play the sound
	local sound = soundTemplate:Clone()
	-- Use provided values or default to template's original settings
	sound.Volume = volume or soundTemplate.Volume
	sound.PlaybackSpeed = playbackSpeed or soundTemplate.PlaybackSpeed
	
	-- Parent to specified location or player's head
	if parent then
		sound.Parent = parent
	elseif player.Character and player.Character:FindFirstChild("Head") then
		sound.Parent = player.Character.Head
	else
		sound.Parent = workspace.CurrentCamera
	end
	
	-- Play and clean up
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	
	-- Fallback cleanup in case Ended doesn't fire
	task.delay(sound.TimeLength + 1, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Listen for sound play requests from server
playSoundEvent.OnClientEvent:Connect(function(soundName, volume, playbackSpeed, parent)
	playSound(soundName, volume, playbackSpeed, parent)
end)

print("LocalSoundHandler initialized!")

-- Example usage from server:
-- game.ReplicatedStorage.RemoteEvents.PlaySoundEvent:FireClient(player, "ClaimSound", 0.5, 1, nil)
