-- Base Upgrade Station Manager
-- Place this in ServerScriptService/GameManager folder

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Get modules
local BaseUpgrade = require(script.Parent.BaseUpgrade)

-- Configuration
local BASES_FOLDER = Workspace:WaitForChild("Bases")
local INTERACTION_DISTANCE = 10

-- Format number with suffixes
local function formatNumber(num)
	local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
	local tier = 1
	
	while num >= 1000 and tier < #suffixes do
		num = num / 1000
		tier = tier + 1
	end
	
	if num >= 100 then
		return string.format("%.0f%s", num, suffixes[tier])
	elseif num >= 10 then
		return string.format("%.1f%s", num, suffixes[tier])
	else
		return string.format("%.2f%s", num, suffixes[tier])
	end
end

-- Update UI for a specific base
local function updateDisplay(upgradeBase, player)
	if not upgradeBase or not player then return end
	
	local sign = upgradeBase:FindFirstChild("Sign")
	if not sign then return end
	
	local surfaceGui = sign:FindFirstChild("SurfaceGui")
	if not surfaceGui then return end
	
	local frame = surfaceGui:FindFirstChild("Frame")
	if not frame then return end
	
	local info = BaseUpgrade:GetUpgradeInfo(player)
	
	-- Update cost label
	local costLabel = frame:FindFirstChild("Cost")
	if costLabel then
		if info.CanUpgrade then
			costLabel.Text = "$" .. info.NextCostFormatted
			costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			costLabel.Text = "MAX"
			costLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
		end
	end
	
	-- Update level display (look for LevelChange or SlotCount)
	local levelLabel = frame:FindFirstChild("LevelChange") or frame:FindFirstChild("SlotCount")
	if levelLabel then
		levelLabel.Text = info.CurrentLevel .. "/20"
	end
end

-- Setup upgrade station for a base
local function setupUpgradeStation(base, baseNumber)
	-- Look for UpgradeBase → Sign
	local upgradeBase = base:FindFirstChild("UpgradeBase")
	if not upgradeBase then
		warn("UpgradeBase not found in", base.Name)
		return
	end
	
	local sign = upgradeBase:FindFirstChild("Sign")
	if not sign then
		warn("Sign not found in UpgradeBase for", base.Name)
		return
	end
	
	print("Setup upgrade station for", base.Name, "on Sign")
	
	-- Note: Click detection is now handled by LocalScript on the ImageButton
	-- This just stores the connection for the RemoteEvent
end

-- Initialize all base upgrade stations
local function initializeAllBases()
	for i = 1, 5 do
		local baseName = "Base" .. i
		local base = BASES_FOLDER:FindFirstChild(baseName)
		
		if base then
			setupUpgradeStation(base, i)
		else
			warn("Base not found:", baseName)
		end
	end
end

-- Create RemoteEvent for base upgrades
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
	remoteEventsFolder = Instance.new("Folder")
	remoteEventsFolder.Name = "RemoteEvents"
	remoteEventsFolder.Parent = ReplicatedStorage
end

local baseUpgradeEvent = remoteEventsFolder:FindFirstChild("BaseUpgradeEvent")
if not baseUpgradeEvent then
	baseUpgradeEvent = Instance.new("RemoteEvent")
	baseUpgradeEvent.Name = "BaseUpgradeEvent"
	baseUpgradeEvent.Parent = remoteEventsFolder
end

-- Create RemoteEvent for error sound
local errorSoundEvent = remoteEventsFolder:FindFirstChild("ErrorSound")
if not errorSoundEvent then
	errorSoundEvent = Instance.new("RemoteEvent")
	errorSoundEvent.Name = "ErrorSound"
	errorSoundEvent.Parent = remoteEventsFolder
end

-- Handle base upgrade requests from client
baseUpgradeEvent.OnServerEvent:Connect(function(player)
	local baseNumber = player:GetAttribute("BaseNumber")
	if not baseNumber then
		warn(player.Name, "doesn't have a base")
		return
	end
	
	local baseName = "Base" .. baseNumber
	local base = BASES_FOLDER:FindFirstChild(baseName)
	if not base then
		warn("Base not found:", baseName)
		return
	end
	
	local upgradeBase = base:FindFirstChild("UpgradeBase")
	
	print(player.Name, "requested base upgrade for Base" .. baseNumber)
	
	-- Attempt upgrade (server-side validation of money, etc.)
	local success, message = BaseUpgrade:PurchaseUpgrade(player)
	
	if success then
		print("Upgrade successful:", message)
		updateDisplay(upgradeBase, player)
		
		-- Send success notification
		local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
		if notificationEvent then
			notificationEvent:FireClient(player, message, true)
		end
	else
		warn(player.Name, "upgrade failed:", message)
		
		-- Play error sound
		errorSoundEvent:FireClient(player)
		
		-- Send error notification
		local notificationEvent = remoteEventsFolder:FindFirstChild("Notification")
		if notificationEvent then
			notificationEvent:FireClient(player, message, false)
		end
	end
end)

-- Update displays periodically for nearby players
local function monitorDisplays()
	while true do
		wait(2)
		
		for _, player in pairs(Players:GetPlayers()) do
			local baseNumber = player:GetAttribute("BaseNumber")
			if baseNumber then
				local baseName = "Base" .. baseNumber
				local base = BASES_FOLDER:FindFirstChild(baseName)
				
				if base then
					local upgradeBase = base:FindFirstChild("UpgradeBase")
					local sign = upgradeBase and upgradeBase:FindFirstChild("Sign")
					
					if sign then
						local character = player.Character
						local hrp = character and character:FindFirstChild("HumanoidRootPart")
						
						if hrp then
							local distance = (hrp.Position - sign.Position).Magnitude
							
							-- Update display if player is nearby
							if distance <= 20 then
								updateDisplay(upgradeBase, player)
							end
						end
					end
				end
			end
		end
	end
end

-- Initialize
initializeAllBases()
spawn(monitorDisplays)

print("Base Upgrade Station Manager initialized!")
