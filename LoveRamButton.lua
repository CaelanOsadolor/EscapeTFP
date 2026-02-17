-- Love Ram Purchase Button
-- Place as SERVER Script inside the Love Ram model in Workspace

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local LOVE_RAM_PRODUCT_ID = 3526740159 -- 399 Robux (same as Gold Ram)

-- Get the model and prompt
local loveRamModel = script.Parent
local promptFolder = loveRamModel:FindFirstChild("Prompt")
local prompt = promptFolder and promptFolder:FindFirstChildOfClass("ProximityPrompt")

if not prompt then
	warn("[LoveRamButton] ProximityPrompt not found in model!")
	return
end

print("[LoveRamButton] Initialized for", loveRamModel.Name)

-- Sounds
local soundsFolder = ReplicatedStorage:WaitForChild("Sounds")
local buttonPressSound = soundsFolder:FindFirstChild("ButtonPress")
local playSoundEvent = ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("PlaySoundEvent")

-- Handle proximity prompt trigger
prompt.Triggered:Connect(function(player)
	print("[LoveRamButton] Prompt triggered by", player.Name)
	
	-- Play button sound for the player
	if playSoundEvent and buttonPressSound then
		playSoundEvent:FireClient(player, "ButtonPress", 0.2, nil, nil)
	end
	
	-- Prompt purchase
	MarketplaceService:PromptProductPurchase(player, LOVE_RAM_PRODUCT_ID)
end)
