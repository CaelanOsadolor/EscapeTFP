-- ThingSystemHandler.lua
-- Main handler that initializes all thing systems
-- Place in: ServerScriptService/Things/

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ThingSystemHandler = {}

-- Import all managers from the Things folder
local ThingSpawner = require(script.Parent:WaitForChild("ThingSpawner"))
local ThingCarryManager = require(script.Parent:WaitForChild("ThingCarryManager"))
local BaseSlotManager = require(script.Parent:WaitForChild("BaseSlotManager"))
local ThingValueManager = require(script.Parent:WaitForChild("ThingValueManager"))

-- Remote events
local pickupEvent
local placeEvent
local dropEvent
local getThingInfoFunc

-- Initialize all systems
function ThingSystemHandler.Init()

	-- Initialize all managers
	ThingSpawner.Init()
	ThingCarryManager.Init()
	BaseSlotManager.Init()
	ThingValueManager.Init()
	
	-- Setup remote events
	ThingSystemHandler.SetupRemotes()
	
	print("========================================")
	print("[ThingSystemHandler] Thing System initialized!")
	print("FEATURES ENABLED:")
	print("✅ Thing spawning on floors")
	print("✅ Pick up things (E key)")
	print("✅ Carry things (capacity-based)")
	print("✅ Place things in base slots")
	print("✅ Passive income from placed things")
	print("✅ Each thing has unique value!")
	print("⏳ Sell NPC (coming later)")
	print("========================================")
end

-- Setup remote events
function ThingSystemHandler.SetupRemotes()
	-- Pickup thing event
	pickupEvent = ReplicatedStorage:FindFirstChild("PickupThing")
	if not pickupEvent then
		pickupEvent = Instance.new("RemoteEvent")
		pickupEvent.Name = "PickupThing"
		pickupEvent.Parent = ReplicatedStorage
	end
	
	pickupEvent.OnServerEvent:Connect(function(player, thing)
		if not thing or not thing:IsDescendantOf(workspace) then return end
		
		local success, message = ThingCarryManager.PickupThing(player, thing)
		
		if not success then
			-- Send error notification
			ThingSystemHandler.SendNotification(player, "Cannot Pick Up", message)
		else
			local info = ThingValueManager.GetThingInfo(thing)
			ThingSystemHandler.SendNotification(player, "Picked Up!", info.Name .. " (" .. info.PassiveValue .. ")")
		end
	end)
	
	-- Place thing event
	placeEvent = ReplicatedStorage:FindFirstChild("PlaceThing")
	if not placeEvent then
		placeEvent = Instance.new("RemoteEvent")
		placeEvent.Name = "PlaceThing"
		placeEvent.Parent = ReplicatedStorage
	end
	
	placeEvent.OnServerEvent:Connect(function(player, slot)
		if not slot or not slot:IsDescendantOf(workspace) then return end
		
		-- Get first carried thing
		local carriedThings = ThingCarryManager.GetCarriedThings(player)
		if #carriedThings == 0 then
			ThingSystemHandler.SendNotification(player, "No Things", "You need to carry a thing to place it")
			return
		end
		
		local thing = carriedThings[1]
		
		-- Drop it first
		ThingCarryManager.DropThing(player, thing)
		
		-- Place in slot
		local success, message = BaseSlotManager.PlaceThing(player, thing, slot)
		
		if not success then
			ThingSystemHandler.SendNotification(player, "Cannot Place", message)
		else
			local info = ThingValueManager.GetThingInfo(thing)
			ThingSystemHandler.SendNotification(player, "Placed!", info.Name .. " - Earning " .. info.PassiveValue)
		end
	end)
	
	-- Drop thing event
	dropEvent = ReplicatedStorage:FindFirstChild("DropThing")
	if not dropEvent then
		dropEvent = Instance.new("RemoteEvent")
		dropEvent.Name = "DropThing"
		dropEvent.Parent = ReplicatedStorage
	end
	
	dropEvent.OnServerEvent:Connect(function(player)
		ThingCarryManager.DropCarriedThings(player)
		ThingSystemHandler.SendNotification(player, "Dropped", "Dropped all things")
	end)
	
	-- Get thing info function
	getThingInfoFunc = ReplicatedStorage:FindFirstChild("GetThingInfo")
	if not getThingInfoFunc then
		getThingInfoFunc = Instance.new("RemoteFunction")
		getThingInfoFunc.Name = "GetThingInfo"
		getThingInfoFunc.Parent = ReplicatedStorage
	end
	
	getThingInfoFunc.OnServerInvoke = function(player, thing)
		if not thing or not thing:IsDescendantOf(workspace) then return nil end
		return ThingValueManager.GetThingInfo(thing)
	end
	
	print("[ThingSystemHandler] Remote events setup complete")
end

-- Send notification to player
function ThingSystemHandler.SendNotification(player, title, message)
	local notificationEvent = ReplicatedStorage:FindFirstChild("SendNotification")
	
	if notificationEvent then
		notificationEvent:FireClient(player, {
			Title = title,
			Message = message,
			Duration = 2
		})
	end
	-- Removed fallback print to reduce console spam
end

return ThingSystemHandler
