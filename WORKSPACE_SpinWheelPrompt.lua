-- SpinWheelPrompt.lua
-- Server Script - Place this INSIDE Workspace > SpinWheel > PromptPart
-- Opens/closes SpinWheelFrame when player is near

local Players = game:GetService("Players")
local PromptPart = script.Parent

if not PromptPart:IsA("BasePart") then
	warn("SpinWheelPrompt must be inside a BasePart in Workspace!")
	return
end

local CLOSE_DISTANCE = 20
local CHECK_INTERVAL = 0.5
local playersInZone = {}

-- Open GUI
local function openGUI(player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end
	
	local spinWheel = playerGui:FindFirstChild("SpinWheel")
	if not spinWheel then return end
	
	local frame = spinWheel:FindFirstChild("SpinWheelFrame")
	local bg = spinWheel:FindFirstChild("Background") -- Background is sibling of frame, not child
	
	if frame then
		frame.Visible = true
		
		-- Also show background
		if bg then
			bg.Visible = true
		end
		
		print("Opened wheel GUI for", player.Name)
	end
end

-- Close GUI
local function closeGUI(player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end
	
	local spinWheel = playerGui:FindFirstChild("SpinWheel")
	if not spinWheel then return end
	
	local frame = spinWheel:FindFirstChild("SpinWheelFrame")
	local bg = spinWheel:FindFirstChild("Background") -- Background is sibling of frame, not child
	
	if frame then
		frame.Visible = false
		
		-- Also hide background
		if bg then
			bg.Visible = false
		end
		
		print("Closed wheel GUI for", player.Name)
	end
end

-- Check distance
local function isNear(player)
	local char = player.Character
	if not char then return false end
	
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	
	return (hrp.Position - PromptPart.Position).Magnitude <= CLOSE_DISTANCE
end

-- Monitor player
local function monitor(player)
	task.spawn(function()
		task.wait(0.5)
		
		while playersInZone[player.UserId] do
			if not isNear(player) then
				playersInZone[player.UserId] = nil
				closeGUI(player)
				break
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

-- Touch detection
PromptPart.Touched:Connect(function(hit)
	local char = hit.Parent
	local humanoid = char:FindFirstChild("Humanoid")
	
	if humanoid then
		local player = Players:GetPlayerFromCharacter(char)
		if player and not playersInZone[player.UserId] then
			playersInZone[player.UserId] = true
			openGUI(player)
			monitor(player)
		end
	end
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
	playersInZone[player.UserId] = nil
end)

print("SpinWheelPrompt ready!")
