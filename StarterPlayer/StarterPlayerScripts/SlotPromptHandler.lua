-- SlotPromptHandler.lua (LocalScript)
-- Updates server prompt text based on player ownership (client-side only text change)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local function updateSlotPromptText(slot)
	local baseModel = slot:FindFirstChild("Base")
	if not baseModel then return end

	local placeHolder = baseModel:FindFirstChild("PlaceHolder")
	if not placeHolder then return end

	-- Find server prompt (OwnerPrompt) - wait for it if needed
	local prompt = placeHolder:FindFirstChild("OwnerPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then 
		-- Prompt not ready yet, will update when attributes change
		return 
	end

	-- Get owner ID and occupation status
	local ownerUserId = slot:GetAttribute("OwnerUserId")
	local occupied = slot:GetAttribute("Occupied")

	-- If owner not set yet, don't update (will update when OwnerUserId is set)
	if not ownerUserId then return end

	local isOwner = (player.UserId == ownerUserId)

	-- NEVER show steal for owner - if you're the owner, only show Place/Remove
	if isOwner then
		if occupied then
			prompt.ActionText = "Remove"
		else
			prompt.ActionText = "Place"
		end
		prompt.Enabled = true
	else
		-- Non-owner: show Steal if occupied, otherwise hide prompt completely
		if occupied then
			prompt.ActionText = "Steal"
			prompt.Enabled = true
		else
			prompt.Enabled = false  -- Hide prompt for non-owner empty slots
		end
	end
end

local function setupSlot(slot)
	-- Wait a moment for the prompt to exist
	task.wait(0.1)

	-- Update text immediately
	updateSlotPromptText(slot)

	-- Listen for occupation changes
	slot:GetAttributeChangedSignal("Occupied"):Connect(function()
		updateSlotPromptText(slot)
	end)

	-- Listen for thing name changes (when things are placed)
	slot:GetAttributeChangedSignal("PlacedThingName"):Connect(function()
		updateSlotPromptText(slot)
	end)

	-- Listen for owner changes (when base is reassigned)
	slot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		updateSlotPromptText(slot)
	end)
end

local function setupAllBases()
	-- Wait for Bases folder
	local bases = Workspace:WaitForChild("Bases", 10)
	if not bases then
		warn("[SlotPromptHandler] No Bases folder found")
		return
	end

	-- Setup ALL bases in the workspace (so we can see other players' slots correctly)
	for _, base in ipairs(bases:GetChildren()) do
		if base:IsA("Model") and base.Name:match("^Base%d+") then
			local slotsFolder = base:FindFirstChild("Slots")
			if slotsFolder then
				for _, slot in ipairs(slotsFolder:GetChildren()) do
					if slot:IsA("Model") and slot.Name:match("^Slot") then
						task.spawn(function()
							setupSlot(slot)
						end)
					end
				end
			end
		end
	end

	-- Wait a moment for attributes to replicate, then update all prompts again
	task.wait(1)
	for _, base in ipairs(bases:GetChildren()) do
		if base:IsA("Model") and base.Name:match("^Base%d+") then
			local slotsFolder = base:FindFirstChild("Slots")
			if slotsFolder then
				for _, slot in ipairs(slotsFolder:GetChildren()) do
					if slot:IsA("Model") and slot.Name:match("^Slot") then
						updateSlotPromptText(slot)
					end
				end
			end
		end
	end

	-- Listen for new bases being added
	bases.ChildAdded:Connect(function(base)
		if base:IsA("Model") and base.Name:match("^Base%d+") then
			task.wait(0.5) -- Wait for slots to be created and attributes to replicate
			local slotsFolder = base:FindFirstChild("Slots")
			if slotsFolder then
				for _, slot in ipairs(slotsFolder:GetChildren()) do
					if slot:IsA("Model") and slot.Name:match("^Slot") then
						task.spawn(function()
							setupSlot(slot)
						end)
					end
				end
			end
		end
	end)

	print("[SlotPromptHandler] Setup complete for ALL bases")
end

-- Setup all bases so non-owners see correct text
setupAllBases()

-- Listen for server request to refresh prompts (after LoadPlacedThings)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local refreshPromptsEvent = remoteEventsFolder:WaitForChild("RefreshSlotPrompts")

refreshPromptsEvent.OnClientEvent:Connect(function()
	print("[SlotPromptHandler] Refreshing all slot prompts...")
	
	-- Update all prompts for all bases
	local bases = Workspace:FindFirstChild("Bases")
	if bases then
		for _, base in ipairs(bases:GetChildren()) do
			if base:IsA("Model") and base.Name:match("^Base%d+") then
				local slotsFolder = base:FindFirstChild("Slots")
				if slotsFolder then
					for _, slot in ipairs(slotsFolder:GetChildren()) do
						if slot:IsA("Model") and slot.Name:match("^Slot") then
							updateSlotPromptText(slot)
						end
					end
				end
			end
		end
	end
	
	print("[SlotPromptHandler] Refresh complete")
end)

print("[SlotPromptHandler] Client-side text updater loaded")
