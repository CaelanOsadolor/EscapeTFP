-- ExampleThingCreator.lua
-- Run this once in Studio to create example "things" for testing
-- This creates placeholder models that you can replace with your own

local ServerStorage = game:GetService("ServerStorage")

local function createExampleThing(name, rarity, color)
	local thing = Instance.new("Model")
	thing.Name = name
	
	-- Create main part
	local part = Instance.new("Part")
	part.Name = "MainPart"
	part.Size = Vector3.new(2, 2, 2)
	part.BrickColor = BrickColor.new(color)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.Parent = thing
	
	-- Create label
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard
	
	thing.PrimaryPart = part
	
	return thing
end

local function setupThingsFolder()
	-- Create Things folder in ServerStorage
	local thingsFolder = ServerStorage:FindFirstChild("Things")
	if not thingsFolder then
		thingsFolder = Instance.new("Folder")
		thingsFolder.Name = "Things"
		thingsFolder.Parent = ServerStorage
		print("Created Things folder in ServerStorage")
	end
	
	-- Rarity definitions
	local rarities = {
		{name = "Common", color = "Light stone grey", things = {"Rock", "Stick", "Pebble", "Leaf", "Shell"}},
		{name = "Uncommon", color = "Bright green", things = {"Flower", "Coin", "Feather", "Bottle", "Crystal"}},
		{name = "Rare", color = "Bright blue", things = {"Gem", "Ring", "Amulet", "Orb", "Rune"}},
		{name = "Epic", color = "Bright violet", things = {"Crown", "Sword", "Staff", "Shield", "Helm"}},
		{name = "Legendary", color = "Bright orange", things = {"Dragon Scale", "Phoenix Feather", "Unicorn Horn", "Mermaid Tear", "Griffin Claw"}},
		{name = "Mythical", color = "Bright purple", things = {"Star Fragment", "Moon Shard", "Sun Core", "Nebula Essence", "Void Crystal"}},
		{name = "Cosmic", color = "Cyan", things = {"Galaxy Stone", "Astral Heart", "Cosmic Dust", "Celestial Core", "Universe Seed"}},
		{name = "Secret", color = "New Yeller", things = {"Golden Trophy", "Diamond Key", "Platinum Crown", "Emerald Heart", "Ruby Eye"}}
	}
	
	-- Create things for each rarity
	for _, rarityData in ipairs(rarities) do
		local rarityFolder = thingsFolder:FindFirstChild(rarityData.name)
		if not rarityFolder then
			rarityFolder = Instance.new("Folder")
			rarityFolder.Name = rarityData.name
			rarityFolder.Parent = thingsFolder
			print("Created " .. rarityData.name .. " folder")
		end
		
		-- Create example things
		for _, thingName in ipairs(rarityData.things) do
			if not rarityFolder:FindFirstChild(thingName) then
				local thing = createExampleThing(thingName, rarityData.name, rarityData.color)
				thing.Parent = rarityFolder
				print("Created " .. rarityData.name .. " thing: " .. thingName)
			end
		end
	end
	
	print("=================================")
	print("Example things created successfully!")
	print("Check ServerStorage/Things/")
	print("Replace these with your own models!")
	print("=================================")
end

-- Run the setup
setupThingsFolder()
