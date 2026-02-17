-- WatchAdButtonMoney.client.lua
-- Place this LocalScript inside the "Watch Ad" button for 2x MONEY boost
-- This button shows rewarded video ads (FREE)

local AdService = game:GetService("AdService")
local TS = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- Find the button
local button = script.Parent
if not (button:IsA("TextButton") or button:IsA("ImageButton")) then
	-- Try to find a button in the parent structure
	button = button:FindFirstChildWhichIsA("TextButton") 
		or button:FindFirstChildWhichIsA("ImageButton")
		or button.Parent:FindFirstChildWhichIsA("TextButton")
		or button.Parent:FindFirstChildWhichIsA("ImageButton")
end

if not button or not (button:IsA("TextButton") or button:IsA("ImageButton")) then
	warn("[WatchAdButtonMoney] Could not find a clickable TextButton or ImageButton!")
	return
end

-- MONEY BOOST SETTINGS
local PRODUCT_ID = 3534035119 -- 2x Money dev product
local BOOST_TYPE = "Money"
local ATTRIBUTE_NAME = "Boost2xMoneyEndTime"

-- Get RemoteEvent for ad requests
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local showAdFunction = remoteEventsFolder:WaitForChild("ShowAdFunction")

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

-- Track button state
local isOnCooldown = false
local isAdAvailable = false

-- Check ad availability
local function checkAdAvailability()
	local success, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)

	if success and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable then
		isAdAvailable = true
		print("[WatchAdButtonMoney] ✅ Money ads available")
	else
		isAdAvailable = false
		print("[WatchAdButtonMoney] ❌ Money ads not available:", result and result.AdAvailabilityResult or "Failed to check")
	end
end

-- Initial ad check
checkAdAvailability()

-- Check ad availability every 30 seconds
task.spawn(function()
	while true do
		task.wait(30)
		checkAdAvailability()
	end
end)

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

-- Function to update button state
local function updateButtonState()
	local boostEndTime = player:GetAttribute(ATTRIBUTE_NAME)
	local currentTime = os.time()

	-- Check if boost is active
	if boostEndTime and currentTime < boostEndTime then
		isOnCooldown = true
		button.Visible = false -- Hide: boost already active
	else
		isOnCooldown = false

		-- Only show button if ad is available
		if isAdAvailable then
			button.Visible = true -- Show: ad available and no active boost
		else
			button.Visible = false -- Hide: no ads available right now
		end
	end
end

-- Update button state every second
task.spawn(function()
	while true do
		updateButtonState()
		task.wait(1)
	end
end)

-- Update when attribute changes
player:GetAttributeChangedSignal(ATTRIBUTE_NAME):Connect(function()
	updateButtonState()
end)

-- Initial update
updateButtonState()

-- Button hover effects
button.MouseEnter:Connect(function()
	if not isOnCooldown and isAdAvailable then
		hoverSound:Play()
		makeBtnTween(hoverScl):Play()
	end
end)

button.MouseLeave:Connect(function()
	if not isOnCooldown and isAdAvailable then
		makeBtnTween(1):Play()
	end
end)

-- Button click - request server to show ad
button.MouseButton1Click:Connect(function()
	if isOnCooldown or not isAdAvailable then
		return
	end

	clickSound:Play()
	local shrinkTween = makeBtnTween(clickScl)
	local resetTween = makeBtnTween(1)

	shrinkTween:Play()
	shrinkTween.Completed:Connect(function()
		resetTween:Play()

		-- Request server to show ad
		print("[WatchAdButtonMoney] Requesting server to show ad for", BOOST_TYPE)

		local success, result = pcall(function()
			return showAdFunction:InvokeServer(BOOST_TYPE, PRODUCT_ID)
		end)

		if success then
			print("[WatchAdButtonMoney] Server response:", result)

			-- Check if ad is already playing
			if result and tostring(result):find("already playing") then
				if starterGui then
					starterGui:SetCore("SendNotification", {
						Title = "Please Wait",
						Text = "Another ad is playing. Try again in a moment.",
						Duration = 3
					})
				end
			end

			-- Refresh ad availability after showing
			task.wait(2)
			checkAdAvailability()
			updateButtonState()
		else
			warn("[WatchAdButtonMoney] Failed to invoke server:", result)
			if starterGui then
				starterGui:SetCore("SendNotification", {
					Title = "Ad Error",
					Text = "Failed to show ad. Try again later.",
					Duration = 3
				})
			end
		end
	end)
end)

print("[WatchAdButtonMoney] Initialized for Money boost")
print("[WatchAdButtonMoney] Button visibility: Shows only when ads available AND no active boost")
