-- Services
local tweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Player
local player = Players.LocalPlayer

-- Wait for RemoteEvent
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local slowWalkToggleEvent = remoteEventsFolder:WaitForChild("SlowWalkToggleEvent")

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local bottomLeft = playerGui:WaitForChild("BottomLeft")
local frame = bottomLeft:WaitForChild("Frame")
local buttonFrame = frame:WaitForChild("OnOffButtonFrame")
local onPos = buttonFrame:WaitForChild("OnPos")
local offPos = buttonFrame:WaitForChild("OffPos")
local movingPart = buttonFrame:WaitForChild("MovingPart")
local greenFrame = buttonFrame:WaitForChild("GreenFrame")
local redFrame = buttonFrame:WaitForChild("RedFrame")
local OnValue = buttonFrame:WaitForChild("OnOffVal")
local button = buttonFrame:WaitForChild("InteractButton")

-- Create click sound
local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://9083627113"
clickSound.Volume = 0.25
clickSound.PlaybackSpeed = 1.2
clickSound.Parent = button

-- Tweens
local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
local tweenOFF = tweenService:Create(movingPart, tweenInfo, {Position = offPos.Position})
local tweenON = tweenService:Create(movingPart, tweenInfo, {Position = onPos.Position})

-- Track current slow walk status (starts OFF)
local slowWalkEnabled = false

-- Initialize button to OFF state
OnValue.Value = false
movingPart.Position = offPos.Position
redFrame.ZIndex = 0
greenFrame.ZIndex = -1

-- Sync initial state with server (OFF = normal speed)
-- Wait for character to fully load before syncing
task.spawn(function()
	player.CharacterAdded:Wait()
	task.wait(2) -- Wait for server scripts to initialize
	slowWalkToggleEvent:FireServer(false)
end)

local function ButtonPressed(BoolVal, TweenType)
	OnValue.Value = BoolVal
	TweenType:Play()
	
	if BoolVal == true then
		-- ON state (Slow Walk)
		redFrame.ZIndex = -1
		greenFrame.ZIndex = 0
	else
		-- OFF state (Normal Speed)
		redFrame.ZIndex = 0
		greenFrame.ZIndex = -1
	end
	
	return true
end

button.MouseButton1Click:Connect(function()
	-- Play click sound
	clickSound:Play()
	
	button.Interactable = false
	
	if OnValue.Value == false then
		-- Turn ON slow walk (18 speed)
		local BTNPress = ButtonPressed(true, tweenON)
		if BTNPress == true then
			button.Interactable = true
		end
		
		slowWalkEnabled = true
		slowWalkToggleEvent:FireServer(true)
	else
		-- Turn OFF slow walk (back to normal speed)
		local BTNPress = ButtonPressed(false, tweenOFF)
		if BTNPress == true then
			button.Interactable = true
		end
		
		slowWalkEnabled = false
		slowWalkToggleEvent:FireServer(false)
	end
end)