-- GodspeedButton.lua
-- LocalScript to handle Godspeed Tsunami spawning button
-- Place in: SpawnGodspeed Frame

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local frame = script.Parent -- The SpawnGodspeed Frame
local button = frame:WaitForChild("ImageButton")
local icon = frame:WaitForChild("Icon")
local radial = frame:WaitForChild("Radial")

-- Product ID for Godspeed Tsunami spawn
local GODSPEED_PRODUCT_ID = 3515370630

-- Cooldown tracking
local lastPurchaseTime = 0
local COOLDOWN = 3 -- 3 second cooldown to prevent spam

-- Rotation animation for Radial only
local rotateInfo = TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false) -- -1 = infinite, no reverse

local radialRotate = TweenService:Create(radial, rotateInfo, {
	Rotation = 360
})

radialRotate:Play()

-- Button click handler
button.MouseButton1Click:Connect(function()
	-- Play button press sound
	local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")
	if soundsFolder then
		local buttonSound = soundsFolder:FindFirstChild("ButtonPress")
		if buttonSound then
			local sound = buttonSound:Clone()
			sound.Volume = buttonSound.Volume * 0.2
			sound.Parent = workspace.CurrentCamera
			sound:Play()
			sound.Ended:Connect(function()
				sound:Destroy()
			end)
		end
	end

	-- Check cooldown
	local currentTime = tick()
	if currentTime - lastPurchaseTime < COOLDOWN then
		warn("[GodspeedButton] Cooldown active, wait", math.ceil(COOLDOWN - (currentTime - lastPurchaseTime)), "seconds")
		return
	end

	-- Prompt purchase
	local success, errorMessage = pcall(function()
		MarketplaceService:PromptProductPurchase(player, GODSPEED_PRODUCT_ID)
	end)

	if not success then
		warn("[GodspeedButton] Failed to prompt purchase:", errorMessage)
	end

	lastPurchaseTime = currentTime
end)

print("[GodspeedButton] Loaded!")
