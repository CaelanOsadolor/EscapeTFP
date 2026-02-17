-- Carry Shop UI Handler
-- Place as LocalScript inside StarterGui.CarryShop.Frame.Carry

local player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- Stud background configuration
local studImageId = "rbxassetid://6927295847"
local studSize = 64 -- Size of each stud tile in pixels (adjust as needed)

-- UI Elements
local carryFrame = script.Parent
local buyFrame = carryFrame:FindFirstChild("Buy")
local buyRobuxFrame = carryFrame:FindFirstChild("BuyRobux")
local buyButton = buyFrame and buyFrame:FindFirstChild("TextButton")
local buyRobuxButton = buyRobuxFrame and buyRobuxFrame:FindFirstChild("TextButton")
local costLabel = buyButton -- The TextButton itself displays the cost

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

local currentCarryLabel = getTextLabel(carryFrame, "CurrentCarry")
local nextCarryLabel = getTextLabel(carryFrame, "NextCarry")
local ownedLabel = getTextLabel(carryFrame, "Owned")
local infoLabel = getTextLabel(carryFrame, "Info")
local maxReachedLabel = carryFrame:FindFirstChild("MaxReached")

-- RemoteEvent
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local carryPurchaseEvent = remoteEventsFolder:WaitForChild("CarryPurchaseEvent")

-- Sounds
local soundsFolder = ReplicatedStorage:WaitForChild("Sounds")
local buttonPressSound = soundsFolder:WaitForChild("ButtonPress")
local purchaseSuccessSound = soundsFolder:WaitForChild("PurchaseSuccess")
local errorSound = soundsFolder:WaitForChild("Error")

-- Configuration
local MAX_CARRY = 10
local ROBUX_PRICE = 29
-- IMPORTANT: Create the product in Roblox, then replace this with the actual Product ID!
local CARRY_PRODUCT_ID = 3509300769 -- Carry Upgrade Developer Product

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

-- Calculate cost for next carry level (matches server formula)
local function getCarryCost(currentCarry)
	if currentCarry >= MAX_CARRY then
		return nil
	end
	
	local BASE_COST = 500000
	local COST_MULTIPLIER = 85 -- Match server scaling
	local carryLevel = currentCarry - 1 + 1
	local cost = math.floor(BASE_COST * (COST_MULTIPLIER ^ (carryLevel - 1)))
	
	return cost
end

-- Update UI based on current carry capacity
local function updateUI()
	local currentCarry = player:GetAttribute("CarryCapacity") or 1
	
	-- Update current carry display
	if currentCarryLabel then
		currentCarryLabel.Text = tostring(currentCarry)
	end
	
	-- Update owned display
	if ownedLabel then
		ownedLabel.Text = tostring(currentCarry)
	end
	
	-- Check if at max carry
	if currentCarry >= MAX_CARRY then
		-- At max level
		if costLabel then
			costLabel.Text = "MAX"
		end
		if nextCarryLabel then
			nextCarryLabel.Text = tostring(MAX_CARRY)
		end
		if infoLabel then
			infoLabel.Text = "+1 Carry\n" .. currentCarry .. "→" .. MAX_CARRY
		end
		if maxReachedLabel then
			maxReachedLabel.Visible = true
		end
		if buyFrame then
			buyFrame.Visible = false
		end
		if buyRobuxFrame then
			buyRobuxFrame.Visible = false
		end
	else
		-- Can still upgrade
		local nextCarry = currentCarry + 1
		local cost = getCarryCost(currentCarry)
		
		if nextCarryLabel then
			nextCarryLabel.Text = tostring(nextCarry)
		end
		
		if costLabel and cost then
			costLabel.Text = "$" .. formatNumber(cost)
		end
		
		if infoLabel then
			infoLabel.Text = "+1 Carry\n" .. currentCarry .. "→" .. nextCarry
		end
		
		if maxReachedLabel then
			maxReachedLabel.Visible = false
		end
		
		if buyFrame then
			buyFrame.Visible = true
		end
		
		if buyRobuxFrame then
			buyRobuxFrame.Visible = true
		end
	end
end

-- Handle money purchase
if buyButton then
	buyButton.MouseButton1Click:Connect(function()
		local currentCarry = player:GetAttribute("CarryCapacity") or 1
		if currentCarry < MAX_CARRY then
			playSound(buttonPressSound)
			carryPurchaseEvent:FireServer("Money")
		end
	end)
end

-- Handle Robux purchase
if buyRobuxButton then
	buyRobuxButton.MouseButton1Click:Connect(function()
		local currentCarry = player:GetAttribute("CarryCapacity") or 1
		if currentCarry < MAX_CARRY then
			-- Prompt developer product purchase
			MarketplaceService:PromptProductPurchase(player, CARRY_PRODUCT_ID)
		end
	end)
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
studBackground.Parent = carryFrame.Parent

-- Watch for carry capacity changes
player:GetAttributeChangedSignal("CarryCapacity"):Connect(updateUI)

-- Initial UI update
updateUI()
