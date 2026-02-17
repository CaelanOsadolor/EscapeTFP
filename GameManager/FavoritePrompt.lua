-- FavoritePrompt.lua
-- Server-side script that prompts players to favorite the game once per player (ever)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FavoritePromptStore = DataStoreService:GetDataStore("FavoritePrompts_V1")

local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local showFavoritePrompt = remoteEventsFolder:WaitForChild("ShowFavoritePrompt")

local function promptFavorite(player)
	local userId = "Player_" .. player.UserId
	
	-- Check if already prompted before
	local hasBeenPrompted = false
	local success, result = pcall(function()
		return FavoritePromptStore:GetAsync(userId)
	end)
	
	if success and result == true then
		print(player.Name .. " has already been prompted before - skipping")
		return
	end
	
	-- Show the prompt
	showFavoritePrompt:FireClient(player)
	print("Showing favorite prompt to: " .. player.Name .. " (first time)")
	
	-- Mark as prompted (fire and forget)
	task.spawn(function()
		pcall(function()
			FavoritePromptStore:SetAsync(userId, true)
		end)
	end)
end

Players.PlayerAdded:Connect(function(player)
	task.wait(2)

	-- Random delay between 60-120 seconds before showing prompt
	local randomDelay = math.random(5, 10)
	task.wait(randomDelay)

	if player.Parent then
		promptFavorite(player)
	end
end)

print("FavoritePrompt system loaded")
