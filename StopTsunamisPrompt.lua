-- StopTsunamisPrompt.lua
-- Server script to prompt Stop Tsunamis purchase when player touches/approaches
-- Place this script inside the StopTsunamis model in Workspace

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

-- Product ID for Stop Tsunamis
local STOP_TSUNAMIS_PRODUCT_ID = 3533863230

-- Cooldown to prevent spam
local COOLDOWN = 3 -- 3 seconds
local playerCooldowns = {}

-- Get the model this script is in
local model = script.Parent

-- Function to prompt purchase
local function promptPurchase(player)
	-- Check cooldown
	local currentTime = tick()
	if playerCooldowns[player.UserId] and (currentTime - playerCooldowns[player.UserId]) < COOLDOWN then
		return
	end
	
	-- Update cooldown
	playerCooldowns[player.UserId] = currentTime
	
	-- Prompt purchase
	local success, errorMessage = pcall(function()
		MarketplaceService:PromptProductPurchase(player, STOP_TSUNAMIS_PRODUCT_ID)
	end)
	
	if not success then
		warn("[StopTsunamisPrompt] Failed to prompt purchase for", player.Name, ":", errorMessage)
	else
		print("[StopTsunamisPrompt] Prompted", player.Name, "to purchase Stop Tsunamis")
	end
end

-- Set up touch detection on all parts in the model
for _, part in pairs(model:GetDescendants()) do
	if part:IsA("BasePart") then
		part.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = Players:GetPlayerFromCharacter(character)
			
			if player then
				promptPurchase(player)
			end
		end)
	end
end

-- Also add a ProximityPrompt for better UX (optional)
local primaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
if primaryPart then
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.ActionText = "Stop Tsunamis"
	proximityPrompt.ObjectText = "30 Seconds"
	proximityPrompt.HoldDuration = 0
	proximityPrompt.MaxActivationDistance = 10
	proximityPrompt.RequiresLineOfSight = false
	proximityPrompt.Parent = primaryPart
	
	proximityPrompt.Triggered:Connect(function(player)
		promptPurchase(player)
	end)
end

print("[StopTsunamisPrompt] Loaded for model:", model.Name)
