-- Admin Money & Speed Giver with Chat Commands (Game 3)
-- Place in ServerScriptService temporarily for testing

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

-- All things in the game organized by rarity (Game 3)
local ALL_THINGS = {
	Common = {"Black", "Blue", "Green", "Pink", "Red", "Yellow"},
	Uncommon = {"Banana", "FastFood", "Festive", "Painter"},
	Rare = {"Bandit", "Bronze", "Cook", "Judge", "Police", "Snowman"},
	Epic = {"Fancy", "Icecream", "Knight", "Silver"},
	Legendary = {"Gold", "Scholar", "Sleepy", "Snowy", "TRex"},
	Mythical = {"Celebrity", "Chubby", "Ruby", "Seal"},
	Divine = {"Astral", "Boxer", "Diamond", "Neon Samurai", "Wizard"},
	Secret = {"Chill Bro", "King", "Spino", "Yeti"},
	Celestial = {"Angel", "Frostbite", "HeartBreaker", "Space"},
	Limited = {"Love Knight"}
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
					print("[GiveMoney3:30] Adding money via command:", moneyAmount, "| Current:", money.Value, "| New:", money.Value + moneyAmount)
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
		-- Only allow UnempIoymen to use admin commands
		if player.Name ~= "UnempIoymen" then
			return
		end
		
		local lowerMsg = message:lower()
		
		-- Reset speed to 18
		if lowerMsg == "/resetspeed" then
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
						print("[GiveMoney3:157] Adding money via /givemoney command:", amount, "| Current:", money.Value, "| New:", money.Value + amount)
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
					print("[GiveMoney3:180] Resetting money to 0 via /resetall for", player.Name, "| Current:", money.Value)
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
		
		-- Give specific thing: /givething [thingName] [mutation] or /givething [playerName] [thingName] [mutation]
		elseif lowerMsg:match("^/givething%s+") then
			local args = {}
			for word in message:gmatch("%S+") do
				if word ~= "/givething" then
					table.insert(args, word)
				end
			end
			
			local targetPlayer = nil
			local thingName = nil
			local mutation = ""
			
			-- Check if first arg is a player name
			if #args >= 2 then
				-- Try to find player by name
				for _, p in Players:GetPlayers() do
					if p.Name:lower() == args[1]:lower() then
						targetPlayer = p
						-- Rest of args is the thing name and possibly mutation
						table.remove(args, 1)
						break
					end
				end
			end
			
			-- If no player found, give to self
			if not targetPlayer then
				targetPlayer = player
			end
			
			-- Check if last arg is a mutation (Gold, Diamond, Emerald)
			local knownMutations = {"gold", "diamond", "emerald"}
			if #args > 0 then
				local lastArg = args[#args]:lower()
				for _, mut in ipairs(knownMutations) do
					if lastArg == mut then
						mutation = args[#args] -- Use original capitalization
						table.remove(args, #args) -- Remove mutation from args
						break
					end
				end
			end
			
			-- Remaining args are the thing name
			thingName = table.concat(args, " ")
			
			-- Find which rarity this thing belongs to
			local foundRarity = nil
			for rarity, things in pairs(ALL_THINGS) do
				for _, itemName in ipairs(things) do
					if itemName:lower() == thingName:lower() then
						foundRarity = rarity
						thingName = itemName -- Use exact capitalization
						break
					end
				end
				if foundRarity then break end
			end
			
			if foundRarity then
				local ThingInventoryManager = require(ServerScriptService.Things.ThingInventoryManager)
				local success, msg = ThingInventoryManager.AddToInventory(
					targetPlayer,
					thingName,
					mutation, -- Use specified mutation or empty string
					foundRarity,
					nil, -- rate will be calculated
					{}, -- empty guiData
					0 -- level 0
				)
				
				if success then
					local mutationText = mutation ~= "" and (" (" .. mutation .. ")") or ""
					if targetPlayer == player then
						print(player.Name, "gave themselves", thingName .. mutationText, "(" .. foundRarity .. ")")
					else
						print(player.Name, "gave", thingName .. mutationText, "(" .. foundRarity .. ") to", targetPlayer.Name)
					end
				else
					warn("Failed to give", thingName, "to", targetPlayer.Name, ":", msg)
				end
			else
				warn("Thing not found:", thingName)
			end
		end
	end)
end)

-- Give UnempIoymen 99 trillion and 99 speed on startup
task.wait(3) -- Wait longer for player to fully load
giveStuff("UnempIoymen", 99000000000000, 99, 1) -- 99T money, 99 speed, 1 rebirth

print("Admin command system (Game 3) loaded!")
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
print("  /giveallcelestials - Give all celestial items (Angel, Frostbite, HeartBreaker, Space)")
print("  /spawncelestial - Spawn a random celestial item instantly")
print("  /givething [thingName] - Give yourself a specific thing (e.g., /givething Love Knight)")
print("  /givething [thingName] [mutation] - Give yourself a thing with mutation (e.g., /givething King Gold)")
print("  /givething [playerName] [thingName] - Give a specific thing to another player")
print("  /givething [playerName] [thingName] [mutation] - Give with mutation (Gold, Diamond, Emerald)")
