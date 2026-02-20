-- Admin Money & Speed Giver with Chat Commands (Game 2)
-- Place in ServerScriptService temporarily for testing

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

-- Load EventManager for event control commands
local EventManager = require(ServerScriptService.GameManager.EventManager)

-- Track admin countdown task so we can cancel it
local adminCountdownTask = nil

-- All things in the game organized by rarity (Game 2)
local ALL_THINGS = {
	Common = {"Wooden Sword", "Stone Axe", "Leather Boots", "Iron Dagger", "Training Bow"},
	Uncommon = {"Steel Sword", "Iron Axe", "Chain Mail", "Silver Dagger", "Oak Bow"},
	Rare = {"Enchanted Sword", "Battle Axe", "Knight's Armor", "Ruby Dagger", "Longbow"},
	Epic = {"Holy Sword", "Dragon Axe", "Paladin Armor", "Diamond Dagger", "Elvish Bow"},
	Legendary = {"Excalibur", "Thunder Hammer", "Dragon Scale Armor", "Obsidian Blade", "Phoenix Bow"},
	Mythical = {"Frostblade", "Mjolnir", "Celestial Armor", "Shadowfang Dagger", "Starlight Bow"},
	Divine = {"Sword of Light", "Earthquake Hammer", "Angelic Plate", "Voidreaver Dagger", "Moonbeam Bow"},
	Secret = {"Blade of Eternity", "Godslayer Hammer", "Immortal Armor", "Soulstealer Dagger", "Infinity Bow"},
	Celestial = {"Angel", "Angry Deer", "Snowman"},
	Limited = {"Love Ram"}
}

-- Give money and speed to specific player
local function giveStuff(playerName, moneyAmount, speedAmount, rebirthAmount)
	for _, player in pairs(Players:GetPlayers()) do
		if player.Name == playerName then
			-- Wait for leaderstats to exist
			local leaderstats = player:WaitForChild("leaderstats", 5)
			if leaderstats then
				local money = leaderstats:FindFirstChild("Money")
				if money then
					print("[GiveMoney2:30] Adding money via command:", moneyAmount, "| Current:", money.Value, "| New:", money.Value + moneyAmount)
					money.Value = money.Value + moneyAmount
					print("Gave", moneyAmount, "money to", player.Name, "| New balance:", money.Value)
				end
				
				-- Give rebirths
				if rebirthAmount then
					local rebirths = leaderstats:FindFirstChild("Rebirths")
					if rebirths then
						rebirths.Value = rebirthAmount
						player:SetAttribute("Rebirths", rebirthAmount)
						local multiplier = 1 + (rebirthAmount * 0.5)
						player:SetAttribute("RebirthMultiplier", multiplier)
						print("Set", player.Name, "rebirths to", rebirthAmount, "(" .. multiplier .. "x multiplier)")
					else
						warn("Rebirths leaderstat not found for", player.Name)
					end
				end
			end
			
			-- Give speed
			player:SetAttribute("Speed", speedAmount)
			
			-- Update walkspeed if character exists
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = speedAmount
				end
			end
			
			print("Set", player.Name, "speed to", speedAmount)
			return true
		end
	end
	warn("Player not found:", playerName)
	return false
end

-- Chat command handler
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		-- Only allow specific user to use admin commands (more secure than username)
		if player.UserId ~= 8921430843 then
			return
		end
		
		local lowerMsg = message:lower()
		
		-- Start an event manually: /startevent night OR /startevent love (GLOBAL - ALL SERVERS)
		if lowerMsg:match("^/startevent%s+%w+$") then
			local eventType = lowerMsg:match("%s(%w+)$")
			eventType = eventType:sub(1,1):upper() .. eventType:sub(2):lower() -- Capitalize first letter
			
			if eventType == "Night" or eventType == "Love" then
				-- Cancel any existing admin countdown
				if adminCountdownTask then
					task.cancel(adminCountdownTask)
					adminCountdownTask = nil
				end
				
				-- Publish to ALL servers globally
				local success = EventManager.PublishGlobalStartEvent(eventType)
				
				if success then
					print(player.Name, "started", eventType, "Event GLOBALLY across all servers")
					
					-- Send notification
					local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
					local notificationEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("Notification")
					if notificationEvent then
						notificationEvent:FireClient(player, "⚡ Started " .. eventType .. " Event GLOBALLY!", nil, Color3.fromRGB(255, 215, 0), 5)
					end
				else
					warn("Failed to publish global event command")
				end
			else
				warn("Invalid event type. Use: night or love")
			end
			
		-- Start an event locally (STUDIO TESTING - Current server only)
		elseif lowerMsg:match("^/startevent_local%s+%w+$") then
			local eventType = lowerMsg:match("%s(%w+)$")
			eventType = eventType:sub(1,1):upper() .. eventType:sub(2):lower()
			
			if eventType == "Night" or eventType == "Love" then
				-- Cancel any existing admin countdown
				if adminCountdownTask then
					task.cancel(adminCountdownTask)
					adminCountdownTask = nil
				end
				
				-- End current event if one is active
				if EventManager.IsAnyEventActive() then
					EventManager.EndEvent()
					task.wait(0.5)
				end
				
				-- Pause automatic timer updates
				EventManager.PauseTimerUpdates()
				
				-- Start the event locally
				EventManager.StartEvent(eventType)
				print(player.Name, "started", eventType, "Event LOCALLY (this server only)")
				
				-- Send notification
				local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
				local notificationEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("Notification")
				if notificationEvent then
					notificationEvent:FireClient(player, "⚡ Started " .. eventType .. " Event (Local)", nil, Color3.fromRGB(255, 165, 0), 3)
				end
				
				-- Start countdown loop (5 minutes)
				local eventTimerBindable = remoteEventsFolder and remoteEventsFolder:FindFirstChild("EventTimerUpdate")
				if eventTimerBindable then
					adminCountdownTask = task.spawn(function()
						for timeRemaining = 300, 0, -1 do
							eventTimerBindable:Fire(eventType, timeRemaining)
							if timeRemaining > 0 then
								task.wait(1)
							end
						end
						-- Event finished, end it
						EventManager.EndEvent()
						
						-- Start 30-minute countdown
						for timeRemaining = 1800, 0, -1 do
							eventTimerBindable:Fire(nil, timeRemaining)
							if timeRemaining > 0 then
								task.wait(1)
							end
						end
						
						-- Resume automatic cycle
						EventManager.ResumeTimerUpdates()
						adminCountdownTask = nil
					end)
				end
			else
				warn("Invalid event type. Use: night or love")
			end
			
		-- End event locally (STUDIO TESTING - Current server only)
		elseif lowerMsg == "/endevent_local" then
			-- Cancel any admin countdown task
			if adminCountdownTask then
				task.cancel(adminCountdownTask)
				adminCountdownTask = nil
			end
			
			if EventManager.IsAnyEventActive() then
				local currentEvent = EventManager.GetActiveEvent()
				EventManager.EndEvent()
				print(player.Name, "ended", currentEvent.Type, "Event LOCALLY")
				
				-- Send notification
				local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
				local notificationEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("Notification")
				if notificationEvent then
					notificationEvent:FireClient(player, "⚡ Ended event (Local)", nil, Color3.fromRGB(255, 165, 0), 3)
				end
				
				-- Start 30-minute countdown
				local eventTimerBindable = remoteEventsFolder and remoteEventsFolder:FindFirstChild("EventTimerUpdate")
				if eventTimerBindable then
					adminCountdownTask = task.spawn(function()
						for timeRemaining = 1800, 0, -1 do
							eventTimerBindable:Fire(nil, timeRemaining)
							if timeRemaining > 0 then
								task.wait(1)
							end
						end
						
						-- Resume automatic cycle
						EventManager.ResumeTimerUpdates()
						adminCountdownTask = nil
					end)
				end
			else
				print(player.Name, "tried to end event but no event is active")
			end
			
		-- End current event: /endevent (GLOBAL - ALL SERVERS)
		elseif lowerMsg == "/endevent" then
			-- Cancel any admin countdown task
			if adminCountdownTask then
				task.cancel(adminCountdownTask)
				adminCountdownTask = nil
			end
			
			if EventManager.IsAnyEventActive() then
				-- Publish to ALL servers globally
				local success = EventManager.PublishGlobalEndEvent()
				
				if success then
					print(player.Name, "ended event GLOBALLY across all servers")
					
					-- Send notification
					local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
					local notificationEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("Notification")
					if notificationEvent then
						notificationEvent:FireClient(player, "⚡ Ended event GLOBALLY!", nil, Color3.fromRGB(255, 215, 0), 5)
					end
				else
					warn("Failed to publish global end event")
				end
			else
				print(player.Name, "tried to end event but no event is active")
			end
			
		-- Check what event is active: /checkevent
		elseif lowerMsg == "/checkevent" then
			if EventManager.IsAnyEventActive() then
				local currentEvent = EventManager.GetActiveEvent()
				print("Current event:", currentEvent.Type, "| Started at:", currentEvent.StartTime)
				
				-- Send notification
				local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
				local notificationEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("Notification")
				if notificationEvent then
					notificationEvent:FireClient(player, "Current Event: " .. currentEvent.Type, nil, Color3.fromRGB(255, 255, 0), 3)
				end
			else
				print("No event currently active")
				
				-- Send notification
				local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
				local notificationEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("Notification")
				if notificationEvent then
					notificationEvent:FireClient(player, "No event currently active", nil, Color3.fromRGB(255, 255, 0), 3)
				end
			end
			
		-- Give specific thing with mutation: /givething [name] [mutation]
		elseif lowerMsg:match("^/givething%s+.+") then
			local args = message:sub(12) -- Remove "/givething "
			local mutation = ""
			local thingName = args
			
			-- Check if mutation is specified (last word)
			local mutations = {"gold", "diamond", "emerald", "night", "love", "none"}
			for _, mut in ipairs(mutations) do
				if args:lower():match("%s" .. mut .. "$") then
					mutation = mut == "none" and "" or (mut:sub(1,1):upper() .. mut:sub(2):lower())
					thingName = args:sub(1, -(#mut + 2)) -- Remove mutation from name
					break
				end
			end
			
			-- Find the rarity of this thing
			local foundRarity = nil
			for rarity, things in pairs(ALL_THINGS) do
				for _, name in ipairs(things) do
					if name:lower() == thingName:lower() then
						foundRarity = rarity
						thingName = name -- Use correct capitalization
						break
					end
				end
				if foundRarity then break end
			end
			
			if foundRarity then
				local ThingInventoryManager = require(ServerScriptService.Things.ThingInventoryManager)
				local ThingValueManager = require(ServerScriptService.Things.ThingValueManager)
				
				-- Calculate rate with mutation applied
				local baseRate = ThingValueManager.GetThingValueByName(thingName, foundRarity)
				
				-- Apply mutation multiplier
				local mutationMultiplier = 1
				if mutation == "Gold" then
					mutationMultiplier = 1.5
				elseif mutation == "Diamond" then
					mutationMultiplier = 2
				elseif mutation == "Emerald" then
					mutationMultiplier = 3
				elseif mutation == "Night" then
					mutationMultiplier = 2
				elseif mutation == "Love" then
					mutationMultiplier = 3
				end
				
				local rate = baseRate * mutationMultiplier
				
				local success, msg = ThingInventoryManager.AddToInventory(
					player,
					thingName,
					mutation,
					foundRarity,
					rate,
					{},
					0
				)
				
				if success then
					local mutText = mutation ~= "" and (" with " .. mutation .. " mutation") or ""
					print(player.Name, "received", thingName, mutText, "- Rate:", rate, "/sec")
				else
					warn("Failed to add", thingName, ":", msg)
				end
			else
				warn("Thing not found:", thingName)
				print("Use exact name like: /givething Angel love")
			end
			
		-- Reset speed to 18
		elseif lowerMsg == "/resetspeed" then
			player:SetAttribute("Speed", 18)
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 18
				end
			end
			print(player.Name, "reset speed to 18")
			
		-- Reset carry to 1
		elseif lowerMsg == "/resetcarry" then
			player:SetAttribute("CarryCapacity", 1)
			print(player.Name, "reset carry to 1")
			
		-- Give rebirths: /giverebirths 5
		elseif lowerMsg:match("^/giverebirths%s+%d+$") then
			local amount = tonumber(lowerMsg:match("%d+"))
			if amount and amount >= 0 and amount <= 10 then
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local rebirths = leaderstats:FindFirstChild("Rebirths")
					if rebirths then
						rebirths.Value = amount
						player:SetAttribute("Rebirths", amount)
						local multiplier = 1 + (amount * 0.5)
						player:SetAttribute("RebirthMultiplier", multiplier)
						print(player.Name, "set rebirths to", amount, "(" .. multiplier .. "x multiplier)")
					else
						warn("Rebirths leaderstat not found for", player.Name)
					end
				else
					warn("leaderstats not found for", player.Name)
				end
			else
				warn("Invalid rebirth amount:", amount)
			end
			
		-- Wipe floor (reset base upgrade level): /wipefloor
		elseif lowerMsg == "/wipefloor" then
			player:SetAttribute("BaseUpgradeLevel", 0)
			print(player.Name, "reset base upgrade level to 0")
			
		-- Set base upgrade level: /setfloor 10
		elseif lowerMsg:match("^/setfloor%s+%d+$") then
			local level = tonumber(lowerMsg:match("%d+"))
			if level and level >= 0 and level <= 20 then
				player:SetAttribute("BaseUpgradeLevel", level)
				print(player.Name, "set base upgrade level to", level)
			end
			
		-- Set carry to specific amount: /setcarry 5
		elseif lowerMsg:match("^/setcarry%s+%d+$") then
			local amount = tonumber(lowerMsg:match("%d+"))
			if amount and amount >= 1 and amount <= 10 then
				player:SetAttribute("CarryCapacity", amount)
				print(player.Name, "set carry to", amount)
			end
			
		-- Set speed to specific amount: /setspeed 50
		elseif lowerMsg:match("^/setspeed%s+%d+$") then
			local amount = tonumber(lowerMsg:match("%d+"))
			if amount and amount >= 18 and amount <= 2000 then
				player:SetAttribute("Speed", amount)
				local character = player.Character
				if character then
					local humanoid = character:FindFirstChild("Humanoid")
					if humanoid then
						humanoid.WalkSpeed = amount
					end
				end
				print(player.Name, "set speed to", amount)
			end
			
		-- Give money: /givemoney 1000000
		elseif lowerMsg:match("^/givemoney%s+%d+$") then
			local amount = tonumber(lowerMsg:match("%d+"))
			if amount then
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local money = leaderstats:FindFirstChild("Money")
					if money then
						print("[GiveMoney2:157] Adding money via /givemoney command:", amount, "| Current:", money.Value, "| New:", money.Value + amount)
						money.Value = money.Value + amount
						print(player.Name, "gave themselves", amount, "money")
					end
				end
			end
			
		-- Reset everything to defaults
		elseif lowerMsg == "/resetall" then
			player:SetAttribute("Speed", 18)
			player:SetAttribute("CarryCapacity", 1)
			player:SetAttribute("BaseUpgradeLevel", 0)
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 18
				end
			end
			-- Also reset money
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local money = leaderstats:FindFirstChild("Money")
				if money then
					print("[GiveMoney2:180] Resetting money to 0 via /resetall for", player.Name, "| Current:", money.Value)
					money.Value = 0
				end
			end
			print(player.Name, "reset all stats to defaults")
			
		-- Give all things in the game: /giveallthings
		elseif lowerMsg == "/giveallthings" then
			local ThingInventoryManager = require(ServerScriptService.Things.ThingInventoryManager)
			local count = 0
			
			-- Loop through all rarities and give one of each thing
			for rarity, things in pairs(ALL_THINGS) do
				for _, thingName in ipairs(things) do
					local success, msg = ThingInventoryManager.AddToInventory(
						player,
						thingName,
						"", -- No mutation (blank)
						rarity,
						nil, -- rate will be calculated
						{}, -- empty guiData
						0 -- level 0
					)
					
					if success then
						count = count + 1
					else
						warn("Failed to add", thingName, ":", msg)
					end
					
					task.wait(0.05) -- Small delay to prevent lag
				end
			end
			
			print(player.Name, "received", count, "things!")
			
		-- Give all things with gold mutation: /giveallgold
		elseif lowerMsg == "/giveallgold" then
			local ThingInventoryManager = require(ServerScriptService.Things.ThingInventoryManager)
			local count = 0
			
			-- Loop through all rarities and give one gold version of each thing
			for rarity, things in pairs(ALL_THINGS) do
				for _, thingName in ipairs(things) do
					local success, msg = ThingInventoryManager.AddToInventory(
						player,
						thingName,
						"Gold", -- Gold mutation
						rarity,
						nil,
						{},
						0
					)
					
					if success then
						count = count + 1
					end
					
					task.wait(0.05)
				end
			end
			
			print(player.Name, "received", count, "gold things!")
			
		-- Give all celestials: /giveallcelestials
		elseif lowerMsg == "/giveallcelestials" then
			local ThingInventoryManager = require(ServerScriptService.Things.ThingInventoryManager)
			local celestials = ALL_THINGS.Celestial
			local count = 0
			
			if celestials then
				for _, thingName in ipairs(celestials) do
					local success, msg = ThingInventoryManager.AddToInventory(
						player,
						thingName,
						"", -- No mutation
						"Celestial",
						nil,
						{},
						0
					)
					
					if success then
						count = count + 1
						print("Added Celestial:", thingName)
					else
						warn("Failed to add", thingName, ":", msg)
					end
					
					task.wait(0.05)
				end
			end
			
			print(player.Name, "received", count, "celestial items!")
			
		-- Spawn a celestial item: /spawncelestial
		elseif lowerMsg == "/spawncelestial" then
			-- Pick a random celestial item
			local celestialThings = ALL_THINGS.Celestial
			if celestialThings and #celestialThings > 0 then
				local randomIndex = math.random(1, #celestialThings)
				local thingName = celestialThings[randomIndex]
				
				-- Get ThingSpawner
				local ThingSpawner = require(ServerScriptService.Things.ThingSpawner)
				
				-- Spawn the celestial thing
				ThingSpawner.SpawnSpecificThing(thingName, "Celestial")
				
				-- Send notifications to all players
				local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
				local notificationEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("Notification")
				local playSoundEvent = remoteEventsFolder and remoteEventsFolder:FindFirstChild("PlaySoundEvent")
				
				if notificationEvent then
					for _, p in Players:GetPlayers() do
						notificationEvent:FireClient(p, "🌟 A Celestial " .. thingName .. " has spawned!", nil, Color3.fromRGB(255, 170, 255), 5)
						
						if playSoundEvent then
							playSoundEvent:FireClient(p, "ClaimSound", 0.7, 1, nil)
						end
					end
				end
				
				print(player.Name, "spawned a Celestial:", thingName)
			else
				warn("No celestial things found!")
			end
		end
	end)
end)

-- Give UnempIoymen 99 trillion and 99 speed on startup
task.wait(3) -- Wait longer for player to fully load
giveStuff("UnempIoymen", 99000000000000, 99, 1) -- 99T money, 99 speed, 1 rebirth

print("Admin command system (Game 2) loaded!")
print("Commands:")
print("  /resetspeed - Reset speed to 18")
print("  /resetcarry - Reset carry to 1")
print("  /setcarry [1-10] - Set carry capacity")
print("  /setspeed [18-2000] - Set speed")
print("  /givemoney [amount] - Give money")
print("  /giverebirths [0-10] - Set rebirth count")
print("  /wipefloor - Reset base upgrade level to 0")
print("  /setfloor [0-20] - Set base upgrade level")
print("  /resetall - Reset everything to defaults")
print("  /giveallthings - Give yourself all items in the game")
print("  /giveallgold - Give all items with gold mutation")
print("  /giveallcelestials - Give all celestial items (Angel, Angry Deer, Snowman)")
print("  /givething [name] [mutation] - Give specific thing (e.g., /givething Angel love)")
print("  /spawncelestial - Spawn a random celestial item instantly")
print("  /startevent [night/love] - Start a specific event GLOBALLY (all servers)")
print("  /endevent - End the current event GLOBALLY (all servers)")
print("  /startevent_local [night/love] - Start event on THIS server only (for Studio testing)")
print("  /endevent_local - End event on THIS server only (for Studio testing)")
print("  /checkevent - Check what event is currently active")
