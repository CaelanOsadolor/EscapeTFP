-- ThingCarryManager.lua
-- Simplified carrying system based on simple carry approach
-- Place in: ServerScriptService/Things/

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ThingCarryManager = {}

local playerCarrying = {} -- Track what each player is carrying

-- Get animation from ReplicatedStorage/Animations
local carryAnim = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("CarryAnim(R15)")

local MAX_CARRY = 10 -- Maximum things a player can carry at once

-- Create RemoteEvent for dropping
local dropEvent = ReplicatedStorage:FindFirstChild("DropThing")
if not dropEvent then
	dropEvent = Instance.new("RemoteEvent")
	dropEvent.Name = "DropThing"
	dropEvent.Parent = ReplicatedStorage
end

-- Setup speed synchronization for a player (NO CHANGES - carry doesn't affect speed/jump)
local function SetupSpeedSync(player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not humanoidRootPart then return end

	local playerData = playerCarrying[player.UserId]
	if not playerData then return end

	-- Sync speed only - NO jump changes
	local function syncSpeed()
		local actualSpeed = player:GetAttribute("Speed") or 18
		humanoid.WalkSpeed = actualSpeed
		-- NO jump power changes - jumping stays normal
	end

	-- Initial sync
	syncSpeed()

	-- Connect listener (never disconnect it)
	local speedConnection = player:GetAttributeChangedSignal("Speed"):Connect(syncSpeed)
	playerData.SpeedConnection = speedConnection
end

-- Create CarryPart attached to player's HumanoidRootPart
local function CreateCarryPart(player)
	local character = player.Character
	if not character then return nil end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	-- Create invisible part in front of player at chest height
	local carryPart = Instance.new("Part")
	carryPart.Name = "CarryPart"
	carryPart.Size = Vector3.new(1, 1, 1)
	carryPart.Transparency = 1
	carryPart.CanCollide = false
	carryPart.CanTouch = false
	carryPart.CanQuery = false
	carryPart.Massless = true
	carryPart.Anchored = false
	carryPart.Parent = character

	-- Position high above player's head (like carrying on head)
	carryPart.CFrame = hrp.CFrame * CFrame.new(0, 5, 0)

	-- Weld to HumanoidRootPart using WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryPartWeld"
	weld.Parent = carryPart
	weld.Part0 = hrp
	weld.Part1 = carryPart

	return carryPart
end

-- Play carry animation (loops continuously)
local function PlayCarryAnimation(player, play)
	local playerData = playerCarrying[player.UserId]
	if not playerData then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	if play then
		-- Load and play animation, then freeze after 1 second
		local animTrack = animator:LoadAnimation(carryAnim)
		animTrack.Priority = Enum.AnimationPriority.Action4 -- Highest priority so nothing overrides
		animTrack.Looped = false
		animTrack:Play()

		-- Freeze animation after 1 second of playing
		task.spawn(function()
			task.wait(1) -- Wait exactly 1 second
			animTrack:AdjustSpeed(0) -- Freeze at current position

			-- Keep re-freezing to prevent fall/jump animations from unfreezing it
			while playerData.CarryAnim == animTrack do
				task.wait(0.1) -- Check every 0.1 seconds
				if animTrack.IsPlaying and animTrack.Speed ~= 0 then
					animTrack:AdjustSpeed(0) -- Re-freeze if it got unfrozen
				end
			end
		end)

		playerData.CarryAnim = animTrack
	else
		-- UNFREEZE first, then stop animation
		if playerData.CarryAnim then
			local animTrack = playerData.CarryAnim -- Cache it before wait
			playerData.CarryAnim = nil -- Clear reference immediately (stops the re-freeze loop)
			animTrack:AdjustSpeed(1) -- Unfreeze before stopping
			task.wait(0.05) -- Brief wait to allow unfreeze
			animTrack:Stop(0) -- Stop immediately with no fade
		end
	end
end

-- Attach thing to player (simple weld approach)
local function AttachThing(player, thing)
	local character = player.Character
	if not character then return false, "No character" end

	local handle = thing:FindFirstChild("Handle")
	if not handle then return false, "No handle" end

	local carryPart = character:FindFirstChild("CarryPart")
	if not carryPart or not handle then return false, "Missing parts" end

	-- Get player data for stack offset
	local playerData = playerCarrying[player.UserId]
	if not playerData then return false, "No player data" end

	-- CRITICAL: Disable Humanoid physics without destroying it (like the example)
	local humanoid = thing:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true -- Disables humanoid physics
	end

	-- Make ALL parts massless and unanchor them (they were anchored when spawned)
	for _, part in ipairs(thing:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Anchored = false -- CRITICAL: Unanchor so player can move
			-- Use collision group to ensure NO collision at all
			pcall(function()
				part.CollisionGroup = "CarriedThings"
			end)
			-- Set network ownership to player for smooth physics
			pcall(function()
				part:SetNetworkOwner(player)
			end)
		end
	end

	-- Weld all parts to Handle FIRST (preserve model structure)
	for _, part in ipairs(thing:GetDescendants()) do
		if part:IsA("BasePart") and part ~= handle then
			local partWeld = Instance.new("WeldConstraint")
			partWeld.Name = "PartWeld"
			partWeld.Parent = part
			partWeld.Part0 = handle
			partWeld.Part1 = part
		end
	end

	-- Position handle at CarryPart (stack items vertically) - BEFORE main weld like example
	-- FACE FORWARD: Rotate thing to face same direction as player
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		-- Stack offset for multiple items
		local stackOffset = #playerData.Things * 3 -- Each item 3 studs higher
		handle.CFrame = carryPart.CFrame * CFrame.new(0, stackOffset, 0)
	else
		-- Fallback
		local stackOffset = #playerData.Things * 3
		handle.CFrame = carryPart.CFrame * CFrame.new(0, stackOffset, 0)
	end

	-- Weld handle to CarryPart (like the example - simple WeldConstraint)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "ThingWeld"
	weld.Parent = carryPart
	weld.Part0 = carryPart
	weld.Part1 = handle

	return true
end

-- Detach thing from player
local function DetachThing(player, thing)
	-- Remove welds
	local handle = thing:FindFirstChild("Handle")
	if handle then
		local character = player.Character
		if character then
			local carryPart = character:FindFirstChild("CarryPart")
			if carryPart then
				-- Destroy all WeldConstraints in CarryPart
				for _, weld in ipairs(carryPart:GetChildren()) do
					if weld:IsA("WeldConstraint") and weld.Name == "ThingWeld" then
						weld:Destroy()
					end
				end
			end
		end

		-- Destroy PartWelds
		for _, part in ipairs(thing:GetDescendants()) do
			if part:IsA("BasePart") then
				for _, weld in ipairs(part:GetChildren()) do
					if weld:IsA("WeldConstraint") and weld.Name == "PartWeld" then
						weld:Destroy()
					end
				end
			end
		end
	end
end

-- Drop all carried things (on death or drop)
local function DropAllThings(player)
	local playerData = playerCarrying[player.UserId]
	if not playerData then return end

	-- Detach and destroy all carried things
	for _, thing in ipairs(playerData.Things) do
		if thing and thing.Parent then
			DetachThing(player, thing)
			thing:Destroy()
		end
	end

	-- Stop animation
	PlayCarryAnimation(player, false)

	-- Destroy CarryPart
	local character = player.Character
	if character then
		local carryPart = character:FindFirstChild("CarryPart")
		if carryPart then
			carryPart:Destroy()
		end
	end

	-- Hide DropGui
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		local dropGui = playerGui:FindFirstChild("DropGui")
		if dropGui then
			dropGui.Enabled = false
		end
	end

	-- Clear data
	playerData.Things = {}
end

-- Check if player can pickup more things
local function CanPickup(player)
	local playerData = playerCarrying[player.UserId]
	if not playerData then return false end

	-- Get player's carry capacity from attribute (default 1)
	local carryCapacity = player:GetAttribute("CarryCapacity") or 1

	return #playerData.Things < carryCapacity
end

-- Main pickup function
function ThingCarryManager.PickupThing(player, thing)
	if not player or not thing then return false end

	local playerData = playerCarrying[player.UserId]
	if not playerData then return false end

	-- Check if already carrying this thing
	if table.find(playerData.Things, thing) then
		return false
	end

	-- Check capacity
	if not CanPickup(player) then
		-- Send notification that player is at max capacity
		local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		if remoteEventsFolder then
			local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
			if notificationEvent then
				local carryCapacity = player:GetAttribute("CarryCapacity") or 1
				notificationEvent:FireClient(player, "Max carry capacity! (" .. carryCapacity .. ")", false)
			end

			-- Play error sound
			local playSoundEvent = remoteEventsFolder:FindFirstChild("PlaySoundEvent")
			if playSoundEvent then
				playSoundEvent:FireClient(player, "Error")
			end
		end

		return false
	end

	-- Create CarryPart if first thing
	if #playerData.Things == 0 then
		local carryPart = CreateCarryPart(player)
		if not carryPart then return false end

		-- Start animation (loops continuously)
		PlayCarryAnimation(player, true)

		-- Show DropGui
		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui then
			local dropGui = playerGui:FindFirstChild("DropGui")
			if dropGui then
				dropGui.Enabled = true
			end
		end
	else
		-- Already carrying things - IMMEDIATELY re-freeze animation to ensure it stays frozen
		if playerData.CarryAnim then
			local animTrack = playerData.CarryAnim
			-- Force freeze regardless of current state
			if not animTrack.IsPlaying then
				animTrack:Play()
				task.wait(0.05)
			end
			animTrack:AdjustSpeed(0) -- Force freeze
		end
	end

	-- Attach thing
	local success, err = AttachThing(player, thing)
	if not success then
		return false
	end

	-- Mark as picked up to prevent despawn
	thing:SetAttribute("IsPickedUp", true)

	-- Cancel the original countdown thread from spawn
	local countdownThread = thing:GetAttribute("CountdownThread")
	if countdownThread then
		task.cancel(countdownThread)
		thing:SetAttribute("CountdownThread", nil)
	end

	-- Add to carrying list
	table.insert(playerData.Things, thing)

	-- Stop despawn timer by destroying countdown connection
	local despawnConnection = thing:GetAttribute("DespawnConnection")
	if despawnConnection then
		-- Mark as not despawning
		thing:SetAttribute("ShouldDespawn", false)
	end

	-- Hide timer GUI
	local timerGui = thing:FindFirstChild("TimerGui")
	if timerGui then
		timerGui.Enabled = false
	end

	return true
end

-- Setup player
local function OnPlayerAdded(player)
	-- Initialize player data
	playerCarrying[player.UserId] = {
		Things = {},
		SpeedConnection = nil,
		CarryAnim = nil
	}

	-- Setup for character
	local function OnCharacterAdded(character)
		-- Wait for humanoid
		local humanoid = character:WaitForChild("Humanoid")

		-- Setup speed sync
		SetupSpeedSync(player)

		-- Handle death
		humanoid.Died:Connect(function()
			DropAllThings(player)
		end)
	end

	-- Connect to current and future characters
	if player.Character then
		OnCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(OnCharacterAdded)
end

-- Cleanup player
local function OnPlayerRemoving(player)
	DropAllThings(player)

	local playerData = playerCarrying[player.UserId]
	if playerData then
		-- Disconnect speed listener
		if playerData.SpeedConnection then
			playerData.SpeedConnection:Disconnect()
		end

		playerCarrying[player.UserId] = nil
	end
end

-- Initialize
function ThingCarryManager.Init()
	-- Setup collision group for carried things (no collision with anything)
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered("CarriedThings") then
			PhysicsService:RegisterCollisionGroup("CarriedThings")
		end
		-- Disable collision between CarriedThings and Default (everything else)
		PhysicsService:CollisionGroupSetCollidable("CarriedThings", "Default", false)
	end)

	-- Setup drop remote event handler
	dropEvent.OnServerEvent:Connect(function(player)
		ThingCarryManager.DropCarriedThings(player)
	end)

	-- Setup existing players
	for _, player in ipairs(Players:GetPlayers()) do
		OnPlayerAdded(player)
	end

	-- Setup future players
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)
end

-- Get player's carried things
function ThingCarryManager.GetCarriedThings(player)
	local playerData = playerCarrying[player.UserId]
	if not playerData then return {} end

	return playerData.Things or {}
end

-- Clear player's carried things (used when converting to inventory)
function ThingCarryManager.ClearCarried(player)
	local playerData = playerCarrying[player.UserId]
	if not playerData then return end

	-- FORCE stop ALL animations (ensure carry animation always ends)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChild("Animator")
			if animator then
				-- Stop all playing animation tracks
				local playingTracks = animator:GetPlayingAnimationTracks()
				for _, track in pairs(playingTracks) do
					track:Stop(0) -- Stop immediately with no fade
				end
			end
		end
	end

	-- Stop animation using our internal method (backup)
	PlayCarryAnimation(player, false)

	-- Destroy CarryPart
	if character then
		local carryPart = character:FindFirstChild("CarryPart")
		if carryPart then
			carryPart:Destroy()
		end
	end

	-- Hide DropGui
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		local dropGui = playerGui:FindFirstChild("DropGui")
		if dropGui then
			dropGui.Enabled = false
		end
	end

	-- Clear data
	playerData.Things = {}
end

-- Drop currently carried things into the world
function ThingCarryManager.DropCarriedThings(player)
	local playerData = playerCarrying[player.UserId]
	if not playerData or #playerData.Things == 0 then return end

	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Get ActiveThings folder
	local activeThingsFolder = game.Workspace:FindFirstChild("ActiveThings")
	if not activeThingsFolder then
		activeThingsFolder = Instance.new("Folder")
		activeThingsFolder.Name = "ActiveThings"
		activeThingsFolder.Parent = game.Workspace
	end

	-- Drop position (5 studs in front of player)
	local dropBasePosition = hrp.Position + (hrp.CFrame.LookVector * 5)

	-- Drop each carried thing
	for i, thing in ipairs(playerData.Things) do
		if thing and thing.Parent then
			-- Detach from player
			DetachThing(player, thing)

			-- Re-enable humanoid physics
			local humanoid = thing:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.PlatformStand = false
			end

			-- Setup like spawned things (anchored, no collision)
			local handle = thing:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.CanCollide = false
				handle.CanTouch = false
				handle.Transparency = 1
				handle.Anchored = true
				handle.CollisionGroup = "CarriedThings"
			end

			-- Make all other parts anchored and non-collidable like spawned things
			for _, part in ipairs(thing:GetDescendants()) do
				if part:IsA("BasePart") and part ~= handle then
					part.CanCollide = false
					part.Anchored = true
					part.CollisionGroup = "CarriedThings"
				end
			end

			-- Position on ground like spawned things (Y=0)
			if thing:IsA("Model") then
				-- Find the lowest Y position of all parts in the model
				local lowestY = math.huge
				for _, part in ipairs(thing:GetDescendants()) do
					if part:IsA("BasePart") then
						local partBottom = part.Position.Y - (part.Size.Y / 2)
						if partBottom < lowestY then
							lowestY = partBottom
						end
					end
				end

				-- Get current model position
				local currentCFrame = thing:GetPivot()
				local currentY = currentCFrame.Position.Y

				-- Calculate offset needed to put bottom at ground level (0)
				local yOffset = 0 - lowestY

				-- Stack drops slightly offset
				local stackOffset = Vector3.new((i-1) * 2, 0, 0)
				local finalPosition = Vector3.new(dropBasePosition.X, currentY + yOffset, dropBasePosition.Z) + stackOffset
				local rotation = CFrame.Angles(0, math.rad(90), 0)
				thing:PivotTo(CFrame.new(finalPosition) * rotation)
			else
				local stackOffset = Vector3.new((i-1) * 2, 0, 0)
				handle.Position = Vector3.new(dropBasePosition.X, 0, dropBasePosition.Z) + stackOffset
				handle.CFrame = handle.CFrame * CFrame.Angles(0, math.rad(90), 0)
			end

			-- Mark as dropped and not picked up
			thing:SetAttribute("IsPickedUp", false)
			thing:SetAttribute("IsDropped", true)
			thing:SetAttribute("DropTime", tick())

			-- Move to ActiveThings folder
			thing.Parent = activeThingsFolder

			-- Re-enable ProximityPrompt so it can be picked up again
			if handle then
				local takePrompt = handle:FindFirstChild("TakePrompt")
				if takePrompt then
					takePrompt.Enabled = true
				end

				-- Show and restart TimerGui countdown (fresh 60 seconds)
				local timerGui = handle:FindFirstChild("TimerGui")
				if timerGui then
					timerGui.Enabled = true

					-- Start fresh countdown from 60
					for _, descendant in ipairs(timerGui:GetDescendants()) do
						if descendant:IsA("TextLabel") and descendant.Name == "TimeLeft" then
							local timeLeftLabel = descendant
							local countdownThread = task.spawn(function()
								for countdown = 60, 0, -1 do
									if thing and thing.Parent and not thing:GetAttribute("IsPickedUp") then
										timeLeftLabel.Text = tostring(countdown) .. "s"
										task.wait(1)
									else
										break
									end
								end
							end)
							-- Store new countdown thread
							thing:SetAttribute("CountdownThread", countdownThread)
							break
						end
					end
				end
			end

			-- Set up 60 second despawn timer
			task.delay(60, function()
				if thing and thing.Parent and not thing:GetAttribute("IsPickedUp") then
					thing:Destroy()
				end
			end)
		end
	end

	-- Clear carried things
	ThingCarryManager.ClearCarried(player)
end

return ThingCarryManager
