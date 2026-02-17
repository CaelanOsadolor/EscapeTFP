-- SkipSpinButton.lua
-- LocalScript - Place inside the SkipSpin button in SpinWheelFrame > Content
-- Toggles fast spin mode

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Sound system
local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")

local button = script.Parent
local checkmark = button:FindFirstChild("Checkmark", true) -- Recursive search

if not checkmark then
	warn("Checkmark not found in SkipSpin button! Searched recursively.")
	-- Try to find it as an ImageLabel
	for _, child in pairs(button:GetDescendants()) do
		if child.Name == "Checkmark" then
			checkmark = child
			print("Found Checkmark:", checkmark:GetFullName())
			break
		end
	end
end

-- Initially hide checkmark (fast spin OFF)
checkmark.Visible = false

-- Store fast spin state in a BoolValue that WheelUI can read
local SpinWheel = script.Parent.Parent.Parent -- Content > SpinWheelFrame > SpinWheel
local fastSpinEnabled = SpinWheel:FindFirstChild("FastSpinEnabled")

if not fastSpinEnabled then
	fastSpinEnabled = Instance.new("BoolValue")
	fastSpinEnabled.Name = "FastSpinEnabled"
	fastSpinEnabled.Value = false
	fastSpinEnabled.Parent = SpinWheel
end

-- Find the actual clickable button
local clickButton = button:FindFirstChildWhichIsA("TextButton") 
	or button:FindFirstChildWhichIsA("ImageButton")

if not clickButton then
	-- Maybe the button itself is clickable
	if button:IsA("GuiButton") then
		clickButton = button
	end
end

-- Handle button click
if clickButton and clickButton:IsA("GuiButton") then
	clickButton.MouseButton1Click:Connect(function()
		-- Play click sound
		if soundsFolder then
			local clickSound = soundsFolder:FindFirstChild("Click")
			if clickSound then
				clickSound:Play()
			end
		end
		
		-- Toggle fast spin mode
		fastSpinEnabled.Value = not fastSpinEnabled.Value
		
		-- Update checkmark visibility
		if checkmark then
			checkmark.Visible = fastSpinEnabled.Value
			print("Fast spin mode:", fastSpinEnabled.Value and "ON (Checkmark visible)" or "OFF (Checkmark hidden)")
		end
	end)
	
	print("SkipSpin button connected")
else
	warn("Could not find clickable button in SkipSpin")
end
