-- EventTimerDisplay.lua
-- Server Script - Place in: Workspace > Map > MainSign
-- Updates the Event countdown timer when events are active

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the script's parent (MainSign)
local mainSign = script.Parent
if not mainSign then
	warn("[EventTimer] Script parent not found!")
	return
end

-- Find the Event part (not Celestial)
local eventPart = mainSign:FindFirstChild("Event")
if not eventPart then
	warn("[EventTimer] Event part not found in MainSign!")
	return
end

-- Find the Timer TextLabel in Event part's descendants
local timerLabel = nil
for _, descendant in ipairs(eventPart:GetDescendants()) do
	if descendant:IsA("TextLabel") and descendant.Name == "Timer" then
		timerLabel = descendant
		print("[EventTimer] Found Timer label at:", descendant:GetFullName())
		break
	end
end

if not timerLabel then
	warn("[EventTimer] Timer TextLabel not found in Event part!")
	return
end

-- Find Primary TextLabel for event name
local primaryLabel = nil
for _, descendant in ipairs(eventPart:GetDescendants()) do
	if descendant:IsA("TextLabel") and descendant.Name == "Primary" then
		primaryLabel = descendant
		print("[EventTimer] Found Primary label at:", descendant:GetFullName())
		break
	end
end

-- Store original text
local ORIGINAL_PRIMARY_TEXT = "Next Event In"
local ORIGINAL_TIMER_COLOR = timerLabel.TextColor3

-- Set default state
if primaryLabel then
	primaryLabel.Text = ORIGINAL_PRIMARY_TEXT
	-- Remove any existing gradient
	local existingGradient = primaryLabel:FindFirstChildOfClass("UIGradient")
	if existingGradient then
		existingGradient:Destroy()
	end
end
timerLabel.Text = "30:00"
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White for countdown

-- Wait for RemoteEvents folder
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEventsFolder then
	warn("[EventTimer] RemoteEvents folder not found!")
	return
end

-- Get EventTimerUpdate BindableEvent
local eventTimerBindable = remoteEventsFolder:FindFirstChild("EventTimerUpdate")
if not eventTimerBindable then
	warn("[EventTimer] EventTimerUpdate BindableEvent not found!")
	return
end

-- Listen for event timer updates
eventTimerBindable.Event:Connect(function(eventType, timeRemaining)
	if not timerLabel then return end
	
	if eventType and timeRemaining then
		-- Event is active - show event countdown with gradient
		if primaryLabel then
			if eventType == "Night" then
				primaryLabel.Text = "🌙 NIGHT EVENT Ends In"
				
				-- Remove any existing gradient
				local existingGradient = primaryLabel:FindFirstChildOfClass("UIGradient")
				if existingGradient then
					existingGradient:Destroy()
				end
				
				-- Add Night gradient (dark blue to light blue)
				local nightGrad = Instance.new("UIGradient")
				nightGrad.Color = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 80)),    -- Dark blue
					ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 150, 255))  -- Light blue
				}
				nightGrad.Parent = primaryLabel
				
			elseif eventType == "Love" then
				primaryLabel.Text = "💖 LOVE EVENT Ends In"
				
				-- Remove any existing gradient
				local existingGradient = primaryLabel:FindFirstChildOfClass("UIGradient")
				if existingGradient then
					existingGradient:Destroy()
				end
				
				-- Add Love gradient (same as celestial - purple to pink)
				local loveGrad = Instance.new("UIGradient")
				loveGrad.Color = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 100, 255)),  -- Purple
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 255))   -- Pink
				}
				loveGrad.Parent = primaryLabel
			end
		end
		
		-- Keep timer text white always
		timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		
		-- Format as MM:SS
		local minutes = math.floor(timeRemaining / 60)
		local seconds = timeRemaining % 60
		timerLabel.Text = string.format("%d:%02d", minutes, seconds)
	elseif timeRemaining then
		-- No event active but countdown is running - show "Next Event In"
		if primaryLabel then
			primaryLabel.Text = "Next Event In"
			
			-- Remove any gradient for normal countdown
			local existingGradient = primaryLabel:FindFirstChildOfClass("UIGradient")
			if existingGradient then
				existingGradient:Destroy()
			end
		end
		timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White
		
		-- Format as MM:SS
		local minutes = math.floor(timeRemaining / 60)
		local seconds = timeRemaining % 60
		timerLabel.Text = string.format("%d:%02d", minutes, seconds)
	end
end)

print("[EventTimer] Event timer display script initialized successfully!")
