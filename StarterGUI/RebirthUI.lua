-- Rebirth UI Handler
-- Place as LocalScript inside RebirthFrame

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Get RebirthFrame (this script is inside it)
local rebirthFrame = script.Parent

-- Get UI elements
local currentRebirth = rebirthFrame:WaitForChild("CurrentRebirth")
local currentRebirthText = currentRebirth:WaitForChild("Rebirth")
local currentMultiplierFrame = currentRebirth:WaitForChild("Multiplier")
-- Find TextLabel inside Multiplier frame
local currentMultiplierText = currentMultiplierFrame:FindFirstChildOfClass("TextLabel")

local nextRebirth = rebirthFrame:WaitForChild("NextRebirth")
local nextRebirthText = nextRebirth:WaitForChild("Rebirth")
local nextMultiplierFrame = nextRebirth:WaitForChild("Multiplier")
-- Find TextLabel inside Multiplier frame
local nextMultiplierText = nextMultiplierFrame:FindFirstChildOfClass("TextLabel")

local progressBar = rebirthFrame:WaitForChild("ProgressBar")
local innerBar = progressBar:WaitForChild("InnerBar")
local speedText = progressBar:WaitForChild("Speed")

local rebirthButtonFrame = rebirthFrame:WaitForChild("Rebirth")
local textButton = rebirthButtonFrame:WaitForChild("TextButton")

-- Get RemoteEvents
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local rebirthEvent = remoteEventsFolder:WaitForChild("RebirthEvent")
local rebirthInfoFunction = remoteEventsFolder:WaitForChild("RebirthInfoFunction")

-- Get Sounds
local soundsFolder = ReplicatedStorage:WaitForChild("Sounds")
local buttonPressSound = soundsFolder:WaitForChild("ButtonPress")
local rebirthSound = soundsFolder:WaitForChild("RebirthSound")
local errorSound = soundsFolder:WaitForChild("Error")

-- Track current rebirth eligibility
local canCurrentlyRebirth = false

-- Update UI with current rebirth info
local function updateRebirthUI()
	-- Get info from server
	local success, info = pcall(function()
		return rebirthInfoFunction:InvokeServer()
	end)
	
	if not success or not info then 
		warn("Failed to get rebirth info:", info)
		return 
	end
	
	local currentRebirths = info.CurrentRebirths or 0
	local currentSpeed = info.CurrentSpeed or 18
	local requiredSpeed = info.RequiredSpeed or 50
	local nextMultiplier = info.NextMultiplier or 1.5
	local canRebirth = info.CanRebirth or false
	
	-- Check if at max rebirths
	local isMaxRebirth = currentRebirths >= 10
	
	-- Update current rebirth display
	currentRebirthText.Text = "Rebirth " .. currentRebirths
	local currentMultiplier = 1 + (currentRebirths * 0.5)
	currentMultiplierText.Text = currentMultiplier .. "x Money"
	
	-- Update next rebirth display
	if isMaxRebirth then
		-- Hide or show MAX when at max rebirths
		nextRebirthText.Text = "MAX"
		nextMultiplierText.Text = currentMultiplier .. "x Money"
		speedText.Text = "MAX REBIRTH REACHED!"
		innerBar.Size = UDim2.new(1, 0, 1, 0) -- Full bar
		textButton.Text = ""
		textButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Gold color for max
		textButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		nextRebirthText.Text = "Rebirth " .. (currentRebirths + 1)
		nextMultiplierText.Text = nextMultiplier .. "x Money"
		
		-- Update progress bar with tween animation
		local progress = math.min(currentSpeed / requiredSpeed, 1)
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(innerBar, tweenInfo, {Size = UDim2.new(progress, 0, 1, 0)})
		tween:Play()
		
		-- Update speed text
		speedText.Text = "Speed " .. math.floor(currentSpeed) .. "/" .. requiredSpeed
		
		-- Update button state
		textButton.Text = "Rebirth"
		if canRebirth then
			textButton.BackgroundColor3 = Color3.fromRGB(170, 85, 255) -- Purple when available
			textButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			textButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Gray when locked
			textButton.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
	end
	
	-- Update button state
	canCurrentlyRebirth = canRebirth and not isMaxRebirth
end

-- Helper function to play sound
local function playSound(sound)
	if sound then
		local soundClone = sound:Clone()
		soundClone.Parent = game:GetService("SoundService")
		soundClone:Play()
		soundClone.Ended:Connect(function()
			soundClone:Destroy()
		end)
	end
end

-- Handle rebirth button click
textButton.MouseButton1Click:Connect(function()
	-- Play button press sound
	playSound(buttonPressSound)
	
	-- Check if player can rebirth
	if not canCurrentlyRebirth then
		-- Play error sound if can't rebirth
		playSound(errorSound)
		return
	end
	
	-- Play rebirth success sound
	playSound(rebirthSound)
	
	-- Fire rebirth event to server
	rebirthEvent:FireServer()
	
	-- Update UI after a short delay
	wait(0.5)
	updateRebirthUI()
end)

-- Update UI when attributes change
player:GetAttributeChangedSignal("Speed"):Connect(updateRebirthUI)
player:GetAttributeChangedSignal("Rebirths"):Connect(updateRebirthUI)

-- Initial update
updateRebirthUI()

-- Update every 2 seconds
while true do
	wait(2)
	updateRebirthUI()
end

print("Rebirth UI initialized!")
