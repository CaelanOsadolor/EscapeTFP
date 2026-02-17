-- BuySpinsButton.lua
-- LocalScript - Place inside each Buy button (Buy1 or Buy5)
-- Configure the PRODUCT_ID for each button

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- Sound system
local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")

local button = script.Parent

-- CONFIGURE THIS FOR EACH BUTTON:
-- Buy1 = Product ID 3536444020 (1 spin for 29 R$)
-- Buy5 = Product ID 3536444202 (5 spins for 99 R$)
local PRODUCT_ID = 3536444020 -- Change this based on which button this is

-- Detect which button this is by name
if button.Name == "Buy5" then
	PRODUCT_ID = 3536444202
elseif button.Name == "Buy1" then
	PRODUCT_ID = 3536444020
end

-- Find the actual clickable button
local clickButton = button:FindFirstChildWhichIsA("TextButton") 
	or button:FindFirstChildWhichIsA("ImageButton")
	or button

-- Handle button click
if clickButton:IsA("GuiButton") then
	clickButton.MouseButton1Click:Connect(function()
		-- Play button sound
		if soundsFolder then
			local buttonSound = soundsFolder:FindFirstChild("ButtonPress")
			if buttonSound then
				buttonSound:Play()
			end
		end
		
		-- Prompt purchase
		local success, errorMessage = pcall(function()
			MarketplaceService:PromptProductPurchase(player, PRODUCT_ID)
		end)
		
		if not success then
			warn("Failed to prompt purchase:", errorMessage)
		end
	end)
	
	print("Buy spins button connected (Product ID:", PRODUCT_ID, ")")
else
	warn("Could not find clickable button in", button.Name)
end
