-- VIPWallHandler (LocalScript)
-- Place in StarterPlayer > StarterPlayerScripts
-- Handles client-side VIP wall visibility

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local VIP_GAMEPASS_ID = 1669012678

-- Function to check if player owns VIP gamepass
local function ownsVIP()
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
	end)
	
	if success then
		return owns
	else
		warn("Failed to check VIP gamepass")
		return false
	end
end

-- Function to hide a wall
local function hideWall(wall)
	if wall and wall:IsA("BasePart") then
		wall.Transparency = 1
		
		-- Hide decals, textures, surface guis
		for _, child in ipairs(wall:GetDescendants()) do
			if child:IsA("Decal") or child:IsA("Texture") then
				child.Transparency = 1
			elseif child:IsA("SurfaceGui") then
				child.Enabled = false
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
				child.ImageTransparency = 1
				child.Visible = false
			elseif child:IsA("TextLabel") or child:IsA("TextButton") then
				child.TextTransparency = 1
				child.Visible = false
			end
		end
	end
end

-- Function to hide all VIP walls
local function hideAllVIPWalls()
	local vipWalls = Workspace:WaitForChild("VIPWalls", 10)
	if not vipWalls then 
		warn("VIPWalls folder not found")
		return 
	end
	
	-- Hide all existing walls
	for _, wall in ipairs(vipWalls:GetDescendants()) do
		if wall:IsA("BasePart") then
			hideWall(wall)
		end
	end
	
	-- Monitor for new walls being added
	vipWalls.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			hideWall(descendant)
		end
	end)
	
	print("VIP walls hidden for", player.Name)
end

-- Check VIP status and hide walls
if ownsVIP() then
	hideAllVIPWalls()
end
