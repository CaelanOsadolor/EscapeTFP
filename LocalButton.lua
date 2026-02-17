-- CashPack1Button.client.luau
-- Place this LocalScript inside the Cash Pack #1 button

local MarketplaceService = game:GetService("MarketplaceService")
local TS = game:GetService("TweenService")
local button = script.Parent

local PRODUCT_ID = 3509512671 -- Cash Pack #4 (1B money for 349 Robux)

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

-- Button click effect + purchase prompt
button.MouseButton1Click:Connect(function()
	clickSound:Play()
	local shrinkTween = makeBtnTween(clickScl)
	local resetTween = makeBtnTween(1)

	shrinkTween:Play()
	shrinkTween.Completed:Connect(function()
		resetTween:Play()
		MarketplaceService:PromptProductPurchase(game.Players.LocalPlayer, PRODUCT_ID)
	end)
end)
