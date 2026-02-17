-- ZoneDisplay.lua
-- Shows which zone/floor the player is currently in
-- Place in: StarterGui/Zone/

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Get UI elements (script is inside Zone ScreenGui)
local zoneGui = script.Parent
local zoneFrame = zoneGui:WaitForChild("Frame", 5)
if not zoneFrame then
	warn("[ZoneDisplay] Frame not found in Zone!")
	return
end

local zoneLabel = zoneFrame:WaitForChild("Area", 5)
if not zoneLabel then
	warn("[ZoneDisplay] Area TextLabel not found!")
	return
end

-- Get the UIStroke that already exists
local uiStroke = zoneLabel:FindFirstChildOfClass("UIStroke")

-- Hide UI on start
zoneFrame.Visible = false

-- Rarity colors (matching ThingSpawner)
local ZONE_COLORS = {
	Common = Color3.fromRGB(129, 129, 129),      -- Grey
	Uncommon = Color3.fromRGB(0, 255, 0),        -- Green
	Rare = Color3.fromRGB(0, 112, 221),          -- Blue
	Epic = Color3.fromRGB(163, 53, 238),         -- Purple
	Legendary = Color3.fromRGB(255, 128, 0),     -- Orange
	Mythical = Color3.fromRGB(255, 0, 0),        -- Red
	Divine = Color3.fromRGB(0, 255, 255),        -- Cyan
	Secret = Color3.fromRGB(0, 0, 0),            -- Black
	Celestial = Color3.fromRGB(128, 0, 255),     -- Purple (approximation of gradient)
	Limited = Color3.fromRGB(255, 0, 127)        -- Hot pink
}

-- Default zone when not on any floor
local DEFAULT_ZONE = "Lobby"
local DEFAULT_COLOR = Color3.fromRGB(200, 200, 200)

-- Current zone tracking
local currentZone = DEFAULT_ZONE
local currentColor = DEFAULT_COLOR

-- Function to get character position
local function getCharacterPosition()
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			return rootPart.Position
		end
	end
	return nil
end

-- Wait for character to fully load
repeat wait() until player.Character
repeat wait() until player.Character:FindFirstChild("HumanoidRootPart")

-- Function to check which floor player is standing on using raycast
local function detectCurrentZone()
	local character = player.Character
	if not character then 
		return DEFAULT_ZONE, DEFAULT_COLOR 
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return DEFAULT_ZONE, DEFAULT_COLOR
	end
	
	-- Raycast downward from character to detect floor
	local rayOrigin = rootPart.Position
	local rayDirection = Vector3.new(0, -50, 0) -- Cast 50 studs down
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character}
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	
	local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if rayResult then
		local hitPart = rayResult.Instance
		
		-- Walk up the parent hierarchy to find Map/Floors specifically
		local current = hitPart
		while current do
			if current.Parent and current.Parent.Name == "Floors" and current.Parent.Parent and current.Parent.Parent.Name == "Map" then
				-- Found a floor zone in Map/Floors!
				local zoneName = current.Name
				local zoneColor = ZONE_COLORS[zoneName] or DEFAULT_COLOR
				return zoneName, zoneColor
			end
			current = current.Parent
		end
	end
	
	return nil, nil -- Return nil when not on a floor
end

-- Update zone display
local function updateZoneDisplay()
	local zone, color = detectCurrentZone()
	
	-- Only update if zone changed
	if zone ~= currentZone then
		currentZone = zone
		currentColor = color
		
		-- If not on a floor (zone is nil), hide the UI
		if not zone then
			zoneFrame.Visible = false
			return
		end
		
		-- Show UI and update only text and color
		zoneFrame.Visible = true
		zoneLabel.Text = currentZone
		zoneLabel.TextColor3 = color
		
		-- Set stroke color: white for Secret zone, reset to black for others
		if uiStroke then
			if color == Color3.fromRGB(0, 0, 0) then
				uiStroke.Color = Color3.fromRGB(255, 255, 255) -- White for Secret
			else
				uiStroke.Color = Color3.fromRGB(0, 0, 0) -- Black for all other zones
			end
		end
	end
end

-- Initial zone update
wait(0.5)
updateZoneDisplay()

-- Handle respawns
player.CharacterAdded:Connect(function()
	repeat wait() until player.Character:FindFirstChild("HumanoidRootPart")
	wait(0.5)
	updateZoneDisplay()
end)

-- Update continuously (checks every frame but only updates UI when zone changes)
local lastUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastUpdate >= 0.3 then -- Update every 0.3 seconds
		lastUpdate = now
		updateZoneDisplay()
	end
end)