-- EventNotificationPrompt.lua
-- Server-side script that prompts players to subscribe to your event until they accept

local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventPromptStore = DataStoreService:GetDataStore("EventNotificationPrompts_V2") -- V2 to track acceptance

local Event_ID = "7241949306242728593" -- Your event ID

local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local showEventPrompt = remoteEventsFolder:WaitForChild("ShowEventPrompt")

-- Create RemoteEvent for acceptance confirmation
local eventAcceptedEvent = remoteEventsFolder:FindFirstChild("EventAccepted")
if not eventAcceptedEvent then
	eventAcceptedEvent = Instance.new("RemoteEvent")
	eventAcceptedEvent.Name = "EventAccepted"
	eventAcceptedEvent.Parent = remoteEventsFolder
end

local function promptEventNotification(player)
	local userId = "Player_" .. player.UserId
	
	-- Check if they've already accepted the event
	local hasAccepted = false
	local success, result = pcall(function()
		return EventPromptStore:GetAsync(userId)
	end)
	
	if success and result == Event_ID then
		print(player.Name .. " has already accepted event " .. Event_ID .. " - skipping")
		return
	end
	
	-- Show the prompt
	showEventPrompt:FireClient(player, Event_ID)
	print("Showing event notification prompt to: " .. player.Name)
end

-- Listen for when player accepts the event
eventAcceptedEvent.OnServerEvent:Connect(function(player, eventId)
	if eventId == Event_ID then
		local userId = "Player_" .. player.UserId
		
		-- Save that they accepted this specific event
		task.spawn(function()
			local success = pcall(function()
				EventPromptStore:SetAsync(userId, Event_ID)
			end)
			if success then
				print(player.Name .. " accepted event notification - won't be prompted again")
			end
		end)
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.wait(2)

	-- Random delay between 11-15 seconds before showing prompt
	local randomDelay = math.random(11, 15)
	task.wait(randomDelay)

	if player.Parent then
		promptEventNotification(player)
	end
end)

print("Event Notification Prompt system loaded")
