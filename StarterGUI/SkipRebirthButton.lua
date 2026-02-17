-- SkipRebirthButton.lua
-- LocalScript to handle Skip Rebirth purchase
-- Place in: Skip Frame

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local frame = script.Parent -- The Skip Frame
local button = frame:FindFirstChildWhichIsA("TextButton") or frame:FindFirstChildWhichIsA("ImageButton")

if not button then
	warn("[SkipRebirthButton] No button found in Skip frame")
	return
end

-- Product ID for Skip Rebirth
local SKIP_REBIRTH_PRODUCT_ID = 3533850199

-- Configuration
local MAX_REBIRTHS = 10
local COOLDOWN = 3 -- 3 second cooldown to prevent spam

-- Cooldown tracking
local lastPurchaseTime = 0

-- Update button display based on rebirth status
local function UpdateButtonDisplay()
	local currentRebirths = player:GetAttribute("Rebirths") or 0

	if currentRebirths >= MAX_REBIRTHS then
		-- At max rebirths - disable button
		button.Visible = false
	else
		button.Visible = true
	end
end

-- Initial update
UpdateButtonDisplay()

-- Listen for rebirth changes
player:GetAttributeChangedSignal("Rebirths"):Connect(UpdateButtonDisplay)

-- Button click handler
button.MouseButton1Click:Connect(function()
	-- Play button press sound
	local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")
	if soundsFolder then
		local buttonSound = soundsFolder:FindFirstChild("ButtonPress")
		if buttonSound then
			buttonSound:Play()
		end
	end

	-- Check cooldown
	local currentTime = tick()
	if currentTime - lastPurchaseTime < COOLDOWN then
		warn("[SkipRebirthButton] Cooldown active, wait", math.ceil(COOLDOWN - (currentTime - lastPurchaseTime)), "seconds")
		return
	end

	-- Check if already at max rebirths
	local currentRebirths = player:GetAttribute("Rebirths") or 0
	if currentRebirths >= MAX_REBIRTHS then
		warn("[SkipRebirthButton] Already at max rebirths")
		return
	end

	-- Prompt purchase
	local success, errorMessage = pcall(function()
		MarketplaceService:PromptProductPurchase(player, SKIP_REBIRTH_PRODUCT_ID)
	end)

	if not success then
		warn("[SkipRebirthButton] Failed to prompt purchase:", errorMessage)
	end

	lastPurchaseTime = currentTime
end)

print("[SkipRebirthButton] Loaded!")
