-- VIPWallScript.lua
-- Place this script inside each VIP wall part
-- The part should be in Workspace/VIPWalls folder

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local wall = script.Parent
local VIP_GAMEPASS_ID = 1669012678

-- Function to check if player owns VIP gamepass
local function ownsVIP(player)
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
	end)

	if success then
		return owns
	else
		warn("Failed to check VIP gamepass for", player.Name)
		return false
	end
end

-- Set up collision group for VIP players
local PhysicsService = game:GetService("PhysicsService")

-- Create collision groups if they don't exist
local success = pcall(function()
	if not PhysicsService:IsCollisionGroupRegistered("VIPPlayers") then
		PhysicsService:RegisterCollisionGroup("VIPPlayers")
	end
	if not PhysicsService:IsCollisionGroupRegistered("VIPWalls") then
		PhysicsService:RegisterCollisionGroup("VIPWalls")
	end
end)

-- Make VIP players not collide with VIP walls
pcall(function()
	PhysicsService:CollisionGroupSetCollidable("VIPPlayers", "VIPWalls", false)
end)

-- Set this wall to the VIPWalls collision group
wall.CollisionGroup = "VIPWalls"

-- Cooldown tracking to prevent prompt spam
local promptCooldowns = {}
local PROMPT_COOLDOWN = 3 -- 3 seconds between prompts

-- Handle wall touch to prompt purchase
wall.Touched:Connect(function(hit)
	local character = hit.Parent
	local player = Players:GetPlayerFromCharacter(character)
	
	if not player then return end
	
	-- Check if player already owns VIP
	if ownsVIP(player) then return end
	
	-- Check cooldown
	local currentTime = tick()
	if promptCooldowns[player.UserId] and (currentTime - promptCooldowns[player.UserId]) < PROMPT_COOLDOWN then
		return
	end
	
	-- Update cooldown
	promptCooldowns[player.UserId] = currentTime
	
	-- Prompt gamepass purchase
	local success, errorMessage = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, VIP_GAMEPASS_ID)
	end)
	
	if not success then
		warn("[VIPWall] Failed to prompt purchase for", player.Name, ":", errorMessage)
	end
end)

-- Function to setup player
local function setupPlayer(player)
	local hasVIP = ownsVIP(player)

	if hasVIP then
		-- Wait for character
		player.CharacterAdded:Connect(function(character)
			task.wait(0.5) -- Small delay to ensure character is fully loaded

			-- Set all character parts to VIPPlayers collision group
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CollisionGroup = "VIPPlayers"
				end
			end

			-- Monitor for new parts being added (accessories, etc.)
			character.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") then
					descendant.CollisionGroup = "VIPPlayers"
				end
			end)
		end)

		-- Setup current character if exists
		if player.Character then
			for _, part in ipairs(player.Character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CollisionGroup = "VIPPlayers"
				end
			end
		end
	end
end

-- Setup all current players
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		setupPlayer(player)
	end)
end

-- Setup new players
Players.PlayerAdded:Connect(setupPlayer)
