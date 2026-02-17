-- FloorZoneSetup.lua
-- Run this once in Studio to create example floor zones for testing
-- Replace these with your actual map floors

local Workspace = game:GetService("Workspace")

local function createFloorZone(name, position, color)
	local floor = Instance.new("Model")
	floor.Name = name
	
	-- Create main floor part
	local part = Instance.new("Part")
	part.Name = "Floor"
	part.Size = Vector3.new(50, 1, 50)
	part.Position = position
	part.Anchored = true
	part.BrickColor = BrickColor.new(color)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.3
	part.Parent = floor
	
	-- Add label
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = name .. " Floor"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard
	
	return floor
end

local function setupFloorZones()
	-- Create Map folder
	local map = Workspace:FindFirstChild("Map")
	if not map then
		map = Instance.new("Folder")
		map.Name = "Map"
		map.Parent = Workspace
		print("Created Map folder in Workspace")
	end
	
	-- Create Floors folder
	local floors = map:FindFirstChild("Floors")
	if not floors then
		floors = Instance.new("Folder")
		floors.Name = "Floors"
		floors.Parent = map
		print("Created Floors folder")
	end
	
	-- Floor definitions (stacked vertically for testing)
	local floorData = {
		{name = "Common", yPos = 0, color = "Light stone grey"},
		{name = "Uncommon", yPos = 20, color = "Bright green"},
		{name = "Rare", yPos = 40, color = "Bright blue"},
		{name = "Epic", yPos = 60, color = "Bright violet"},
		{name = "Legendary", yPos = 80, color = "Bright orange"},
		{name = "Mythical", yPos = 100, color = "Bright purple"},
		{name = "Cosmic", yPos = 120, color = "Cyan"},
		{name = "Secret", yPos = 140, color = "New Yeller"}
	}
	
	-- Create floors
	for i, data in ipairs(floorData) do
		if not floors:FindFirstChild(data.name) then
			-- Position floors in a spiral pattern
			local angle = (i - 1) * (math.pi / 4)
			local radius = 100
			local x = math.cos(angle) * radius
			local z = math.sin(angle) * radius
			
			local position = Vector3.new(x, data.yPos, z)
			local floor = createFloorZone(data.name, position, data.color)
			floor.Parent = floors
			
			print("Created " .. data.name .. " floor at height " .. data.yPos)
		end
	end
	
	print("=================================")
	print("Floor zones created successfully!")
	print("Check Workspace/Map/Floors/")
	print("Move these to match your actual map!")
	print("=================================")
end

-- Run the setup
setupFloorZones()
