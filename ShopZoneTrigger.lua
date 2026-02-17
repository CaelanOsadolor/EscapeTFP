-- Shop Zone Trigger Script
-- Place this script inside each PromptZone model (one in SPEED UPGRADES, one in CARRY UPGRADES)

local promptZone = script.Parent
local shopType = nil

-- Detect which shop this is by checking parent names
if promptZone.Parent.Name:lower():find("speed") then
	shopType = "SpeedShop"
elseif promptZone.Parent.Name:lower():find("carry") then
	shopType = "CarryShop"
else
	warn("Could not determine shop type from parent name:", promptZone.Parent.Name)
	return
end

print("Shop zone initialized for:", shopType)

-- Track players currently in zone
local playersInZone = {}
local CLOSE_DISTANCE = 10 -- Distance in studs before closing shop
local zonePart = promptZone:FindFirstChildWhichIsA("BasePart") -- Get reference to zone part for distance checks

-- Function to open shop for player
local function openShop(player)
	local playerGui = player:WaitForChild("PlayerGui")
	local shopFrame = playerGui:FindFirstChild(shopType)
	
	if shopFrame then
		shopFrame.Enabled = true
	end
end

-- Function to close shop for player
local function closeShop(player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end
	
	local shopFrame = playerGui:FindFirstChild(shopType)
	if shopFrame then
		shopFrame.Enabled = false
	end
end

-- Check if player is still near the zone
local function isPlayerNearZone(player)
	if not zonePart then return false end
	
	local character = player.Character
	if not character then return false end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end
	
	local distance = (humanoidRootPart.Position - zonePart.Position).Magnitude
	return distance <= CLOSE_DISTANCE
end

-- Monitor player distance continuously
local function monitorPlayerDistance(player)
	task.spawn(function()
		while playersInZone[player.UserId] do
			if not isPlayerNearZone(player) then
				playersInZone[player.UserId] = nil
				closeShop(player)
				break
			end
			task.wait(0.1) -- Check every 0.1 seconds
		end
	end)
end

-- Get all parts in the PromptZone to detect touches
local function setupTouchDetection()
	for _, part in pairs(promptZone:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Entered zone
			part.Touched:Connect(function(hit)
				local humanoid = hit.Parent:FindFirstChild("Humanoid")
				if humanoid then
					local player = game.Players:GetPlayerFromCharacter(hit.Parent)
					if player and not playersInZone[player.UserId] then
						playersInZone[player.UserId] = true
						openShop(player)
						monitorPlayerDistance(player)
					end
				end
			end)
		end
	end
end

-- Cleanup when player leaves game
game.Players.PlayerRemoving:Connect(function(player)
	playersInZone[player.UserId] = nil
end)

setupTouchDetection()
