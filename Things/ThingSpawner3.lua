-- ThingSpawner.lua
-- Handles spawning individual things on different floors
-- Place in: ServerScriptService/Things/

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ThingSpawner = {}

-- Configuration
local DESPAWN_TIME = 60 -- Things despawn after 60 seconds

-- Spawn configuration per RARITY (each floor maintains ~7 things total)
local RARITY_SPAWN_CONFIG = {
	Common = {SpawnInterval = 5, MaxSpawns = 7},
	Uncommon = {SpawnInterval = 5, MaxSpawns = 7},
	Rare = {SpawnInterval = 5, MaxSpawns = 7},
	Epic = {SpawnInterval = 5, MaxSpawns = 7},
	Legendary = {SpawnInterval = 5, MaxSpawns = 7},
	Mythical = {SpawnInterval = 5, MaxSpawns = 7},
	Divine = {SpawnInterval = 5, MaxSpawns = 7},
	Secret = {SpawnInterval = 5, MaxSpawns = 7},
	Celestial = {SpawnInterval = 300, MaxSpawns = 1}, -- Spawns every 5 minutes (300 seconds)
	-- Limited doesn't spawn naturally (obtained through robux/wheel only)
}

-- Spawn weights for WHICH thing spawns within each rarity
-- Higher weight = more likely to be picked when spawning that rarity
-- Weights are INVERSELY proportional to value - higher value = lower spawn chance
local THING_SPAWN_WEIGHTS = {
	-- Common Things (6 items) - $2-7/sec
	Common = {
		["Black"] = 20,    -- $2/sec (spawns most)
		["Blue"] = 16,     -- $3/sec
		["Green"] = 16,    -- $4/sec
		["Pink"] = 16,     -- $5/sec
		["Red"] = 16,      -- $6/sec
		["Yellow"] = 16    -- $7/sec (spawns least)
	},

	-- Uncommon Things (4 items) - $10-50/sec
	Uncommon = {
		["Banana"] = 35,      -- $10/sec (spawns most)
		["FastFood"] = 25,    -- $20/sec
		["Festive"] = 20,     -- $35/sec
		["Painter"] = 20      -- $50/sec (spawns least)
	},

	-- Rare Things (6 items) - $100-500/sec
	Rare = {
		["Bandit"] = 50,     -- $100/sec (spawns most)
		["Bronze"] = 33,     -- $150/sec
		["Cook"] = 25,       -- $200/sec
		["Judge"] = 17,      -- $300/sec
		["Police"] = 13,     -- $400/sec
		["Snowman"] = 10     -- $500/sec (spawns least)
	},

	-- Epic Things (4 items) - $1K-5K/sec
	Epic = {
		["Fancy"] = 50,       -- $1K/sec (spawns most)
		["Icecream"] = 25,    -- $2K/sec
		["Knight"] = 14,      -- $3.5K/sec
		["Silver"] = 10       -- $5K/sec (spawns least)
	},

	-- Legendary Things (5 items) - $10K-40K/sec
	Legendary = {
		["Gold"] = 40,      -- $10K/sec (spawns most)
		["Scholar"] = 27,   -- $15K/sec
		["Sleepy"] = 18,    -- $22K/sec
		["Snowy"] = 13,     -- $30K/sec
		["TRex"] = 10       -- $40K/sec (spawns least)
	},

	-- Mythical Things (4 items) - $50K-95K/sec
	Mythical = {
		["Celebrity"] = 38,  -- $50K/sec (spawns most)
		["Chubby"] = 29,     -- $65K/sec
		["Ruby"] = 24,       -- $80K/sec
		["Seal"] = 20        -- $95K/sec (spawns least)
	},

	-- Divine Things (5 items) - $200K-400K/sec
	Divine = {
		["Astral"] = 40,         -- $200K/sec (spawns most)
		["Boxer"] = 32,          -- $250K/sec
		["Diamond"] = 27,        -- $300K/sec
		["Neon Samurai"] = 23,   -- $350K/sec
		["Wizard"] = 20          -- $400K/sec (spawns least)
	},

	-- Secret Things (4 items) - $670K-1M/sec
	Secret = {
		["Chill Bro"] = 30,  -- $670K/sec (spawns most)
		["King"] = 26,       -- $777K/sec
		["Spino"] = 22,      -- $900K/sec
		["Yeti"] = 20        -- $1M/sec (spawns least)
	},

	-- Celestial (spawns in Secret zone but very rarely) - 4 items - $5M-15M/sec
	Celestial = {
		["Angel"] = 60,          -- $5M/sec (spawns most)
		["Frostbite"] = 38,      -- $8M/sec
		["HeartBreaker"] = 25,   -- $12M/sec
		["Space"] = 20           -- $15M/sec (spawns least)
	},

	-- Limited (doesn't spawn naturally, only through wheel/robux)
	Limited = {
		["Love Knight"] = 100      -- $30M/sec - Only one Limited item
	}
}

-- Group things by rarity for floor spawning
local RARITY_GROUPS = {
	Common = {},
	Uncommon = {},
	Rare = {},
	Epic = {},
	Legendary = {},
	Mythical = {},
	Divine = {},
	Secret = {},
	Celestial = {},
	Limited = {}
}

local thingTemplates = {} -- Store templates by thing name
local activeThingsByRarity = {} -- Track total spawned things per RARITY
local floorZones = {} -- Store floor zones from workspace

-- Initialize the spawner
function ThingSpawner.Init()
	print("[ThingSpawner] Initializing...")

	-- Setup collision group FIRST before spawning anything
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered("CarriedThings") then
			PhysicsService:RegisterCollisionGroup("CarriedThings")
		end
		PhysicsService:CollisionGroupSetCollidable("CarriedThings", "Default", false)
		-- Also disable collision with PlacedThings if it exists
		if PhysicsService:IsCollisionGroupRegistered("PlacedThings") then
			PhysicsService:CollisionGroupSetCollidable("CarriedThings", "PlacedThings", false)
		end
		print("[ThingSpawner] Collision group registered and configured")
	end)

	-- Wait a frame to ensure collision group is fully registered
	task.wait()

	-- Load thing templates from ServerStorage
	local thingsFolder = ServerStorage:FindFirstChild("Things")
	if not thingsFolder then
		warn("[ThingSpawner] Things folder not found in ServerStorage!")
		return
	end

	-- Load templates for each rarity and organize by thing name
	for rarity, _ in pairs(RARITY_GROUPS) do
		activeThingsByRarity[rarity] = {}

		local rarityFolder = thingsFolder:FindFirstChild(rarity)
		if rarityFolder then
			for _, thing in ipairs(rarityFolder:GetChildren()) do
				if thing:IsA("Model") or thing:IsA("BasePart") then
					local thingName = thing.Name
					thingTemplates[thingName] = thing

					-- Group by rarity
					table.insert(RARITY_GROUPS[rarity], thingName)

					print("[ThingSpawner] Loaded " .. thingName .. " (" .. rarity .. ")")
				end
			end
		else
			warn("[ThingSpawner] No " .. rarity .. " folder found!")
		end
	end

	-- Find floor zones in workspace
	ThingSpawner.SetupFloorZones()

	-- Start spawning loop for each RARITY (maintains ~7 per floor)
	for rarity, config in pairs(RARITY_SPAWN_CONFIG) do
		task.spawn(function()
			ThingSpawner.SpawnLoopForRarity(rarity, config)
		end)
	end
end

-- Setup floor zones from the map
function ThingSpawner.SetupFloorZones()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		warn("[ThingSpawner] Map not found in Workspace!")
		return
	end

	local floors = map:FindFirstChild("Floors")
	if not floors then
		warn("[ThingSpawner] Floors folder not found in Map!")
		return
	end

	-- Find each rarity floor
	for rarity, _ in pairs(RARITY_GROUPS) do
		if rarity == "Celestial" then
			-- Celestial spawns in the Secret zone
			local secretFloor = floors:FindFirstChild("Secret")
			if secretFloor then
				floorZones["Celestial"] = secretFloor
				print("[ThingSpawner] Celestial will spawn in Secret zone")
			else
				warn("[ThingSpawner] Secret floor not found for Celestial!")
			end
		elseif rarity == "Limited" then
			-- Limited doesn't spawn naturally, skip floor setup
			print("[ThingSpawner] Limited rarity doesn't spawn naturally")
		else
			local floor = floors:FindFirstChild(rarity)
			if floor then
				floorZones[rarity] = floor
			else
				warn("[ThingSpawner] " .. rarity .. " floor not found!")
			end
		end
	end
end

-- Main spawn loop for a specific rarity (maintains ~7 things per floor)
function ThingSpawner.SpawnLoopForRarity(rarity, config)
	-- Special handling for Celestial with timer updates
	if rarity == "Celestial" then
		-- Get or create BindableEvent for timer updates
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
		end

		-- Main loop - timer is the source of truth
		while true do
			-- Countdown from spawn interval to 0
			for timeRemaining = config.SpawnInterval, 0, -1 do
				-- Fire timer update
				celestialTimerBindable:Fire(timeRemaining)

				-- Wait 1 second (except on last iteration when timeRemaining is 0)
				if timeRemaining > 0 then
					task.wait(1)
				end
			end

			-- Timer hit 0 - time to spawn!
			-- Check if we're at max spawns for this RARITY
			if #activeThingsByRarity[rarity] < config.MaxSpawns then
				-- Always spawn (no random chance) - pick which thing from this rarity
				local thingName = ThingSpawner.PickRandomThingFromRarity(rarity)
				if thingName then
					ThingSpawner.SpawnSpecificThing(thingName, rarity)

					-- Send pink notification to ALL players (5 seconds duration with sound)
					local Players = game:GetService("Players")
					local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
					local notificationEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("Notification")
					local playSoundEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("PlaySoundEvent")

					if notificationEvent then
						for _, player in Players:GetPlayers() do
							-- Args: Text, Polarity, CustomColor, CustomDuration
							notificationEvent:FireClient(player, "🌟 A Celestial " .. thingName .. " has spawned!", nil, Color3.fromRGB(255, 170, 255), 5)

							-- Play sound separately for each player
							if playSoundEvent then
								playSoundEvent:FireClient(player, "ClaimSound", 0.7, 1, nil)
							end
						end
					end
				end
			end
			-- Timer will restart from config.SpawnInterval at the top of the loop
		end
	else
		-- Normal spawn loop for other rarities
		while true do
			task.wait(config.SpawnInterval)

			-- Check if we're at max spawns for this RARITY
			if #activeThingsByRarity[rarity] >= config.MaxSpawns then
				continue
			end

			-- Always spawn (no random chance) - pick which thing from this rarity
			local thingName = ThingSpawner.PickRandomThingFromRarity(rarity)
			if thingName then
				ThingSpawner.SpawnSpecificThing(thingName, rarity)
			end
		end
	end
end

-- Pick a random thing from a rarity based on spawn weights
function ThingSpawner.PickRandomThingFromRarity(rarity)
	local weights = THING_SPAWN_WEIGHTS[rarity]
	if not weights then
		-- No weights defined, pick random from available things
		local things = RARITY_GROUPS[rarity]
		if things and #things > 0 then
			return things[math.random(1, #things)]
		end
		return nil
	end

	-- Calculate total weight
	local totalWeight = 0
	for _, weight in pairs(weights) do
		totalWeight = totalWeight + weight
	end

	-- Pick random weighted thing
	local randomValue = math.random() * totalWeight
	local currentWeight = 0

	for thingName, weight in pairs(weights) do
		currentWeight = currentWeight + weight
		if randomValue <= currentWeight then
			return thingName
		end
	end

	-- Fallback
	return nil
end

-- Spawn a specific thing by name
function ThingSpawner.SpawnSpecificThing(thingName, rarity)
	-- Get template and floor zone
	local template = thingTemplates[thingName]
	local floor = floorZones[rarity]

	if not template then
		warn("[ThingSpawner] No template for " .. thingName)
		return
	end

	if not floor then
		warn("[ThingSpawner] No floor zone for " .. rarity)
		return
	end

	-- Clone the thing (templates already have collision setup)
	local thing = template:Clone()

	-- Setup Handle GUI stuff
	local handle = thing:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then

		-- Setup ProximityPrompt
		local takePrompt = handle:FindFirstChild("TakePrompt")
		if takePrompt and takePrompt:IsA("ProximityPrompt") then
			takePrompt.ActionText = "Pick Up"
			takePrompt.ObjectText = template.Name
			takePrompt.MaxActivationDistance = 8
			takePrompt.RequiresLineOfSight = false
		else
			-- Create ProximityPrompt if it doesn't exist
			takePrompt = Instance.new("ProximityPrompt")
			takePrompt.Name = "TakePrompt"
			takePrompt.ActionText = "Pick Up"
			takePrompt.ObjectText = template.Name
			takePrompt.MaxActivationDistance = 8
			takePrompt.RequiresLineOfSight = false
			takePrompt.Parent = handle
		end

		-- Connect ProximityPrompt to carry system
		takePrompt.Triggered:Connect(function(player)
			-- Hide prompt IMMEDIATELY to prevent flashing
			takePrompt.Enabled = false

			local ThingCarryManager = require(script.Parent.ThingCarryManager)
			local success, message = ThingCarryManager.PickupThing(player, thing)
			if success then
				-- Hide TimerGui when picked up
				local timerGui = handle:FindFirstChild("TimerGui")
				if timerGui then
					timerGui.Enabled = false
				end
			else
				-- Re-enable if pickup failed
				takePrompt.Enabled = true
			end
		end)

		-- Setup StatsGui with rarity and base values
		local statsGui = handle:FindFirstChild("StatsGui")
		if statsGui then
			local frame = statsGui:FindFirstChild("Frame")
			if frame then
				-- Set Class (rarity) with color coding
				local classLabel = frame:FindFirstChild("Class")
				if classLabel and classLabel:IsA("TextLabel") then
					classLabel.Text = rarity

					-- Color code by rarity
					if rarity == "Common" then
						classLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White
					elseif rarity == "Uncommon" then
						classLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green
					elseif rarity == "Rare" then
						classLabel.TextColor3 = Color3.fromRGB(0, 112, 221) -- Blue
					elseif rarity == "Epic" then
						classLabel.TextColor3 = Color3.fromRGB(163, 53, 238) -- Purple
					elseif rarity == "Legendary" then
						classLabel.TextColor3 = Color3.fromRGB(255, 128, 0) -- Orange
					elseif rarity == "Mythical" then
						classLabel.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red
					elseif rarity == "Divine" then
						classLabel.TextColor3 = Color3.fromRGB(0, 255, 255) -- Cyan
					elseif rarity == "Secret" then
						classLabel.TextColor3 = Color3.fromRGB(0, 0, 0) -- Black					-- Add white UIStroke for Secret
					local uiStroke = classLabel:FindFirstChildOfClass("UIStroke")
					if not uiStroke then
						uiStroke = Instance.new("UIStroke")
						uiStroke.Parent = classLabel
					end
					uiStroke.Color = Color3.fromRGB(255, 255, 255) -- White stroke
					uiStroke.Thickness = 1					elseif rarity == "Celestial" then
						-- Celestial uses gradient
						local uiGradient = classLabel:FindFirstChildOfClass("UIGradient")
						if not uiGradient then
							uiGradient = Instance.new("UIGradient")
							uiGradient.Parent = classLabel
						end
						-- Gradient: light pink to bright pink
						uiGradient.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 255)), -- #ffaaff
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 85, 255)) -- #ff55ff
						}
						classLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- Base white (gradient overrides)
					elseif rarity == "Limited" then
						classLabel.TextColor3 = Color3.fromRGB(0, 0, 0) -- Black text
						-- Add white UIStroke for Limited
						local uiStroke = classLabel:FindFirstChildOfClass("UIStroke")
						if not uiStroke then
							uiStroke = Instance.new("UIStroke")
							uiStroke.Parent = classLabel
						end
						uiStroke.Color = Color3.fromRGB(255, 255, 255)
						uiStroke.Thickness = 1
						-- Add green gradient for Limited
						local uiGradient = classLabel:FindFirstChildOfClass("UIGradient")
						if not uiGradient then
							uiGradient = Instance.new("UIGradient")
							uiGradient.Parent = classLabel
						end
						uiGradient.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 255, 127)), -- #55ff7f
							ColorSequenceKeypoint.new(1, Color3.fromRGB(85, 255, 0)) -- #55ff00
						}
					end
				end

				-- Set Name
				local nameLabel = frame:FindFirstChild("Name")
				if nameLabel and nameLabel:IsA("TextLabel") then
					nameLabel.Text = template.Name

					-- Special styling for Love Knight name label
					if template.Name == "Love Knight" then
						nameLabel.TextColor3 = Color3.fromRGB(0, 0, 0) -- Black text

						-- Add white UIStroke
						local nameStroke = nameLabel:FindFirstChildOfClass("UIStroke")
						if not nameStroke then
							nameStroke = Instance.new("UIStroke")
							nameStroke.Parent = nameLabel
						end
						nameStroke.Color = Color3.fromRGB(255, 255, 255)
						nameStroke.Thickness = 1

						-- Add pink gradient
						local nameGradient = nameLabel:FindFirstChildOfClass("UIGradient")
						if not nameGradient then
							nameGradient = Instance.new("UIGradient")
							nameGradient.Parent = nameLabel
						end
						nameGradient.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 255)), -- #ffaaff
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 85, 255)) -- #ff55ff
						}
					end
				end

				-- Set Rate (money per SECOND) with extended formatting
				local rateLabel = frame:FindFirstChild("Rate")
				if rateLabel and rateLabel:IsA("TextLabel") then
					local ThingValueManager = require(script.Parent.ThingValueManager)
					local value = ThingValueManager.GetThingValueByName(template.Name, rarity)

					-- Format with extended suffixes matching MoneySpeedDisplay
					local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
					local tier = 1
					local num = value

					while num >= 1000 and tier < #suffixes do
						num = num / 1000
						tier = tier + 1
					end

					-- Check if it's a whole number
					local isWhole = (num == math.floor(num))

					local formatted
					if isWhole then
						formatted = string.format("$%.0f%s/s", num, suffixes[tier])
					elseif num >= 100 then
						formatted = string.format("$%.0f%s/s", num, suffixes[tier])
					elseif num >= 10 then
						formatted = string.format("$%.1f%s/s", num, suffixes[tier])
					else
						formatted = string.format("$%.2f%s/s", num, suffixes[tier])
					end
					rateLabel.Text = formatted
				end

				-- Randomly assign mutation (5% gold, 2% diamond, 0.5% emerald)
				local mutationLabel = frame:FindFirstChild("Mutation")
				local mutationType = ""
				if mutationLabel and mutationLabel:IsA("TextLabel") then
					local rand = math.random()
					if rand < 0.005 then
						mutationType = "Emerald"
						mutationLabel.Text = "Emerald"
					elseif rand < 0.025 then
						mutationType = "Diamond"
						mutationLabel.Text = "Diamond"
					elseif rand < 0.075 then
						mutationType = "Gold"
						mutationLabel.Text = "Gold"
					else
						mutationLabel.Text = ""
					end

					-- Set mutation attribute and apply effects
					if mutationType ~= "" then
						thing:SetAttribute("Mutation", mutationType)

						-- Apply visual mutation effects
						local MutationEffects = require(script.Parent.MutationEffects)
						MutationEffects.ApplyEffects(thing)

						-- Color the mutation text
						mutationLabel.TextColor3 = MutationEffects.GetMutationColor(mutationType)
					end
				end
			end
		end

		-- Add IsPickedUp attribute
		thing:SetAttribute("IsPickedUp", false)
		thing:SetAttribute("SpawnTime", os.time())
	end

	-- Create ActiveThings folder if doesn't exist
	local activeThingsFolder = Workspace:FindFirstChild("ActiveThings")
	if not activeThingsFolder then
		activeThingsFolder = Instance.new("Folder")
		activeThingsFolder.Name = "ActiveThings"
		activeThingsFolder.Parent = Workspace
	end

	-- Parent first, then position (so GetBoundingBox works correctly)
	thing.Parent = activeThingsFolder

	-- Setup collision on ALL parts IMMEDIATELY after parenting
	for _, part in ipairs(thing:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Anchored = true
			part.CollisionGroup = "CarriedThings"

			-- Special handling for Handle
			if part.Name == "Handle" then
				part.Transparency = 1
			end
		end
	end

	-- CRITICAL: Disable Humanoid physics (humanoids override collision settings)
	local humanoid = thing:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true -- Disables humanoid movement/physics

		-- Explicitly set HumanoidRootPart collision
		local rootPart = thing:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.CanCollide = false
			rootPart.CanTouch = false
			rootPart.CanQuery = false
			rootPart.Anchored = true
			rootPart.CollisionGroup = "CarriedThings"
		end
	end

	-- Get spawn position on floor
	local spawnPos = ThingSpawner.GetRandomPositionOnFloor(floor)

	-- Position the thing at spawn location
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

		-- Position with rotation (90 degrees on Y axis to face forward)
		local finalPosition = Vector3.new(spawnPos.X, currentY + yOffset, spawnPos.Z)
		local rotation = CFrame.Angles(0, math.rad(90), 0)
		thing:PivotTo(CFrame.new(finalPosition) * rotation)
	else
		thing.Position = spawnPos
		thing.CFrame = thing.CFrame * CFrame.Angles(0, math.rad(90), 0)
	end

	-- Find and start timer countdown after parenting
	local handle = thing:FindFirstChild("Handle")
	if handle then
		local timerGui = handle:FindFirstChild("TimerGui")
		if timerGui then
			-- Search for any TextLabel named TimeLeft
			for _, descendant in ipairs(timerGui:GetDescendants()) do
				if descendant:IsA("TextLabel") and descendant.Name == "TimeLeft" then
					local timeLeftLabel = descendant
					local countdownThread = task.spawn(function()
						for i = DESPAWN_TIME, 0, -1 do
							if thing and thing.Parent and not thing:GetAttribute("IsPickedUp") then
								timeLeftLabel.Text = tostring(i) .. "s"
								task.wait(1)
							else
								break
							end
						end
					end)
					-- Store the countdown thread so it can be cancelled when picked up
					thing:SetAttribute("CountdownThread", countdownThread)
					break
				end
			end
		end
	end

	-- Track the thing by RARITY
	table.insert(activeThingsByRarity[rarity], thing)

	-- Auto-despawn after 60 seconds if not picked up
	task.delay(DESPAWN_TIME, function()
		if thing and thing.Parent and not thing:GetAttribute("IsPickedUp") then
			thing:Destroy()
		end
	end)

	-- Setup cleanup when picked up or destroyed
	thing.AncestryChanged:Connect(function()
		if not thing:IsDescendantOf(Workspace) then
			ThingSpawner.RemoveFromActive(rarity, thing)
		end
	end)
end

-- Get random position within a floor zone
function ThingSpawner.GetRandomPositionOnFloor(floor)
	local parts = {}

	-- Check if floor itself is a BasePart (includes Part, MeshPart, UnionOperation, etc.)
	if floor:IsA("BasePart") then
		table.insert(parts, floor)
	end

	-- Also check children
	for _, child in ipairs(floor:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end

	if #parts == 0 then
		warn("[ThingSpawner] No parts found in floor: " .. floor:GetFullName())
		return Vector3.new(0, 0.5, 0)
	end

	-- Pick random part
	local randomPart = parts[math.random(1, #parts)]

	-- Get random X and Z position on the floor surface
	local size = randomPart.Size
	local pos = randomPart.Position

	local randomX = pos.X + (math.random() - 0.5) * size.X * 0.8
	local randomZ = pos.Z + (math.random() - 0.5) * size.Z * 0.8

	-- Always spawn at Y = 0 (ground level)
	return Vector3.new(randomX, 0, randomZ)
end

-- Remove thing from active tracking
function ThingSpawner.RemoveFromActive(rarity, thing)
	local activeList = activeThingsByRarity[rarity]
	if not activeList then return end

	for i, activeThing in ipairs(activeList) do
		if activeThing == thing then
			table.remove(activeList, i)
			break
		end
	end
end

-- Get thing data from StatsGui
function ThingSpawner.GetThingData(thing)
	local handle = thing:FindFirstChild("Handle")
	if not handle then return nil end

	local statsGui = handle:FindFirstChild("StatsGui")
	if not statsGui then return nil end

	local frame = statsGui:FindFirstChild("Frame")
	if not frame then return nil end

	local classLabel = frame:FindFirstChild("Class")
	local nameLabel = frame:FindFirstChild("Name")
	local mutationLabel = frame:FindFirstChild("Mutation")

	return {
		Rarity = classLabel and classLabel.Text or "Common",
		IsPickedUp = thing:GetAttribute("IsPickedUp") or false,
		ThingName = nameLabel and nameLabel.Text or thing.Name,
		Mutation = mutationLabel and mutationLabel.Text or "None"
	}
end

return ThingSpawner
