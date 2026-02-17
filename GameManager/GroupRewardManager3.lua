-- GroupRewardManager3.lua (Game 3)
-- Handles group rewards (100k + random mythical)
-- Place in: ServerScriptService/GameManager/

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local SaveManager = require(script.Parent.SaveManager)
local ThingInventoryManager = require(ServerScriptService.Things.ThingInventoryManager)
local ThingValueManager = require(ServerScriptService.Things.ThingValueManager)

local GroupRewardManager = {}

-- Configuration
local GROUP_ID = 291288143
local CASH_REWARD = 100000 -- 100k
local COOLDOWN_SECONDS = 3600 -- 1 hour (3600 seconds)
local MYTHICAL_THINGS = {
	"Celebrity",
	"Chubby",
	"Ruby",
	"Seal"
}

-- Create RemoteEvent
local remoteEvent = Instance.new("RemoteEvent")
remoteEvent.Name = "GroupRewardClaim"
remoteEvent.Parent = ReplicatedStorage

-- Get time remaining until next claim (returns seconds, 0 if ready)
local function GetTimeRemaining(player)
	local data = SaveManager:LoadData(player)
	local lastClaim = data.LastGroupClaimTime or 0
	
	if lastClaim == 0 then
		return 0 -- Never claimed, ready now
	end
	
	local currentTime = os.time()
	local timePassed = currentTime - lastClaim
	local timeRemaining = COOLDOWN_SECONDS - timePassed
	
	if timeRemaining <= 0 then
		return 0 -- Cooldown finished
	end
	
	return math.ceil(timeRemaining)
end

-- Save claim timestamp
local function SaveClaimTime(player)
	local data = SaveManager:LoadData(player)
	data.LastGroupClaimTime = os.time()
	SaveManager:SaveData(player, data)
end

-- Handle claim request
remoteEvent.OnServerEvent:Connect(function(player, action)
	-- Handle timer check request
	if action == "CheckTimer" then
		local timeRemaining = GetTimeRemaining(player)
		remoteEvent:FireClient(player, "UpdateTimer", timeRemaining)
		return
	end
	
	-- Check cooldown
	local timeRemaining = GetTimeRemaining(player)
	if timeRemaining > 0 then
		-- Still on cooldown
		remoteEvent:FireClient(player, "UpdateTimer", timeRemaining)
		return
	end
	
	-- Give 100k cash
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local money = leaderstats:FindFirstChild("Money")
		if money then
			print("[GroupRewardManager3:81] Adding group reward:", CASH_REWARD, "| Current:", money.Value, "| New:", money.Value + CASH_REWARD)
			money.Value = money.Value + CASH_REWARD
		end
	end
	
	-- Give random mythical
	local randomMythical = MYTHICAL_THINGS[math.random(1, #MYTHICAL_THINGS)]
	local rarity = "Mythical"
	local mutation = "" -- No mutation
	local rate = ThingValueManager.GetThingValueByName(randomMythical, rarity)
	local upgradeLevel = 0
	
	ThingInventoryManager.AddToInventory(player, randomMythical, mutation, rarity, rate, {}, upgradeLevel)
	
	-- Save claim timestamp
	SaveClaimTime(player)
	
	-- Send notification
	local notificationRemote = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if notificationRemote then
		local notification = notificationRemote:FindFirstChild("Notification")
		if notification then
			notification:FireClient(player, "Group reward claimed! +$100K + " .. randomMythical, true)
		end
	end
	
	-- Play claim sound
	local playSoundEvent = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if playSoundEvent then
		local soundEvent = playSoundEvent:FindFirstChild("PlaySoundEvent")
		if soundEvent then
			soundEvent:FireClient(player, "ClaimSound", 0.2, nil, nil)
		end
	end
	
	-- Send timer update (start 1 hour cooldown)
	remoteEvent:FireClient(player, "UpdateTimer", COOLDOWN_SECONDS)
end)

-- Send timer on join
Players.PlayerAdded:Connect(function(player)
	-- Send multiple times to ensure client receives it
	for i = 1, 3 do
		task.wait(0.5 * i) -- 0.5s, 1s, 1.5s
		local timeRemaining = GetTimeRemaining(player)
		remoteEvent:FireClient(player, "UpdateTimer", timeRemaining)
	end
end)

function GroupRewardManager.Init()
end

return GroupRewardManager
