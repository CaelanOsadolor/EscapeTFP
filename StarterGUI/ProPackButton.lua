-- ProPackButton.lua
-- LocalScript to handle Pro Pack purchase and shop opening
-- Place in: ProPack Frame

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local frame = script.Parent -- The ProPack Frame
local button = frame:WaitForChild("ImageButton")
local costFrame = frame:WaitForChild("Cost")
local costLabel = costFrame:WaitForChild("Cost") -- The price TextLabel
local bottomLabel = frame:WaitForChild("Bottom") -- The pack name TextLabel
local radial = frame:WaitForChild("Radial")

-- Product IDs
local PROPACK_PRODUCT_ID = 3515275327
local OPPACK_PRODUCT_ID = 3515277319

-- Current product state
local currentProductId = PROPACK_PRODUCT_ID

-- Rotation animation for Radial only
local rotateInfo = TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false) -- -1 = infinite, no reverse

local radialRotate = TweenService:Create(radial, rotateInfo, {
	Rotation = 360
})

radialRotate:Play()

-- Find the shop frame
local screenGui = player.PlayerGui:WaitForChild("ScreenGui")
local mainUI = screenGui:WaitForChild("MainUI")
local frames = mainUI:WaitForChild("Frames")
local shopFrame = frames:WaitForChild("ShopFrame")

-- Cooldown tracking
local lastPurchaseTime = 0
local COOLDOWN = 3 -- 3 second cooldown to prevent spam

-- Update button display based on ownership
local function UpdateButtonDisplay()
	local ownsProPack = player:GetAttribute("OwnsProPack")
	local ownsOPPack = player:GetAttribute("OwnsOPPack")

	if ownsOPPack then
		-- Owns both packs - show "Owned" and hide cost
		bottomLabel.Text = "Owned"
		costFrame.Visible = false
		currentProductId = nil -- Don't allow purchase
	elseif ownsProPack then
		-- Owns Pro Pack - show OP Pack
		bottomLabel.Text = "OP Pack"
		costLabel.Text = "99"
		costFrame.Visible = true
		currentProductId = OPPACK_PRODUCT_ID
	else
		-- Doesn't own anything - show Pro Pack
		bottomLabel.Text = "Pro Pack"
		costLabel.Text = "49"
		costFrame.Visible = true
		currentProductId = PROPACK_PRODUCT_ID
	end
end

-- Initial update
UpdateButtonDisplay()

-- Listen for ownership changes
player:GetAttributeChangedSignal("OwnsProPack"):Connect(UpdateButtonDisplay)
player:GetAttributeChangedSignal("OwnsOPPack"):Connect(UpdateButtonDisplay)

-- Button click handler
button.MouseButton1Click:Connect(function()
	-- Play button press sound
	local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")
	if soundsFolder then
		local buttonSound = soundsFolder:FindFirstChild("ButtonPress")
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

	-- Check cooldown
	local currentTime = tick()
	if currentTime - lastPurchaseTime < COOLDOWN then
		warn("[ProPackButton] Cooldown active, wait", math.ceil(COOLDOWN - (currentTime - lastPurchaseTime)), "seconds")
		return
	end

	-- Check if already owned both packs
	if not currentProductId then
		warn("[ProPackButton] Already owns both packs")
		return
	end

	-- Open shop frame
	if shopFrame then
		-- Find TweenShop script to use its opening function
		local tweenShopScript = mainUI:FindFirstChild("Shop")
		if tweenShopScript and tweenShopScript:FindFirstChild("TweenShop") then
			-- Trigger the shop opening by simulating button click
			local shopButton = mainUI:FindFirstChild("Shop")
			if shopButton and shopButton:IsA("TextButton") or shopButton:IsA("ImageButton") then
				-- Shop should open via TweenShop
			end
		end

		-- Fallback: just show the frame
		shopFrame.Visible = true
		shopFrame.Size = UDim2.new(0.5, 0, 0.5, 0) -- ShocurrentProductId
		shopFrame.BackgroundTransparency = 0
	end

	-- Prompt purchase
	local success, errorMessage = pcall(function()
		MarketplaceService:PromptProductPurchase(player, currentProductId)
	end)

	if not success then
		warn("[ProPackButton] Failed to prompt purchase:", errorMessage)
	end

	lastPurchaseTime = currentTime
end)

print("[ProPackButton] Loaded!")
