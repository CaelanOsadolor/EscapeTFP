-- LocalPackButton.client.luau
-- Place this LocalScript inside pack buttons (Pro Pack, OP Pack)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local TS = game:GetService("TweenService")
local button = script.Parent
local player = Players.LocalPlayer

-- CONFIGURE THESE FOR EACH PACK:
local PRODUCT_ID = 3511184157  -- Change to: 3511184157 (Pro Pack) or 3511185098 (OP Pack)
local PACK_NAME = "Pro Pack"   -- Change to: "Pro Pack" or "OP Pack"

-- Pack attribute name (e.g., "OwnsProPack" or "OwnsOPPack")
local PACK_ATTRIBUTE = "Owns" .. PACK_NAME:gsub(" ", "")

-- Button hover/click properties
local origBtnSize = button.Size
local hoverScl = 1.05
local clickScl = 0.9
local btnTInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

-- Track if owned
local isOwned = false

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

-- Update button to show owned state
local function updateButtonState()
	if isOwned then
		-- Find TextLabel inside button to update text
		local textLabel = button:FindFirstChildOfClass("TextLabel")
		if textLabel then
			textLabel.Text = "OWNED"
		end
		button.Active = false
	else
		button.Active = true
	end
end

-- Check if player owns pack
local function checkOwnership()
	isOwned = player:GetAttribute(PACK_ATTRIBUTE) == true
	updateButtonState()
end

-- Button hover effects (only if not owned)
button.MouseEnter:Connect(function()
	if not isOwned then
		hoverSound:Play()
		makeBtnTween(hoverScl):Play()
	end
end)

button.MouseLeave:Connect(function()
	if not isOwned then
		makeBtnTween(1):Play()
	end
end)

-- Button click effect + purchase prompt
button.MouseButton1Click:Connect(function()
	if isOwned then
		return -- Don't allow clicking if owned
	end
	
	clickSound:Play()
	local shrinkTween = makeBtnTween(clickScl)
	local resetTween = makeBtnTween(1)

	shrinkTween:Play()
	shrinkTween.Completed:Connect(function()
		resetTween:Play()
		MarketplaceService:PromptProductPurchase(player, PRODUCT_ID)
	end)
end)

-- Listen for purchase completion
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
	if userId == player.UserId and productId == PRODUCT_ID and wasPurchased then
		-- Wait a moment for server to set attribute
		task.wait(0.5)
		checkOwnership()
	end
end)

-- Listen for attribute changes (in case server sets it)
player:GetAttributeChangedSignal(PACK_ATTRIBUTE):Connect(function()
	checkOwnership()
end)

-- Initial check
checkOwnership()
