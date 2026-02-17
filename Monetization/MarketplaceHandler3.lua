-- Marketplace Handler Script (Game 3)
-- Place in ServerScriptService/GameManager/Monetization
-- Handles all developer product purchases
-- NOTE: Gamepasses are handled by GamepassManager in GameManager folder

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

-- Require modules
local DevProducts = require(script.Parent.DevProducts)
local GamepassManager = require(script.Parent.Parent.GameManager.GamepassManager)

-- Track pending purchases to prevent double-granting
local pendingPurchases = {}

-- Process receipt for developer products
local function processReceipt(receiptInfo)
	-- Find the player
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)

	if not player then
		-- Player left, grant purchase next time they join
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Check if this purchase has already been granted
	local purchaseKey = receiptInfo.PlayerId .. "_" .. receiptInfo.PurchaseId
	if pendingPurchases[purchaseKey] then
		-- Already processing this purchase
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Mark as processing
	pendingPurchases[purchaseKey] = true

	-- Check if this is a steal purchase (has pending steal data)
	local success = false
	if receiptInfo.ProductId == 3533182046 then -- Steal product (Game 3 ID)
		local victimUserId = player:GetAttribute("PendingStealVictimUserId")
		local slotName = player:GetAttribute("PendingStealSlotName")
		
		if victimUserId and slotName then
			-- Clear pending steal data
			player:SetAttribute("PendingStealVictimUserId", nil)
			player:SetAttribute("PendingStealSlotName", nil)
			
			-- Process the steal
			local ServerScriptService = game:GetService("ServerScriptService")
			local BaseSlotManager = require(ServerScriptService.Things.BaseSlotManager)
			BaseSlotManager.ProcessSteal(player, victimUserId, slotName)
			success = true
		else
			warn("[MarketplaceHandler] Steal purchase but no pending steal data")
			success = false
		end
	else
		-- Process normal developer product
		success = DevProducts:ProcessPurchase(player, receiptInfo.ProductId)
	end

	-- Clean up
	pendingPurchases[purchaseKey] = nil

	if success then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

-- Set the callback
MarketplaceService.ProcessReceipt = processReceipt

-- Note: Gamepass purchases are handled directly in GamepassManager
-- No need to handle them here since GamepassManager already has:
-- MarketplaceService.PromptGamePassPurchaseFinished:Connect(...)
-- and PlayerSetup.lua calls GamepassManager.InitializePlayer(player)

print("Marketplace Handler 3 initialized!")
