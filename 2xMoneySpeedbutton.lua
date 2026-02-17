-- 2xMoneySpeedbutton.client.lua
-- Place this LocalScript inside the 2x Money or 2x Speed ROBUX button
-- This button handles Robux purchases ONLY

local MarketplaceService = game:GetService("MarketplaceService")
local TS = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Script is inside BuyRobux folder/frame
local buyRobuxFolder = script.Parent

-- Find the actual clickable button (could be BuyRobux itself or inside it)
local button = buyRobuxFolder
if buyRobuxFolder:IsA("Folder") then
	-- If it's a folder, the clickable button is the parent frame
	button = buyRobuxFolder.Parent
end

-- If BuyRobux is a TextButton/ImageButton, use it directly
if not (button:IsA("TextButton") or button:IsA("ImageButton")) then
	-- Try to find a button inside the structure
	button = buyRobuxFolder:FindFirstChildWhichIsA("TextButton") 
		or buyRobuxFolder:FindFirstChildWhichIsA("ImageButton")
		or buyRobuxFolder.Parent:FindFirstChildWhichIsA("TextButton")
		or buyRobuxFolder.Parent:FindFirstChildWhichIsA("ImageButton")
end

if not button or not (button:IsA("TextButton") or button:IsA("ImageButton")) then
	warn("[2xBoostButton] Could not find a clickable TextButton or ImageButton!")
	return
end

-- CHANGE THESE to match your boost type:
-- Speed: PRODUCT_ID = 3534035402
-- Money: PRODUCT_ID = 3534035119
local PRODUCT_ID = 3534035402 -- Dev product for Robux purchase

-- Determine boost type
local BOOST_TYPE = "Speed"
local ATTRIBUTE_NAME = "Boost2xSpeedEndTime"

if PRODUCT_ID == 3534035119 then
	BOOST_TYPE = "Money"
	ATTRIBUTE_NAME = "Boost2xMoneyEndTime"
end

-- Find the RobuxPrice TextLabel (sibling of this script, inside BuyRobux)
local robuxPriceLabel = buyRobuxFolder:FindFirstChild("RobuxPrice")
if not robuxPriceLabel then
	warn("[2xBoostButton] Could not find RobuxPrice TextLabel!")
	return
end

-- Store the original text (whatever it's set to in Studio)
local ORIGINAL_PRICE_TEXT = robuxPriceLabel.Text

-- Track if button is on cooldown
local isOnCooldown = false

-- Button hover/click properties
local origBtnSize = button.Size
local hoverScl = 1.05
local clickScl = 0.9
local btnTInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

-- Sound effects
local hoverSound = Instance.new("Sound")
hoverSound.SoundId = "rbxassetid://10066931761"
hoverSound.Volume = 0.1
hoverSound.Parent = button

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6586979979"
clickSound.Volume = 0.2
clickSound.Parent = button

-- Button tween function
local function makeBtnTween(scl)
	local newSize = UDim2.new(
		origBtnSize.X.Scale * scl,
		origBtnSize.X.Offset * scl,
		origBtnSize.Y.Scale * scl,
		origBtnSize.Y.Offset * scl
	)
	return TS:Create(button, btnTInfo, {Size = newSize})
end

-- Button hover effects
button.MouseEnter:Connect(function()
	if not isOnCooldown then
		hoverSound:Play()
		makeBtnTween(hoverScl):Play()
	end
end)

button.MouseLeave:Connect(function()
	if not isOnCooldown then
		makeBtnTween(1):Play()
	end
end)

-- Function to format time remaining (MM:SS)
local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", minutes, secs)
end

-- Function to update button state based on cooldown
local function updateButtonState()
	local boostEndTime = player:GetAttribute(ATTRIBUTE_NAME)
	local currentTime = os.time()
	
	if boostEndTime and currentTime < boostEndTime then
		-- Boost is active - show countdown timer
		isOnCooldown = true
		local timeRemaining = boostEndTime - currentTime
		robuxPriceLabel.Text = formatTime(timeRemaining)
	else
		-- No active boost - show Robux price
		isOnCooldown = false
		robuxPriceLabel.Text = ORIGINAL_PRICE_TEXT
	end
end

-- Update button state every second (not every frame to reduce lag)
task.spawn(function()
	while true do
		updateButtonState()
		task.wait(1) -- Update every second
	end
end)

-- Also update when attribute changes
player:GetAttributeChangedSignal(ATTRIBUTE_NAME):Connect(function()
	updateButtonState()
end)

-- Initial update
updateButtonState()

-- Button click effect + Robux product prompt
button.MouseButton1Click:Connect(function()
	if isOnCooldown then
		-- Don't allow purchase during boost cooldown
		return
	end
	
	clickSound:Play()
	local shrinkTween = makeBtnTween(clickScl)
	local resetTween = makeBtnTween(1)

	shrinkTween:Play()
	shrinkTween.Completed:Connect(function()
		resetTween:Play()
		-- Show Robux purchase prompt
		MarketplaceService:PromptProductPurchase(player, PRODUCT_ID)
	end)
end)

print("[2xBoostButton] Initialized for", BOOST_TYPE, "boost (Robux only)")
