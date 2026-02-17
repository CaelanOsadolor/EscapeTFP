-- WheelUI.lua
-- Client-side script for wheel UI and spinning animation
-- Place this LocalScript INSIDE the SpinWheel GUI (as a child of SpinWheel)

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Wait for remote events
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local spinWheelEvent = remoteEventsFolder:WaitForChild("SpinWheel")
local updateWheelUI = remoteEventsFolder:WaitForChild("UpdateWheelUI")

-- Sound system
local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")

-- Get GUI (parent of this script)
local SpinWheel = script.Parent
local SpinWheelFrame = SpinWheel:WaitForChild("SpinWheelFrame")
local Content = SpinWheelFrame:WaitForChild("Content")
local Wheel = Content:WaitForChild("Wheel")
local Arrow = Content:FindFirstChild("Arrow") or Content:FindFirstChild("Pointer") -- Arrow/pointer element
local Background = SpinWheel:FindFirstChild("Background") -- Background is sibling of SpinWheelFrame

-- Ensure GUI is hidden by default (will be shown by server when touching PromptPart)
SpinWheelFrame.Visible = false
if Background then
	Background.Visible = false
end

-- Fast spin mode value (created by SkipSpinButton script)
local fastSpinEnabled = SpinWheel:FindFirstChild("FastSpinEnabled")
if not fastSpinEnabled then
	fastSpinEnabled = Instance.new("BoolValue")
	fastSpinEnabled.Name = "FastSpinEnabled"
	fastSpinEnabled.Value = false
	fastSpinEnabled.Parent = SpinWheel
end

-- Get wheel structure
local Rewards = Wheel:FindFirstChild("Rewards")
local Middle = Wheel:FindFirstChild("Middle")
local rewardFrames = {}

if Rewards then
	for _, child in pairs(Rewards:GetChildren()) do
		if child:IsA("Frame") or child:IsA("ImageLabel") then
			table.insert(rewardFrames, child)
		end
	end
end

-- GUI elements
local Buttons = SpinWheelFrame:FindFirstChild("Buttons")

-- Find spin button (it's nested: Buttons > Spin (Frame) > Button)
local spinButton = nil
local spinButtonLabel = nil
if Buttons then
	local spinFrame = Buttons:FindFirstChild("Spin")
	if spinFrame then
		-- Try to find the actual button inside
		spinButton = spinFrame:FindFirstChildWhichIsA("TextButton") 
			or spinFrame:FindFirstChildWhichIsA("ImageButton")
			or spinFrame:FindFirstChild("Button")
		
		-- Find the label inside the button
		if spinButton then
			spinButtonLabel = spinButton:FindFirstChild("Label") or spinButton:FindFirstChildWhichIsA("TextLabel")
		end
	end
end

local spinsLabel = SpinWheelFrame:FindFirstChild("SpinsLabel")
local timerLabel = SpinWheelFrame:FindFirstChild("TimerLabel")
local resultLabel = SpinWheelFrame:FindFirstChild("ResultLabel")
local xButton = SpinWheelFrame:FindFirstChild("X") -- Close button

-- Debug: Print what we found
print("Spin button found:", spinButton)
if spinButton then
	print("Spin button type:", spinButton.ClassName)
	print("Spin button label found:", spinButtonLabel)
end

-- State
local isSpinning = false
local currentSpins = 0
local playtimeRemaining = 0

-- Format time as MM:SS
local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", minutes, secs)
end

-- Update UI display
local function updateDisplay()
	if spinsLabel then
		spinsLabel.Text = "Spins: " .. currentSpins
	end
	
	if timerLabel then
		if playtimeRemaining > 0 then
			timerLabel.Text = "Next Free Spin: " .. formatTime(playtimeRemaining)
			timerLabel.Visible = true
		else
			timerLabel.Visible = false
		end
	end
	
	-- Update spin button text and state
	if spinButton then
		-- Update button text (use label if it's an ImageButton)
		local textElement = spinButtonLabel or spinButton
		
		if currentSpins > 0 then
			-- Show spin count
			if textElement.ClassName == "TextLabel" or textElement.ClassName == "TextButton" then
				textElement.Text = "Spin (" .. currentSpins .. "x)"
			end
			spinButton.Interactable = not isSpinning
		else
			-- Show timer countdown
			if textElement.ClassName == "TextLabel" or textElement.ClassName == "TextButton" then
				if playtimeRemaining > 0 then
					textElement.Text = formatTime(playtimeRemaining)
				else
					textElement.Text = "Spin"
				end
			end
			spinButton.Interactable = false
		end
	end
end

-- Spin animation with smooth rotation and counter-rotation
local function animateWheelSpin(reward)
	isSpinning = true
	if resultLabel then
		resultLabel.Visible = false
	end
	
	-- Calculate rotation based on reward position
	-- Rewards are arranged clockwise based on the actual GUI labels: 1=top, 2, 3, 4, 5, 6
	-- Arrow points UP (0 degrees)
	-- Positions verified from wheel GUI layout
	local rewardPositions = {
		["Valentine 17 Pro Max"] = 1,  -- Top position (0°) - labeled "1" (ultra rare Limited)
		["100M Cash"] = 2,      -- 60° clockwise - labeled "2"
		["2x Speed"] = 3,       -- 120° clockwise - labeled "3" (10 Minutes 15%)
		["1M Cash"] = 4,        -- 180° (bottom) - labeled "4"
		["Random Celestial"] = 5,      -- 240° clockwise - labeled "5"
		["2x Money"] = 6,       -- 300° clockwise - labeled "6" (10 Minutes 25%)
	}
	
	local position = rewardPositions[reward.Name]
	if not position then
		warn("Unknown reward name:", reward.Name, "- defaulting to position 1")
		position = 1
	end
	
	local degreesPerSection = 360 / 6  -- 60 degrees per section
	
	-- Get starting rotation BEFORE calculating target
	local startRotation = Wheel.Rotation
	
	-- Calculate exact target rotation to land arrow on reward
	-- We want the reward to be at 0° (top where arrow points)
	local baseTargetRotation = -(position - 1) * degreesPerSection
	
	-- Check if fast spin is enabled
	local isFastSpin = fastSpinEnabled.Value
	
	-- Add extra spins for effect
	local extraSpins = isFastSpin and math.random(2, 3) or math.random(5, 7)
	
	-- Calculate total rotation - we want to end at the exact target position
	-- Add full rotations, then adjust to reach the target from current position
	local totalRotation = (360 * extraSpins) + baseTargetRotation - (startRotation % 360)
	
	-- Animation parameters - faster initially
	local duration = isFastSpin and 1.5 or 4 -- Fast: 1.5s, Normal: 4s
	local startTime = tick()
	
	-- Play initial tick sound when spin starts
	if soundsFolder then
		local tickSound = soundsFolder:FindFirstChild("Tick")
		if tickSound then
			tickSound:Play()
		end
	end
	
	-- Track which section we're in for tick sounds
	-- Initialize to current section so any movement triggers a tick
	local lastSection = 0
	
	-- Arrow wobble effect parameters
	local arrowOriginalRotation = Arrow and Arrow.Rotation or 0
	local wobbleAmount = 15 -- degrees of wobble
	local wobbleSpeed = 20 -- wobbles per second at peak speed
	
	-- Animate with RenderStepped for smooth rotation
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local progress = math.min(elapsed / duration, 1)
		
		-- Easing function - starts fast, slows down at end (ease out cubic for smooth deceleration)
		local eased = 1 - math.pow(1 - progress, 3)
		
		-- Calculate current rotation
		local currentRotation = startRotation + (totalRotation * eased)
		
		-- Apply rotation to wheel
		Wheel.Rotation = currentRotation
		
		-- Counter-rotate rewards and middle to keep them upright
		for _, rewardFrame in pairs(rewardFrames) do
			rewardFrame.Rotation = -currentRotation
		end
		
		if Middle then
			Middle.Rotation = -currentRotation
		end
		
		-- Animate arrow wobble - wobbles more at high speed, less as it slows
		if Arrow then
			local wobbleIntensity = 1 - eased -- More wobble at start, less at end
			local wobblePhase = elapsed * wobbleSpeed * wobbleIntensity
			local wobbleOffset = math.sin(wobblePhase * math.pi * 2) * wobbleAmount * wobbleIntensity
			Arrow.Rotation = arrowOriginalRotation + wobbleOffset
		end
		
		-- Play tick sound when passing each section (every 60 degrees)
		-- Use relative rotation to track section changes accurately
		local totalRotated = math.abs(currentRotation - startRotation)
		local currentSection = math.floor(totalRotated / degreesPerSection)
		if currentSection > lastSection then
			lastSection = currentSection
			if soundsFolder then
				local tickSound = soundsFolder:FindFirstChild("Tick")
				if tickSound then
					tickSound:Play()
				end
			end
		end
		
		-- Stop when animation is complete
		if progress >= 1 then
			connection:Disconnect()
			
			-- Set final rotation (keep accumulating, don't reset to 0)
			local finalRotation = startRotation + totalRotation
			Wheel.Rotation = finalRotation
			for _, rewardFrame in pairs(rewardFrames) do
				rewardFrame.Rotation = -finalRotation
			end
			if Middle then
				Middle.Rotation = -finalRotation
			end
			
			-- Reset arrow wobble
			if Arrow then
				Arrow.Rotation = arrowOriginalRotation
			end
			
			print("Landed on reward:", reward.Name, "at rotation:", finalRotation, "(normalized:", finalRotation % 360, "target was:", baseTargetRotation, ")")
			
			-- Play claim sound when landing on reward
			if soundsFolder then
				local claimSound = soundsFolder:FindFirstChild("ClaimSound")
				if claimSound then
					claimSound:Play()
				end
			end
			
			-- Show result
			if resultLabel then
				resultLabel.Text = "You won: " .. reward.Name .. "!"
				resultLabel.Visible = true
			end
			
			task.wait(2) -- Show result for 2 seconds
			
			if resultLabel then
				resultLabel.Visible = false
			end
			
			isSpinning = false
			updateDisplay()
		end
	end)
end

-- Spin button clicked
if spinButton and (spinButton:IsA("TextButton") or spinButton:IsA("ImageButton")) then
	spinButton.MouseButton1Click:Connect(function()
		if isSpinning or currentSpins <= 0 then
			return
		end
		
		-- Play button sound
		if soundsFolder then
			local buttonSound = soundsFolder:FindFirstChild("ButtonPress")
			if buttonSound then
				buttonSound:Play()
			end
		end
		
		-- Request spin from server
		spinWheelEvent:FireServer()
	end)
	print("Spin button connected successfully")
else
	warn("Spin button not found or not a valid button type!")
end

-- X button to close GUI
if xButton and xButton:IsA("GuiButton") then
	xButton.MouseButton1Click:Connect(function()
		-- Play click sound
		if soundsFolder then
			local clickSound = soundsFolder:FindFirstChild("Click")
			if clickSound then
				clickSound:Play()
			end
		end
		
		SpinWheelFrame.Visible = false
		if Background then
			Background.Visible = false
		end
	end)
elseif xButton then
	-- Try to find button inside X
	local xButtonInside = xButton:FindFirstChildWhichIsA("TextButton") or xButton:FindFirstChildWhichIsA("ImageButton")
	if xButtonInside then
		xButtonInside.MouseButton1Click:Connect(function()
			-- Play click sound
			if soundsFolder then
				local clickSound = soundsFolder:FindFirstChild("Click")
				if clickSound then
					clickSound:Play()
				end
			end
			
			SpinWheelFrame.Visible = false
			if Background then
				Background.Visible = false
			end
		end)
	end
end

-- Update from server
local lastSpinsCount = nil -- Start as nil to detect first load

updateWheelUI.OnClientEvent:Connect(function(data)
	if data.Spins then
		-- Check if spins increased (purchase or free spin earned)
		-- Only play sound if we've received at least one update before (not the first load)
		if lastSpinsCount and data.Spins > lastSpinsCount then
			-- Play purchase success sound
			if soundsFolder then
				local purchaseSound = soundsFolder:FindFirstChild("PurchaseSuccess")
				if purchaseSound then
					purchaseSound:Play()
				end
			end
		end
		lastSpinsCount = data.Spins
		currentSpins = data.Spins
	end
	
	if data.PlaytimeRemaining then
		playtimeRemaining = data.PlaytimeRemaining
	end
	
	if data.Reward then
		-- Animate wheel spin with reward
		animateWheelSpin(data.Reward)
	end
	
	if data.Error then
		-- Show error message
		if resultLabel then
			resultLabel.Text = data.Error
			resultLabel.Visible = true
			task.wait(2)
			resultLabel.Visible = false
		end
	end
	
	updateDisplay()
end)

-- Initial display
updateDisplay()

-- Request update when GUI becomes visible
SpinWheelFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if SpinWheelFrame.Visible then
		-- Request fresh data from server when GUI opens
		spinWheelEvent:FireServer("RequestUpdate")
	end
end)

-- Timer update loop - updates every second
task.spawn(function()
	while true do
		task.wait(1)
		-- Update timer countdown locally while GUI is visible
		if SpinWheelFrame.Visible and playtimeRemaining > 0 and currentSpins == 0 and not isSpinning then
			playtimeRemaining = math.max(0, playtimeRemaining - 1)
			updateDisplay()
		end
	end
end)

-- ========================================
-- IDLE ANIMATION - Makes wheel spin slowly when not spinning
-- ========================================
local ROTATION_SPEED = 10 -- Degrees per second
local lastFrameTime = tick()

RunService.RenderStepped:Connect(function()
	-- Only animate when not actively spinning
	if not isSpinning then
		local currentTime = tick()
		local deltaTime = currentTime - lastFrameTime
		lastFrameTime = currentTime
		
		-- Update rotation (continue from current position, don't reset)
		local currentRotation = Wheel.Rotation + (ROTATION_SPEED * deltaTime)
		
		-- Rotate wheel
		Wheel.Rotation = currentRotation
		
		-- Counter-rotate rewards and middle to keep them upright
		for _, rewardFrame in pairs(rewardFrames) do
			rewardFrame.Rotation = -currentRotation
		end
		
		if Middle then
			Middle.Rotation = -currentRotation
		end
	else
		-- Reset timer when spinning to keep smooth when animation ends
		lastFrameTime = tick()
	end
end)

print("WheelUI loaded with idle animation")
