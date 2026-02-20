-- OpenShopToBoostsButton.lua
-- Place this LocalScript inside the plus button next to "2x Temp" text
-- When clicked, opens the shop and scrolls to the 2x Temp boosts section

local TS = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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
	warn("[OpenShopToBoosts] Could not find a clickable TextButton or ImageButton!")
	return
end

-- Find UI elements
local screenGui = playerGui:WaitForChild("ScreenGui")
local mainUI = screenGui:WaitForChild("MainUI")
local frames = mainUI:WaitForChild("Frames")
local shopFrame = frames:WaitForChild("ShopFrame")
local scrolling = shopFrame:WaitForChild("Scrolling")
local scrollingFrame = scrolling:WaitForChild("ScrollingFrame")

-- Sound effects
local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://6586979979"
clickSound.Volume = 0.2
clickSound.Parent = button

-- Store original shop frame properties
local origFrameSize = UDim2.new(0.5, 0, 0.5, 0)
local frameTInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

-- Function to open shop and scroll to 2x Temp section
local function openShopToBoosts()
	clickSound:Play()
	
	-- Close other popup frames first
	for _, otherFrame in pairs(frames:GetChildren()) do
		if otherFrame:IsA("Frame") and otherFrame ~= shopFrame then
			if otherFrame.Name == "RebirthFrame" then
				otherFrame.Visible = false
				otherFrame.Size = UDim2.new(0, 0, 0, 0)
				otherFrame.BackgroundTransparency = 1
			end
		end
	end
	
	-- Open the shop frame with animation
	shopFrame.Visible = true
	
	-- Animate shop frame opening
	local openTween = TS:Create(shopFrame, frameTInfo, {
		Size = origFrameSize,
		BackgroundTransparency = 0
	})
	openTween:Play()
	
	-- Wait for shop to open, then scroll to 2x Temp section
	openTween.Completed:Connect(function()
		task.wait(0.3) -- Longer delay to ensure UI is fully loaded
		
		-- Find the 2x Temp frame in the scrolling frame
		local tempFrame = scrollingFrame:FindFirstChild("2x Temp")
		
		-- Debug output
		if not tempFrame then
			print("[OpenShopToBoosts] Searching for '2x Temp' frame...")
			print("[OpenShopToBoosts] Children in ScrollingFrame:")
			for _, child in ipairs(scrollingFrame:GetChildren()) do
				print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
				if child.Name == "2x Temp" then
					tempFrame = child
					print("  ^ FOUND IT!")
				end
			end
		end
		
		if tempFrame then
			-- Calculate Y position of the frame within the canvas
			-- Use the frame's Position.Y.Offset since UIListLayout positions things
			local targetYPosition = tempFrame.AbsolutePosition.Y - scrollingFrame.AbsolutePosition.Y + scrollingFrame.CanvasPosition.Y
			
			-- Center the frame in the viewport
			local viewportHeight = scrollingFrame.AbsoluteSize.Y
			local frameHeight = tempFrame.AbsoluteSize.Y
			local centeredPosition = targetYPosition - (viewportHeight / 2) + (frameHeight / 2)
			
			-- Clamp to valid range
			local maxScroll = scrollingFrame.AbsoluteCanvasSize.Y - viewportHeight
			centeredPosition = math.max(0, math.min(centeredPosition, maxScroll))
			
			-- Smoothly scroll to the position
			local scrollTween = TS:Create(scrollingFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CanvasPosition = Vector2.new(0, centeredPosition)
			})
			scrollTween:Play()
			
			print("[OpenShopToBoosts] Scrolled to 2x Temp section at position:", centeredPosition)
		else
			warn("[OpenShopToBoosts] Could not find '2x Temp' frame in ScrollingFrame")
			-- If not found, scroll to a reasonable middle position (around where boosts would be)
			local middlePosition = math.max(0, (scrollingFrame.AbsoluteCanvasSize.Y - scrollingFrame.AbsoluteSize.Y) / 3)
			scrollingFrame.CanvasPosition = Vector2.new(0, middlePosition)
		end
	end)
end

-- Button click handler
button.MouseButton1Click:Connect(function()
	openShopToBoosts()
end)

-- Optional: Button hover effects
local origBtnSize = button.Size
local hoverScl = 1.1
local clickScl = 0.9
local btnTInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function makeBtnTween(scl)
	local newSize = UDim2.new(
		origBtnSize.X.Scale * scl,
		origBtnSize.X.Offset * scl,
		origBtnSize.Y.Scale * scl,
		origBtnSize.Y.Offset * scl
	)
	return TS:Create(button, btnTInfo, {Size = newSize})
end

button.MouseEnter:Connect(function()
	makeBtnTween(hoverScl):Play()
end)

button.MouseLeave:Connect(function()
	makeBtnTween(1):Play()
end)

print("[OpenShopToBoosts] Button initialized - Click to open shop and scroll to boosts")
