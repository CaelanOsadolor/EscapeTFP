-- GroupRewardButton.lua (LocalScript)
-- Place in: StarterGui > GroupReward > Claim (inside the button)
-- Handles group reward claim button

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local button = script.Parent -- The Claim button
local groupRewardGui = button.Parent -- The GroupReward folder
local textLabel = button:WaitForChild("TextLabel") -- Timer text

-- Configuration
local GROUP_ID = 5254090 -- Your group ID

-- Get RemoteEvent
local remoteEvent = ReplicatedStorage:WaitForChild("GroupRewardClaim")

-- Timer state
local timeRemaining = 0
local originalButtonText = textLabel.Text
local isOnCooldown = false

-- Format time as MM:SS
local function FormatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", minutes, secs)
end

-- Update button display
local function UpdateButtonDisplay()
	if timeRemaining > 0 then
		isOnCooldown = true
		textLabel.Text = FormatTime(timeRemaining)
		button.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Gray out
	else
		isOnCooldown = false
		textLabel.Text = originalButtonText
		button.BackgroundColor3 = Color3.fromRGB(0, 170, 255) -- Original color (adjust as needed)
	end
end

-- Start countdown timer
task.spawn(function()
	while true do
		task.wait(1)
		if timeRemaining > 0 then
			timeRemaining = timeRemaining - 1
			UpdateButtonDisplay()
		end
	end
end)

-- Request initial timer state (with retries)
task.spawn(function()
	for i = 1, 5 do
		task.wait(0.5)
		remoteEvent:FireServer("CheckTimer")
		
		-- Wait to see if we get a response
		task.wait(0.5)
		if isOnCooldown or timeRemaining > 0 then
			break -- Got valid timer state
		end
	end
end)

-- Button click handler
button.MouseButton1Click:Connect(function()
	-- Pop animation
	local originalSize = button.Size
	local popTween = TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(originalSize.X.Scale * 0.9, originalSize.X.Offset * 0.9, originalSize.Y.Scale * 0.9, originalSize.Y.Offset * 0.9)
	})
	local popBackTween = TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = originalSize
	})
	
	popTween:Play()
	popTween.Completed:Connect(function()
		popBackTween:Play()
	end)
	
	-- Check if on cooldown
	if isOnCooldown then
		return -- Don't do anything if on cooldown
	end
	
	-- Play button press sound
	local soundTemplate = ReplicatedStorage:FindFirstChild("Sounds")
	if soundTemplate then
		local buttonSound = soundTemplate:FindFirstChild("ButtonPress")
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
	
	-- Prompt player to join group and get result
	local success, result = pcall(function()
		return GroupService:PromptJoinAsync(GROUP_ID)
	end)
	
	-- Check if they joined or are already a member
	if success and (result == Enum.GroupMembershipStatus.Joined or result == Enum.GroupMembershipStatus.AlreadyMember) then
		remoteEvent:FireServer()
	end
end)

-- Listen for timer updates from server
remoteEvent.OnClientEvent:Connect(function(action, seconds)
	if action == "UpdateTimer" then
		timeRemaining = seconds or 0
		UpdateButtonDisplay()
	end
end)
