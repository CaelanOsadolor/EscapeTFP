--// Combined script: Hover & click effect + PopUp frame functionality

local btn = script.Parent
local frame = btn.Parent.Parent.Frames.ShopFrame
local closeBtn = frame.Close
local TS = game:GetService("TweenService")

-- Sound effects
local hoverSound = Instance.new("Sound")
hoverSound.SoundId = "rbxassetid://10066931761"
hoverSound.Volume = 0.15 -- Adjust hover sound volume (0-1)
hoverSound.Parent = btn

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6586979979"
clickSound.Volume = 0.15 -- Adjust click sound volume (0-1)
clickSound.Parent = btn

-- Button hover/click properties
local origBtnSize = btn.Size
local hoverScl = 1.05
local clickScl = 0.9
local btnTInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

-- Frame popup properties
local origFrameSize = frame.Size
local frameTInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local isOpen = false

-- Initialize frame
frame.Size = UDim2.new(0, 0, 0, 0)
frame.BackgroundTransparency = 1

-- Get all ImageLabels and other UI elements inside the button
local function getButtonChildren()
	local children = {}
	for _, child in pairs(btn:GetChildren()) do
		if child:IsA("ImageLabel") or child:IsA("TextLabel") or child:IsA("ImageButton") or child:IsA("TextButton") then
			-- Exclude Studs from scaling
			if child.Name ~= "Studs" then
				-- Set AnchorPoint to (0.5, 0.8) to prevent shifting
				if child.AnchorPoint ~= Vector2.new(0.5, 0.8) then
					local currentPos = child.Position
					local currentSize = child.Size
					local oldAnchor = child.AnchorPoint
					child.AnchorPoint = Vector2.new(0.5, 0.8)
					-- Adjust position to maintain visual location
					child.Position = UDim2.new(
						currentPos.X.Scale + currentSize.X.Scale * (0.5 - oldAnchor.X),
						currentPos.X.Offset + currentSize.X.Offset * (0.5 - oldAnchor.X),
						currentPos.Y.Scale + currentSize.Y.Scale * (0.8 - oldAnchor.Y),
						currentPos.Y.Offset + currentSize.Y.Offset * (0.8 - oldAnchor.Y)
					)
				end
				table.insert(children, {element = child, origSize = child.Size})
			end
		end
	end
	return children
end

local buttonChildren = getButtonChildren()

-- Set button AnchorPoint to (0.5, 0.8) to prevent shifting
if btn.AnchorPoint ~= Vector2.new(0.5, 0.8) then
	local currentPos = btn.Position
	local oldAnchor = btn.AnchorPoint
	btn.AnchorPoint = Vector2.new(0.5, 0.8)
	btn.Position = UDim2.new(
		currentPos.X.Scale + btn.Size.X.Scale * (0.5 - oldAnchor.X),
		currentPos.X.Offset + btn.Size.X.Offset * (0.5 - oldAnchor.X),
		currentPos.Y.Scale + btn.Size.Y.Scale * (0.8 - oldAnchor.Y),
		currentPos.Y.Offset + btn.Size.Y.Offset * (0.8 - oldAnchor.Y)
	)
end

-- Store original text sizes
for _, childData in pairs(buttonChildren) do
	if childData.element:IsA("TextLabel") or childData.element:IsA("TextButton") then
		childData.origTextSize = childData.element.TextSize
	end
end

-- Button tween function
local function makeBtnTween(scl)
	local newSize = UDim2.new(
		origBtnSize.X.Scale * scl,
		origBtnSize.X.Offset * scl,
		origBtnSize.Y.Scale * scl,
		origBtnSize.Y.Offset * scl
	)
	local tweens = {TS:Create(btn, btnTInfo, {Size = newSize})}

	-- Scale children size only (don't change position to prevent shifting)
	for _, childData in pairs(buttonChildren) do
		local childNewSize = UDim2.new(
			childData.origSize.X.Scale * scl,
			childData.origSize.X.Offset * scl,
			childData.origSize.Y.Scale * scl,
			childData.origSize.Y.Offset * scl
		)
		-- Scale text size for text elements
		if childData.origTextSize then
			table.insert(tweens, TS:Create(childData.element, btnTInfo, {Size = childNewSize, TextSize = childData.origTextSize * scl}))
		else
			table.insert(tweens, TS:Create(childData.element, btnTInfo, {Size = childNewSize}))
		end
	end

	return tweens
end

-- Frame tween function
local function makeFrameTween(scl, alpha)
	local newSize = UDim2.new(
		origFrameSize.X.Scale * scl,
		origFrameSize.X.Offset * scl,
		origFrameSize.Y.Scale * scl,
		origFrameSize.Y.Offset * scl
	)
	return TS:Create(frame, frameTInfo, {Size = newSize, BackgroundTransparency = alpha})
end

-- Frame popup functions
local function popIn()
	frame.Visible = true
	makeFrameTween(1, 0):Play()
	isOpen = true
end

local function popOut()
	local tween = makeFrameTween(0, 1)
	tween:Play()
	tween.Completed:Connect(function()
		frame.Visible = false
		isOpen = false
	end)
end

-- Button hover effects
btn.MouseEnter:Connect(function()
	hoverSound:Play()
	local tweens = makeBtnTween(hoverScl)
	for _, tween in pairs(tweens) do
		tween:Play()
	end
end)

btn.MouseLeave:Connect(function()
	local tweens = makeBtnTween(1)
	for _, tween in pairs(tweens) do
		tween:Play()
	end
end)

-- Button click effect + toggle popup
btn.MouseButton1Click:Connect(function()
	clickSound:Play()
	local shrinkTweens = makeBtnTween(clickScl)
	local resetTweens = makeBtnTween(1)

	for _, tween in pairs(shrinkTweens) do
		tween:Play()
	end

	shrinkTweens[1].Completed:Connect(function()
		for _, tween in pairs(resetTweens) do
			tween:Play()
		end

		-- Check if this frame is currently open
		local wasOpen = frame.Visible and frame.Size == origFrameSize

		-- Close other popup frames (ShopFrame and RebirthFrame)
		local framesFolder = btn.Parent.Parent.Frames
		for _, otherFrame in pairs(framesFolder:GetChildren()) do
			if otherFrame:IsA("Frame") and otherFrame ~= frame then
				if otherFrame.Name == "ShopFrame" or otherFrame.Name == "RebirthFrame" then
					-- Reset popup frames to closed state
					otherFrame.Visible = false
					otherFrame.Size = UDim2.new(0, 0, 0, 0)
					otherFrame.BackgroundTransparency = 1
				end
			end
		end

		-- Toggle this frame based on its actual state
		if wasOpen then
			popOut()
		else
			popIn()
		end
	end)
end)

-- Close button functionality
closeBtn.MouseButton1Click:Connect(function()
	popOut()
end)