-- CheckAdsOnShopOpen.client.lua
-- Place this LocalScript in the ShopFrame or MainUI
-- Checks ad availability when shop opens

local AdService = game:GetService("AdService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Find the shop frame
local shopFrame = script.Parent
if shopFrame.Name ~= "ShopFrame" then
	shopFrame = shopFrame:FindFirstChild("ShopFrame", true)
end

if not shopFrame then
	warn("[CheckAdsOnShopOpen] Could not find ShopFrame!")
	return
end

-- Function to check ad availability
local function checkAllAds()
	print("[CheckAdsOnShopOpen] Checking ad availability...")
	
	local success, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)
	
	if success then
		local isAvailable = result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
		print("[CheckAdsOnShopOpen] Rewarded ads available:", isAvailable)
		if not isAvailable then
			print("[CheckAdsOnShopOpen] Reason:", result.AdAvailabilityResult)
		end
	else
		warn("[CheckAdsOnShopOpen] Failed to check ad availability:", result)
	end
end

-- Check ads when shop becomes visible
shopFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if shopFrame.Visible then
		print("[CheckAdsOnShopOpen] Shop opened, checking ads...")
		checkAllAds()
	end
end)

-- Initial check if shop is already visible
if shopFrame.Visible then
	checkAllAds()
end

print("[CheckAdsOnShopOpen] Initialized - will check ads when shop opens")
