-- Love Knight Purchase Button
-- Place as SERVER Script inside the Love Knight button model in Workspace

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local LOVE_KNIGHT_PRODUCT_ID = 3538163795 -- 399 Robux (Limited Rarity)

-- Get the model and prompt
local loveKnightModel = script.Parent
local promptFolder = loveKnightModel:FindFirstChild("Prompt")
local prompt = promptFolder and promptFolder:FindFirstChildOfClass("ProximityPrompt")

if not prompt then
	warn("[LoveKnightButton] ProximityPrompt not found in model!")
	return
end

print("[LoveKnightButton] Initialized for", loveKnightModel.Name)

-- Sounds
local soundsFolder = ReplicatedStorage:WaitForChild("Sounds")
local buttonPressSound = soundsFolder:FindFirstChild("ButtonPress")
local playSoundEvent = ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("PlaySoundEvent")

-- Handle proximity prompt trigger
prompt.Triggered:Connect(function(player)
	print("[LoveKnightButton] Prompt triggered by", player.Name)
	
	-- Play button sound for the player
	if playSoundEvent and buttonPressSound then
		playSoundEvent:FireClient(player, "ButtonPress", 0.2, nil, nil)
	end
	
	-- Prompt purchase
	MarketplaceService:PromptProductPurchase(player, LOVE_KNIGHT_PRODUCT_ID)
end)
