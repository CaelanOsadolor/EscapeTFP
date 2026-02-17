-- Carry Shop Tween Script
-- Place this as a LocalScript inside StarterGui.CarryShop

local screenGui = script.Parent
local frame = screenGui:WaitForChild("Frame")
local closeBtn = frame:WaitForChild("Close")
local carryBtn = frame:FindFirstChild("Carry")
local TS = game:GetService("TweenService")

-- Animation properties
local origFrameSize = frame.Size
local frameTInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local buttonTInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local hoverScl = 1.05
local clickScl = 0.9

-- Sound effects
local hoverSound = Instance.new("Sound")
hoverSound.SoundId = "rbxassetid://10066931761"
hoverSound.Volume = 0.15
hoverSound.Parent = screenGui

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6586979979"
clickSound.Volume = 0.15
clickSound.Parent = screenGui

-- Initialize frame
frame.Size = UDim2.new(0, 0, 0, 0)
frame.BackgroundTransparency = 1
screenGui.Enabled = false

-- Frame tween functions
local function makeFrameTween(scl, alpha)
	local newSize = UDim2.new(
		origFrameSize.X.Scale * scl,
		origFrameSize.X.Offset * scl,
		origFrameSize.Y.Scale * scl,
		origFrameSize.Y.Offset * scl
	)
	return TS:Create(frame, frameTInfo, {Size = newSize, BackgroundTransparency = alpha})
end

local function popIn()
	frame.Visible = true
	makeFrameTween(1, 0):Play()
end

local function popOut()
	local tween = makeFrameTween(0, 1)
	tween:Play()
	tween.Completed:Connect(function()
		frame.Visible = false
		screenGui.Enabled = false
	end)
end

-- Button tween functions
local function makeBtnTween(btn, scl)
	if not btn then return {} end
	local origSize = btn:GetAttribute("OriginalSize")
	if not origSize then
		origSize = btn.Size
		btn:SetAttribute("OriginalSize", origSize)
	end
	
	local newSize = UDim2.new(
		origSize.X.Scale * scl,
		origSize.X.Offset * scl,
		origSize.Y.Scale * scl,
		origSize.Y.Offset * scl
	)
	return TS:Create(btn, buttonTInfo, {Size = newSize})
end

-- Setup carry button hover effects
if carryBtn and carryBtn:IsA("GuiButton") then
	carryBtn.MouseEnter:Connect(function()
		hoverSound:Play()
		makeBtnTween(carryBtn, hoverScl):Play()
	end)
	
	carryBtn.MouseLeave:Connect(function()
		makeBtnTween(carryBtn, 1):Play()
	end)
	
	carryBtn.MouseButton1Click:Connect(function()
		clickSound:Play()
		local shrinkTween = makeBtnTween(carryBtn, clickScl)
		shrinkTween:Play()
		shrinkTween.Completed:Wait()
		makeBtnTween(carryBtn, 1):Play()
	end)
end

-- Close button functionality
closeBtn.MouseButton1Click:Connect(function()
	clickSound:Play()
	popOut()
end)

-- Watch for when shop is opened
screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if screenGui.Enabled then
		popIn()
	end
end)
