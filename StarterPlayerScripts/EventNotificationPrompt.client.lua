local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local SocialService = game:GetService("SocialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local showEventPrompt = remoteEventsFolder:WaitForChild("ShowEventPrompt")
local eventAcceptedEvent = remoteEventsFolder:WaitForChild("EventAccepted")

showEventPrompt.OnClientEvent:Connect(function(eventId)
	if Player and eventId then
		-- Prompt the player to RSVP to the event
		local success, rsvpStatus = pcall(function()
			return SocialService:PromptRsvpToEventAsync(eventId)
		end)
		
		if success then
			print("Event RSVP prompt shown successfully, status:", rsvpStatus)
			
			-- Save if they clicked anything except "Not Going" or dismissed (None)
			-- This catches: Going, Interested, or any "Notify Me" action
			if rsvpStatus ~= Enum.RsvpStatus.None and rsvpStatus ~= Enum.RsvpStatus.NotGoing then
				print("Player accepted event notification!")
				-- Tell server they accepted so we won't prompt them again
				eventAcceptedEvent:FireServer(eventId)
			else
				print("Player declined or dismissed event notification")
			end
		else
			warn("RSVP Failed:", rsvpStatus)
		end
	end
end)
