-- LocalGamepassButton.client.luau
-- Place this LocalScript inside any gamepass button
-- Change GAMEPASS_ID to match the gamepass you want to sell

local MarketplaceService = game:GetService("MarketplaceService")
local TS = game:GetService("TweenService")
local button = script.Parent

-- CHANGE THIS to the gamepass you want to sell:
-- Speed2x = 1669318521
-- Money2x = 1669118677
-- VIP = 1669012678
local GAMEPASS_ID = 1669318521 -- Default: 2x Speed

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

-- Button hover effects
button.MouseEnter:Connect(function()
	hoverSound:Play()
	makeBtnTween(hoverScl):Play()
end)

button.MouseLeave:Connect(function()
	makeBtnTween(1):Play()
end)

-- Button click effect + gamepass prompt
button.MouseButton1Click:Connect(function()
	clickSound:Play()
	local shrinkTween = makeBtnTween(clickScl)
	local resetTween = makeBtnTween(1)

	shrinkTween:Play()
	shrinkTween.Completed:Connect(function()
		resetTween:Play()
		MarketplaceService:PromptGamePassPurchase(game.Players.LocalPlayer, GAMEPASS_ID)
	end)
end)
