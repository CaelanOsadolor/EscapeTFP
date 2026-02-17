-- Speed Shop UI Handler
-- Place as LocalScript inside StarterGui.SpeedShop.Frame

local player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- Stud background configuration
local studImageId = "rbxassetid://6927295847"
local studSize = 64 -- Size of each stud tile in pixels (adjust as needed)

-- Main frame
local speedShopFrame = script.Parent

-- RemoteEvent
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local speedPurchaseEvent = remoteEventsFolder:WaitForChild("SpeedPurchaseEvent")

-- Sounds
local soundsFolder = ReplicatedStorage:WaitForChild("Sounds")
local buttonPressSound = soundsFolder:WaitForChild("ButtonPress")
local purchaseSuccessSound = soundsFolder:WaitForChild("PurchaseSuccess")
local errorSound = soundsFolder:WaitForChild("Error")

-- Configuration
local MAX_SPEED = 2000
local MIN_SPEED = 18
local BASE_COST = 250
local COST_MULTIPLIER = 1.15

-- Helper function to play sound
local function playSound(sound)
	if sound then
		local soundClone = sound:Clone()
		soundClone.Parent = game:GetService("SoundService")
		soundClone:Play()
		soundClone.Ended:Connect(function()
			soundClone:Destroy()
		end)
	end
end

-- Speed tier configurations for +10 speed (changes based on current speed)
local speedTiers = {
	{minSpeed = 18, maxSpeed = 50, robuxPrice = 9, productId = 3509332757},
	{minSpeed = 51, maxSpeed = 100, robuxPrice = 29, productId = 3509333449},
	{minSpeed = 101, maxSpeed = 150, robuxPrice = 69, productId = 3509333798},
	{minSpeed = 151, maxSpeed = 200, robuxPrice = 99, productId = 3509334189},
	{minSpeed = 201, maxSpeed = 2000, robuxPrice = 129, productId = 3509334769}
}

-- Speed button configurations
local speedButtons = {
	{
		frame = speedShopFrame:FindFirstChild("Speed1"),
		speedIncrease = 1,
		isTiered = true -- All Robux purchases give +10 with tiered pricing
	},
	{
		frame = speedShopFrame:FindFirstChild("Speed2"),
		speedIncrease = 5,
		isTiered = true -- All Robux purchases give +10 with tiered pricing
	},
	{
		frame = speedShopFrame:FindFirstChild("Speed3"),
		speedIncrease = 10,
		isTiered = true -- All Robux purchases give +10 with tiered pricing
	}
}

-- Format number with extended suffixes
local function formatNumber(num)
	local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
	local tier = 1
	
	while num >= 1000 and tier < #suffixes do
		num = num / 1000
		tier = tier + 1
	end
	
	if num >= 100 then
		return string.format("%.0f%s", num, suffixes[tier])
	elseif num >= 10 then
		return string.format("%.1f%s", num, suffixes[tier])
	else
		return string.format("%.2f%s", num, suffixes[tier])
	end
end

-- Helper function to get TextLabel from Frame or direct TextLabel
local function getTextLabel(parent, name)
	local element = parent:FindFirstChild(name)
	if not element then return nil end
	if element:IsA("TextLabel") then
		return element
	else
		return element:FindFirstChild("TextLabel") or element:FindFirstChildWhichIsA("TextLabel")
	end
end

-- Get the current speed tier for +10 upgrades
local function getCurrentSpeedTier(currentSpeed)
	for _, tier in ipairs(speedTiers) do
		if currentSpeed >= tier.minSpeed and currentSpeed <= tier.maxSpeed then
			return tier
		end
	end
	return speedTiers[#speedTiers] -- Default to highest tier
end

-- Calculate cost for speed increase (matches server formula)
local function getSpeedCost(currentSpeed, speedIncrease)
	local totalCost = 0
	
	for i = 1, speedIncrease do
		local targetSpeed = currentSpeed + i
		if targetSpeed > MAX_SPEED then
			break
		end
		
		local speedLevel = targetSpeed - MIN_SPEED
		local cost = math.floor(BASE_COST * (COST_MULTIPLIER ^ speedLevel))
		totalCost = totalCost + cost
	end
	
	return totalCost
end

-- Update a single speed button UI
local function updateSpeedButton(buttonConfig)
	local frame = buttonConfig.frame
	if not frame then return end
	
	local speedIncrease = buttonConfig.speedIncrease
	local currentSpeed = player:GetAttribute("Speed") or MIN_SPEED
	
	-- Get UI elements
	local buyFrame = frame:FindFirstChild("Buy")
	local buyRobuxFrame = frame:FindFirstChild("BuyRobux")
	local buyButton = buyFrame and buyFrame:FindFirstChild("TextButton")
	local currentSpeedLabel = getTextLabel(frame, "CurrentSpeed")
	local nextSpeedLabel = getTextLabel(frame, "NextSpeed")
	local ownedLabel = getTextLabel(frame, "Owned")
	local infoLabel = getTextLabel(frame, "Info")
	local amountLabel = getTextLabel(buyRobuxFrame, "Amount")
	
	-- Update current speed display
	if currentSpeedLabel then
		currentSpeedLabel.Text = tostring(currentSpeed)
	end
	
	if ownedLabel then
		ownedLabel.Text = tostring(currentSpeed)
	end
	
	-- Calculate next speed and cost
	local actualIncrease = math.min(speedIncrease, MAX_SPEED - currentSpeed)
	local nextSpeed = currentSpeed + actualIncrease
	local cost = getSpeedCost(currentSpeed, actualIncrease)
	
	-- Update next speed display
	if nextSpeedLabel then
		nextSpeedLabel.Text = tostring(nextSpeed)
	end
	
	-- Update cost display
	if buyButton and cost then
		buyButton.Text = "$" .. formatNumber(cost)
	end
	
	-- Update info label
	if infoLabel then
		infoLabel.Text = "+" .. actualIncrease .. " Speed\n" .. currentSpeed .. "→" .. nextSpeed
	end
	
	-- Update Robux amount and cost for tiered buttons
	if buttonConfig.isTiered then
		local currentTier = getCurrentSpeedTier(currentSpeed)
		if amountLabel then
			amountLabel.Text = "+10" -- All Robux purchases give +10 speed
		end
		-- Update Robux button to show cost
		if buyRobuxFrame then
			local robuxButton = buyRobuxFrame:FindFirstChild("TextButton")
			if robuxButton then
				local robuxIcon = robuxButton:FindFirstChild("RobuxIcon") or robuxButton
				local costLabel = buyRobuxFrame:FindFirstChild("Cost")
				if costLabel and costLabel:IsA("TextLabel") then
					costLabel.Text = tostring(currentTier.robuxPrice)
				end
			end
		end
		-- Store current tier for purchase handler
		buttonConfig.currentTier = currentTier
	else
		if amountLabel then
			amountLabel.Text = "+" .. speedIncrease
		end
	end
	
	-- Check if at max speed
	if currentSpeed >= MAX_SPEED then
		if buyButton then
			buyButton.Text = "MAX"
		end
		if buyFrame then
			buyFrame.Visible = false
		end
		if buyRobuxFrame then
			buyRobuxFrame.Visible = false
		end
	else
		if buyFrame then
			buyFrame.Visible = true
		end
		if buyRobuxFrame then
			buyRobuxFrame.Visible = true
		end
	end
end

-- Update all speed buttons
local function updateAllButtons()
	for _, buttonConfig in pairs(speedButtons) do
		updateSpeedButton(buttonConfig)
	end
end

-- Setup button click handlers
for _, buttonConfig in pairs(speedButtons) do
	local frame = buttonConfig.frame
	if frame then
		-- Money purchase
		local buyFrame = frame:FindFirstChild("Buy")
		if buyFrame then
			local buyButton = buyFrame:FindFirstChild("TextButton")
			if buyButton then
				buyButton.MouseButton1Click:Connect(function()
					local currentSpeed = player:GetAttribute("Speed") or MIN_SPEED
					if currentSpeed < MAX_SPEED then
						playSound(buttonPressSound)
						speedPurchaseEvent:FireServer(buttonConfig.speedIncrease)
					end
				end)
			end
		end
		
		-- Robux purchase
		local buyRobuxFrame = frame:FindFirstChild("BuyRobux")
		if buyRobuxFrame then
			local buyRobuxButton = buyRobuxFrame:FindFirstChild("TextButton")
			if buyRobuxButton then
				buyRobuxButton.MouseButton1Click:Connect(function()
					local currentSpeed = player:GetAttribute("Speed") or MIN_SPEED
					if currentSpeed < MAX_SPEED then
						-- For tiered buttons, use dynamic product ID
						local productId = buttonConfig.isTiered and buttonConfig.currentTier.productId or buttonConfig.productId
						if productId and productId > 0 then
							MarketplaceService:PromptProductPurchase(player, productId)
						end
					end
				end)
			end
		end
	end
end

-- Create stud background
local studBackground = Instance.new("ImageLabel")
studBackground.Name = "StudBackground"
studBackground.Image = studImageId
studBackground.ScaleType = Enum.ScaleType.Tile
studBackground.TileSize = UDim2.new(0, studSize, 0, studSize)
studBackground.Size = UDim2.new(1, 0, 1, 0)
studBackground.Position = UDim2.new(0, 0, 0, 0)
studBackground.BackgroundTransparency = 1
studBackground.ZIndex = 0
studBackground.Parent = speedShopFrame

-- Watch for speed changes
player:GetAttributeChangedSignal("Speed"):Connect(updateAllButtons)

-- Initial UI update
updateAllButtons()
