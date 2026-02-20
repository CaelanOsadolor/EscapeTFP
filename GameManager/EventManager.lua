-- EventManager.lua
-- Manages timed events (Night Event and Love Event)
-- Events cycle every 30 minutes, last for 5 minutes each
-- Place in: ServerScriptService/GameManager/

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")

local EventManager = {}

-- Configuration
local EVENT_CYCLE_TIME = 1800 -- 30 minutes between events (1800 seconds)
local EVENT_DURATION = 300 -- 5 minutes per event (300 seconds)
local MESSAGING_TOPIC = "GlobalEventControl" -- Topic for cross-server communication

-- Track global event countdown task
local globalEventCountdownTask = nil

-- Event types
local EVENT_TYPES = {"Night", "Love"}
local currentEventIndex = 0
local activeEvent = nil -- Stores current active event info: {Type = "Night", StartTime = os.time()}
local pauseTimerUpdates = false -- Flag to pause automatic timer updates when admin controls events

-- Sky textures (hardcoded from your Lighting Sky objects)
local skyTextures = {
	Main = {
		SkyboxBk = "rbxassetid://6444884337",
		SkyboxDn = "rbxassetid://6444884785",
		SkyboxFt = "rbxassetid://6444884337",
		SkyboxLf = "rbxassetid://6444884337",
		SkyboxRt = "rbxassetid://6444884337",
		SkyboxUp = "rbxassetid://6412503613",
		CelestialBodiesShown = true,
		StarCount = 3000,
		SunAngularSize = 30,
		MoonAngularSize = 11,
		SunTextureId = "rbxasset://sky/sun.jpg"
	},
	Night = {
		SkyboxBk = "http://www.roblox.com/asset/?id=12064107",
		SkyboxDn = "http://www.roblox.com/asset/?id=12064152",
		SkyboxFt = "http://www.roblox.com/asset/?id=12064121",
		SkyboxLf = "http://www.roblox.com/asset/?id=12063984",
		SkyboxRt = "http://www.roblox.com/asset/?id=12064115",
		SkyboxUp = "http://www.roblox.com/asset/?id=12064131",
		CelestialBodiesShown = true,
		StarCount = 0,
		SunAngularSize = 21,
		MoonAngularSize = 11,
		SunTextureId = "rbxasset://sky/sun.jpg"
	},
	Love = {
		SkyboxBk = "http://www.roblox.com/asset/?id=271042516",
		SkyboxDn = "http://www.roblox.com/asset/?id=271077243",
		SkyboxFt = "http://www.roblox.com/asset/?id=271042556",
		SkyboxLf = "http://www.roblox.com/asset/?id=271042310",
		SkyboxRt = "http://www.roblox.com/asset/?id=271042467",
		SkyboxUp = "http://www.roblox.com/asset/?id=271077958",
		CelestialBodiesShown = true,
		StarCount = 1334,
		SunAngularSize = 21,
		MoonAngularSize = 11,
		SunTextureId = "rbxasset://sky/sun.jpg"
	}
}
local activeSky = nil -- Reference to the single Sky object in Lighting

-- Initialize
function EventManager.Init()
	print("[EventManager] Initializing event system...")

	-- Find existing Sky objects in Lighting
	EventManager.FindSkyObjects()

	-- Create RemoteEvent for client notifications
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEventsFolder then
		remoteEventsFolder = Instance.new("Folder")
		remoteEventsFolder.Name = "RemoteEvents"
		remoteEventsFolder.Parent = ReplicatedStorage
	end

	local eventNotification = remoteEventsFolder:FindFirstChild("EventNotification")
	if not eventNotification then
		eventNotification = Instance.new("RemoteEvent")
		eventNotification.Name = "EventNotification"
		eventNotification.Parent = remoteEventsFolder
	end

	-- Create StringValue in ReplicatedStorage to track active event
	local activeEventValue = ReplicatedStorage:FindFirstChild("ActiveEvent")
	if not activeEventValue then
		activeEventValue = Instance.new("StringValue")
		activeEventValue.Name = "ActiveEvent"
		activeEventValue.Value = "None"
		activeEventValue.Parent = ReplicatedStorage
	end

	-- Create EventTimerUpdate BindableEvent in RemoteEvents folder
	local eventTimerBindable = remoteEventsFolder:FindFirstChild("EventTimerUpdate")
	if not eventTimerBindable then
		eventTimerBindable = Instance.new("BindableEvent")
		eventTimerBindable.Name = "EventTimerUpdate"
		eventTimerBindable.Parent = remoteEventsFolder
		print("[EventManager] Created EventTimerUpdate BindableEvent")
	end

	-- Subscribe to global event commands (cross-server)
	local success, connection = pcall(function()
		return MessagingService:SubscribeAsync(MESSAGING_TOPIC, function(message)
			local data = message.Data
			if data.Command == "StartEvent" then
				print("[EventManager] Received global start event command:", data.EventType)

				-- Cancel any existing global countdown
				if globalEventCountdownTask then
					task.cancel(globalEventCountdownTask)
					globalEventCountdownTask = nil
				end

				-- Pause automatic updates and start the event
				EventManager.PauseTimerUpdates()
				EventManager.StartEvent(data.EventType)

				-- Start countdown loop with timer updates (5 minutes)
				local eventTimerBindable = remoteEventsFolder and remoteEventsFolder:FindFirstChild("EventTimerUpdate")
				if eventTimerBindable then
					globalEventCountdownTask = task.spawn(function()
						for timeRemaining = EVENT_DURATION, 0, -1 do
							eventTimerBindable:Fire(data.EventType, timeRemaining)
							if timeRemaining > 0 then
								task.wait(1)
							end
						end

						-- Event finished, end it
						EventManager.EndEvent()

						-- Start 30-minute "Next Event In" countdown
						for timeRemaining = EVENT_CYCLE_TIME, 0, -1 do
							eventTimerBindable:Fire(nil, timeRemaining)
							if timeRemaining > 0 then
								task.wait(1)
							end
						end

						-- Resume automatic cycle
						EventManager.ResumeTimerUpdates()
						globalEventCountdownTask = nil
					end)
				end

			elseif data.Command == "EndEvent" then
				print("[EventManager] Received global end event command")

				-- Cancel any global countdown
				if globalEventCountdownTask then
					task.cancel(globalEventCountdownTask)
					globalEventCountdownTask = nil
				end

				EventManager.EndEvent()

				-- Start 30-minute "Next Event In" countdown
				local eventTimerBindable = remoteEventsFolder and remoteEventsFolder:FindFirstChild("EventTimerUpdate")
				if eventTimerBindable then
					globalEventCountdownTask = task.spawn(function()
						for timeRemaining = EVENT_CYCLE_TIME, 0, -1 do
							eventTimerBindable:Fire(nil, timeRemaining)
							if timeRemaining > 0 then
								task.wait(1)
							end
						end

						-- Resume automatic cycle
						EventManager.ResumeTimerUpdates()
						globalEventCountdownTask = nil
					end)
				end
			end
		end)
	end)

	if success then
		print("[EventManager] Subscribed to global event commands")
	else
		warn("[EventManager] Failed to subscribe to MessagingService:", connection)
	end

	-- Start event cycle
	task.spawn(function()
		EventManager.EventCycle()
	end)

	print("[EventManager] Event system started!")
end

-- Find existing Sky objects in Lighting (don't destroy template Skys)
function EventManager.FindSkyObjects()
	-- Find the Main Sky object to use as the active sky
	activeSky = Lighting:FindFirstChild("Main")

	if not activeSky or not activeSky:IsA("Sky") then
		-- If Main doesn't exist, find any Sky or create one
		activeSky = Lighting:FindFirstChildOfClass("Sky")
		if not activeSky then
			activeSky = Instance.new("Sky")
			activeSky.Name = "Sky"
			activeSky.Parent = Lighting
			print("[EventManager] Created new Sky object")
		end
	end

	print("[EventManager] Using Sky:", activeSky.Name)

	-- Apply Main sky by default
	EventManager.ApplySkyTextures("Main")
end

-- Apply textures from a sky type to the active Sky object
function EventManager.ApplySkyTextures(skyType)
	if not activeSky then
		warn("[EventManager] No active Sky object!")
		return
	end

	local textures = skyTextures[skyType]
	if not textures then
		warn("[EventManager] No textures found for sky type:", skyType)
		return
	end

	-- Apply all textures
	activeSky.SkyboxBk = textures.SkyboxBk or ""
	activeSky.SkyboxDn = textures.SkyboxDn or ""
	activeSky.SkyboxFt = textures.SkyboxFt or ""
	activeSky.SkyboxLf = textures.SkyboxLf or ""
	activeSky.SkyboxRt = textures.SkyboxRt or ""
	activeSky.SkyboxUp = textures.SkyboxUp or ""
	activeSky.CelestialBodiesShown = textures.CelestialBodiesShown
	activeSky.StarCount = textures.StarCount or 3000
	activeSky.SunAngularSize = textures.SunAngularSize or 21
	activeSky.MoonAngularSize = textures.MoonAngularSize or 11
	activeSky.SunTextureId = textures.SunTextureId or "rbxasset://sky/sun.jpg"

	print("[EventManager] Applied " .. skyType .. " sky textures")
end

-- Main event cycle loop
function EventManager.EventCycle()
	while true do
		-- Wait 30 minutes between events with countdown
		print("[EventManager] Waiting 30 minutes until next event...")

		local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		local eventTimerBindable = remoteEventsFolder and remoteEventsFolder:FindFirstChild("EventTimerUpdate")

		-- Countdown from 30 minutes to 0
		for timeRemaining = EVENT_CYCLE_TIME, 0, -1 do
			-- Update timer display (nil event type means "Next Event In") - only if not paused by admin
			if eventTimerBindable and not pauseTimerUpdates then
				eventTimerBindable:Fire(nil, timeRemaining)
			end

			-- Wait 1 second (except on last iteration)
			if timeRemaining > 0 then
				task.wait(1)
			end
		end

		-- Pick next event (alternate between Night and Love)
		currentEventIndex = currentEventIndex + 1
		if currentEventIndex > #EVENT_TYPES then
			currentEventIndex = 1
		end

		local eventType = EVENT_TYPES[currentEventIndex]

		-- Start the event
		EventManager.StartEvent(eventType)

		-- Countdown timer for event duration (5 minutes)
		eventTimerBindable = remoteEventsFolder and remoteEventsFolder:FindFirstChild("EventTimerUpdate")

		for timeRemaining = EVENT_DURATION, 0, -1 do
			-- Update timer display - only if not paused by admin
			if eventTimerBindable and not pauseTimerUpdates then
				eventTimerBindable:Fire(eventType, timeRemaining)
			end

			-- Wait 1 second (except on last iteration)
			if timeRemaining > 0 then
				task.wait(1)
			end
		end

		-- End the event
		EventManager.EndEvent()
	end
end

-- Start an event
function EventManager.StartEvent(eventType)
	print("[EventManager] Starting " .. eventType .. " Event!")

	-- Set active event
	activeEvent = {
		Type = eventType,
		StartTime = os.time()
	}

	-- Update ReplicatedStorage value
	local activeEventValue = ReplicatedStorage:FindFirstChild("ActiveEvent")
	if activeEventValue then
		activeEventValue.Value = eventType
	end

	-- Change sky
	EventManager.ApplySky(eventType)

	-- Send notification to all players
	EventManager.NotifyPlayers(eventType, "start")
end

-- End the current event
function EventManager.EndEvent()
	if not activeEvent then return end

	print("[EventManager] Ending " .. activeEvent.Type .. " Event!")

	-- Send end notification
	EventManager.NotifyPlayers(activeEvent.Type, "end")

	-- Clear active event
	activeEvent = nil

	-- Update ReplicatedStorage value
	local activeEventValue = ReplicatedStorage:FindFirstChild("ActiveEvent")
	if activeEventValue then
		activeEventValue.Value = "None"
	end

	-- Restore original sky
	EventManager.RestoreSky()

	-- Timer will automatically continue with "Next Event In" countdown in the main loop
end

-- Apply event sky
function EventManager.ApplySky(eventType)
	if eventType == "Night" then
		EventManager.ApplySkyTextures("Night")
	elseif eventType == "Love" then
		EventManager.ApplySkyTextures("Love")
	else
		warn("[EventManager] Unknown event type:", eventType)
	end
end

-- Restore original sky
function EventManager.RestoreSky()
	EventManager.ApplySkyTextures("Main")
end

-- Notify all players about event
function EventManager.NotifyPlayers(eventType, action)
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEventsFolder then return end

	local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
	local playSoundEvent = remoteEventsFolder:FindFirstChild("PlaySoundEvent")

	if not notificationEvent then return end

	local message = ""
	local color = Color3.fromRGB(255, 255, 255)
	local duration = 5

	if action == "start" then
		if eventType == "Night" then
			message = "NIGHT EVENT STARTED! Things can spawn with Night mutation (2x value)!"
			color = Color3.fromRGB(100, 100, 255) -- Dark blue
		elseif eventType == "Love" then
			message = "LOVE EVENT STARTED! Things can spawn with Love mutation (3x value)!"
			color = Color3.fromRGB(255, 100, 200) -- Pink
		end
	elseif action == "end" then
		message = eventType .. " Event has ended!"
		color = Color3.fromRGB(200, 200, 200) -- Gray
		duration = 3
	end

	-- Send to all players
	-- Notification format: Text, Polarity (nil for custom color), CustomColor, CustomDuration
	for _, player in Players:GetPlayers() do
		notificationEvent:FireClient(player, message, nil, color, duration)

		-- Play notification sound (volume, playbackSpeed, parent)
		if playSoundEvent then
			playSoundEvent:FireClient(player, "ClaimSound", 0.7, 1, nil)
		end
	end
end

-- Get current active event (returns nil if no event active)
function EventManager.GetActiveEvent()
	return activeEvent
end

-- Check if a specific event is active
function EventManager.IsEventActive(eventType)
	return activeEvent and activeEvent.Type == eventType
end

-- Check if ANY event is active
function EventManager.IsAnyEventActive()
	return activeEvent ~= nil
end

-- Get event mutation for spawning (returns mutation name or nil)
function EventManager.GetEventMutation()
	if not activeEvent then return nil end

	-- Return the mutation name based on event type
	if activeEvent.Type == "Night" then
		return "Night"
	elseif activeEvent.Type == "Love" then
		return "Love"
	end

	return nil
end

-- Pause automatic timer updates (for admin manual control)
function EventManager.PauseTimerUpdates()
	pauseTimerUpdates = true
	print("[EventManager] Paused automatic timer updates")
end

-- Resume automatic timer updates
function EventManager.ResumeTimerUpdates()
	pauseTimerUpdates = false
	print("[EventManager] Resumed automatic timer updates")
end

-- Publish global event start command (affects ALL servers)
function EventManager.PublishGlobalStartEvent(eventType)
	local success, err = pcall(function()
		MessagingService:PublishAsync(MESSAGING_TOPIC, {
			Command = "StartEvent",
			EventType = eventType,
			Timestamp = os.time()
		})
	end)

	if success then
		print("[EventManager] Published global start event command:", eventType)
	else
		warn("[EventManager] Failed to publish start event:", err)
	end

	return success
end

-- Publish global event end command (affects ALL servers)
function EventManager.PublishGlobalEndEvent()
	local success, err = pcall(function()
		MessagingService:PublishAsync(MESSAGING_TOPIC, {
			Command = "EndEvent",
			Timestamp = os.time()
		})
	end)

	if success then
		print("[EventManager] Published global end event command")
	else
		warn("[EventManager] Failed to publish end event:", err)
	end

	return success
end

return EventManager