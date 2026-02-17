-- Valentine Pro Max Purchase Button
-- Place as SERVER Script inside the Valentine Pro Max model in Workspace

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local VALENTINE_PROMAX_PRODUCT_ID = 3526936916 -- 399 Robux

-- Get the model and prompt
local valentineModel = script.Parent
local promptFolder = valentineModel:FindFirstChild("Prompt")
local prompt = promptFolder and promptFolder:FindFirstChildOfClass("ProximityPrompt")

if not prompt then
	warn("[ValentineProMaxButton] ProximityPrompt not found in model!")
	return
end

print("[ValentineProMaxButton] Initialized for", valentineModel.Name)

-- Sounds
local soundsFolder = ReplicatedStorage:WaitForChild("Sounds")
local buttonPressSound = soundsFolder:FindFirstChild("ButtonPress")
local playSoundEvent = ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("PlaySoundEvent")

-- Handle proximity prompt trigger
prompt.Triggered:Connect(function(player)
	print("[ValentineProMaxButton] Prompt triggered by", player.Name)
	
	-- Play button sound for the player
	if playSoundEvent and buttonPressSound then
		playSoundEvent:FireClient(player, "ButtonPress", 0.2, nil, nil)
	end
	
	-- Prompt purchase
	MarketplaceService:PromptProductPurchase(player, VALENTINE_PROMAX_PRODUCT_ID)
end)
