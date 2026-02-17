-- RewardedAdsHandler.lua
-- Handles rewarded video ads for 2x Money and 2x Speed boosts
-- Place in ServerScriptService/Monetization folder

local AdService = game:GetService("AdService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Get GamepassManager for boost handling
local GamepassManager = require(ServerScriptService.GameManager.GamepassManager)

-- Get notification event
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local notificationEvent = remoteEventsFolder:WaitForChild("Notification")
local playSoundEvent = remoteEventsFolder:WaitForChild("PlaySoundEvent")

-- Create ShowAdFunction for clients to request ads
local showAdFunction = remoteEventsFolder:FindFirstChild("ShowAdFunction")
if not showAdFunction then
	showAdFunction = Instance.new("RemoteFunction")
	showAdFunction.Name = "ShowAdFunction"
	showAdFunction.Parent = remoteEventsFolder
end

-- Dev Product IDs for ad rewards
local DEV_PRODUCT_IDS = {
	Speed = 3534035402, -- 2x Speed boost dev product
	Money = 3534035119  -- 2x Money boost dev product
}

-- Store ad rewards
local adRewards = {}

-- Ad queue system to prevent multiple ads playing simultaneously
local currentlyShowingAd = false
local adQueue = {}

-- Create ad rewards on server startup
local function createAdRewards()
	for boostType, productId in pairs(DEV_PRODUCT_IDS) do
		local success, result = pcall(function()
			return AdService:CreateAdRewardFromDevProductId(productId)
		end)
		
		if success then
			adRewards[boostType] = result
			print("[RewardedAds] Created ad reward for", boostType)
		else
			warn("[RewardedAds] Failed to create ad reward for", boostType, ":", result)
		end
	end
end

-- Create rewards on startup
createAdRewards()

-- Handle client requests to show ads
showAdFunction.OnServerInvoke = function(player, boostType, productId)
	print("[RewardedAds] Player", player.Name, "requesting to show ad for", boostType)
	
	-- Check if an ad is already playing
	if currentlyShowingAd then
		warn("[RewardedAds] Ad already playing, please wait")
		return "Ad already playing, please wait a moment"
	end
	
	-- Get the ad reward for this boost type
	local adReward = adRewards[boostType]
	if not adReward then
		warn("[RewardedAds] No ad reward found for", boostType)
		return "No ad reward available"
	end
	
	-- Mark that an ad is playing
	currentlyShowingAd = true
	
	-- Show the ad on the server
	local showSuccess, showResult = pcall(function()
		return AdService:ShowRewardedVideoAdAsync(player, adReward)
	end)
	
	-- Clear the ad playing flag after a short delay
	task.delay(2, function()
		currentlyShowingAd = false
	end)
	
	if showSuccess then
		-- Convert result to string for safe comparison
		local resultString = tostring(showResult)
		print("[RewardedAds] Ad result for", player.Name, ":", resultString)
		
		-- Check if player watched the ad (result contains "Watched")
		if resultString:find("Watched") then
			print("[RewardedAds] Player", player.Name, "watched ad for", boostType)
			-- Grant the boost
			grantBoost(player, boostType)
			return "Ad watched successfully!"
		else
			print("[RewardedAds] Player", player.Name, "did not complete ad:", resultString)
			return "Ad not completed"
		end
	else
		warn("[RewardedAds] Failed to show ad:", showResult)
		return "Failed to show ad: " .. tostring(showResult)
	end
end

-- Function to grant boost (extracted from previous OnServerEvent handler)
local function grantBoost(player, boostType)
	if boostType == "Speed" then
		-- Grant 10-minute 2x Speed boost
		local hasSpeed2x = player:GetAttribute("HasSpeed2x")
		
		-- Don't grant if they already have permanent speed gamepass
		if hasSpeed2x then
			notificationEvent:FireClient(player, "You already have permanent 2x Speed!", false)
			return
		end
		
		local endTime = os.time() + 600 -- 10 minutes
		player:SetAttribute("Boost2xSpeedEndTime", endTime)
		
		-- Immediately update character walk speed
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = GamepassManager.GetActualWalkSpeed(player)
			end
		end
		
		notificationEvent:FireClient(player, "⚡ 2x Speed activated for 10 minutes! (FREE)", true)
		playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
		
		print("[RewardedAds] Granted 2x Speed boost to", player.Name)
		
	elseif boostType == "Money" then
		-- Grant 10-minute 2x Money boost
		local endTime = os.time() + 600 -- 10 minutes
		player:SetAttribute("Boost2xMoneyEndTime", endTime)
		
		-- Immediately update RebirthMultiplier
		local newMultiplier = GamepassManager.GetMoneyMultiplier(player)
		player:SetAttribute("RebirthMultiplier", newMultiplier)
		
		notificationEvent:FireClient(player, "💰 2x Money activated for 10 minutes! (FREE)", true)
		playSoundEvent:FireClient(player, "PurchaseSuccess", 0.5, nil, nil)
		
		print("[RewardedAds] Granted 2x Money boost to", player.Name)
		
	else
		warn("[RewardedAds] Unknown boost type:", boostType)
	end
end

print("[RewardedAds] Handler initialized")
print("[RewardedAds] Ready to show ads for players")
