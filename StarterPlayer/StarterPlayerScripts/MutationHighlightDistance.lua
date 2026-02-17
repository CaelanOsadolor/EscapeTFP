-- MutationHighlightDistance.lua
-- Client-side script to fade mutation highlights based on distance

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local FADE_START_DISTANCE = 30 -- Start fading at 30 studs
local FADE_END_DISTANCE = 45 -- Fully transparent at 45 studs

-- Store original transparency values for each highlight
local highlightData = {}

-- Function to update highlight transparency based on distance
local function updateHighlightTransparency(highlight, distance)
	if not highlightData[highlight] then
		-- Store original transparency values
		highlightData[highlight] = {
			OriginalFillTransparency = highlight.FillTransparency,
			OriginalOutlineTransparency = highlight.OutlineTransparency
		}
	end
	
	local data = highlightData[highlight]
	
	if distance <= FADE_START_DISTANCE then
		-- Close enough - use original transparency
		highlight.FillTransparency = data.OriginalFillTransparency
		highlight.OutlineTransparency = data.OriginalOutlineTransparency
	elseif distance >= FADE_END_DISTANCE then
		-- Too far - fully transparent (invisible)
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 1
	else
		-- In fade range - interpolate
		local fadeAlpha = (distance - FADE_START_DISTANCE) / (FADE_END_DISTANCE - FADE_START_DISTANCE)
		highlight.FillTransparency = data.OriginalFillTransparency + (1 - data.OriginalFillTransparency) * fadeAlpha
		highlight.OutlineTransparency = data.OriginalOutlineTransparency + (1 - data.OriginalOutlineTransparency) * fadeAlpha
	end
end

-- Function to get character root position
local function getCharacterPosition()
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			return rootPart.Position
		end
	end
	return nil
end

-- Function to find all mutation highlights in workspace
local function getAllMutationHighlights()
	local highlights = {}
	
	-- Search in player bases (placed things)
	local bases = Workspace:FindFirstChild("Bases")
	if bases then
		for _, highlight in ipairs(bases:GetDescendants()) do
			if highlight:IsA("Highlight") and highlight.Name == "MutationHighlight" then
				table.insert(highlights, highlight)
			end
		end
	end
	
	-- Search in ActiveThings folder (spawned things from ThingSpawner)
	local activeThings = Workspace:FindFirstChild("ActiveThings")
	if activeThings then
		for _, highlight in ipairs(activeThings:GetDescendants()) do
			if highlight:IsA("Highlight") and highlight.Name == "MutationHighlight" then
				table.insert(highlights, highlight)
			end
		end
	end
	
	-- Search in RobuxiPhone folder (Gold iPhone 16 Pro display)
	local robuxiPhone = Workspace:FindFirstChild("RobuxiPhone")
	if robuxiPhone then
		for _, highlight in ipairs(robuxiPhone:GetDescendants()) do
			if highlight:IsA("Highlight") and highlight.Name == "MutationHighlight" then
				table.insert(highlights, highlight)
			end
		end
	end
	
	-- Search in character models (carried things)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			for _, highlight in ipairs(plr.Character:GetDescendants()) do
				if highlight:IsA("Highlight") and highlight.Name == "MutationHighlight" then
					table.insert(highlights, highlight)
				end
			end
		end
	end
	
	return highlights
end

-- Update loop
RunService.RenderStepped:Connect(function()
	local playerPos = getCharacterPosition()
	if not playerPos then return end
	
	local highlights = getAllMutationHighlights()
	
	for _, highlight in ipairs(highlights) do
		if highlight and highlight.Parent then
			-- Get position of the thing (highlight's parent model)
			local thing = highlight.Parent
			if thing:IsA("Model") then
				local pivotPos = thing:GetPivot().Position
				local distance = (pivotPos - playerPos).Magnitude
				
				updateHighlightTransparency(highlight, distance)
			end
		else
			-- Highlight was destroyed, clean up data
			highlightData[highlight] = nil
		end
	end
end)
