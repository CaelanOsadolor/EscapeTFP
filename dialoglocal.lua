-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

--modules
local DialogModule = require(ReplicatedStorage.DialogModule)

--references
local player = Players.LocalPlayer
local playSoundEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("PlaySoundEvent")
local npc = script.Parent -- Reference to the NPC model
local npcGui = npc:WaitForChild("Head"):WaitForChild("gui")
local prompt = npc:WaitForChild("ProximityPrompt")

-- Tag the prompt for the DialogModule system
CollectionService:AddTag(prompt, "NPCprompt")

local dialogObject = DialogModule.new("Merchant", npc, prompt)
dialogObject:addDialog(
	"Hey, what do you want?",
	{
		"<font color='rgb(100,255,100)'>Sell this item</font>",
		"<font color='rgb(255,100,100)'>Sell my entire inventory</font>",
		"<font color='rgb(100,200,255)'>How much is this worth?</font>",
		"<font color='rgb(255,255,255)'>Goodbye</font>"
	}
)

-- Remote events for server communication
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local sellItemEvent = remoteEvents:WaitForChild("SellItem")
local sellInventoryEvent = remoteEvents:WaitForChild("SellInventory")
local getItemValueEvent = remoteEvents:WaitForChild("GetItemValue")

-- what happens when triggered
prompt.Triggered:Connect(function(player)
	dialogObject:triggerDialog(player, 1)
end)

-- logic to go through dialogs
dialogObject.responded:Connect(function(responseNum, dialogNum)
	local character = player.Character
	if not character then return end
	
	if dialogNum == 1 then
		if responseNum == 1 then
			-- Sell equipped item
			local equippedTool = character:FindFirstChildOfClass("Tool")
			if not equippedTool then
				dialogObject:hideGui("<font color='rgb(255,255,255)'>You don't have anything equipped! Equip an item from your inventory first.</font>", true)
				task.wait(2)
				dialogObject:triggerDialog(player, 1)
				return
			end
			
			local itemIndex = equippedTool:GetAttribute("InventoryIndex")
			if not itemIndex then
				dialogObject:hideGui("<font color='rgb(255,255,255)'>I can't buy that!</font>", true)
				task.wait(2)
				dialogObject:triggerDialog(player, 1)
				return
			end
			
			-- Request sell from server
			local success, moneyEarned = sellItemEvent:InvokeServer(itemIndex)
			if success then
				playSoundEvent:FireServer("SellSound")
				dialogObject:hideGui(string.format("<font color='rgb(255,255,255)'>Sold! You received $%d!</font>", moneyEarned))
			else
				dialogObject:hideGui("<font color='rgb(255,255,255)'>Something went wrong!</font>")
			end
			
		elseif responseNum == 2 then
			-- Sell entire inventory
			local backpack = player:FindFirstChild("Backpack")
			local itemCount = 0
			if backpack then
				for _, tool in pairs(backpack:GetChildren()) do
					if tool:IsA("Tool") and tool:GetAttribute("InventoryIndex") then
						itemCount += 1
					end
				end
			end
			
			-- Also count equipped tool
			local equippedTool = character:FindFirstChildOfClass("Tool")
			if equippedTool and equippedTool:GetAttribute("InventoryIndex") then
				itemCount += 1
			end
			
			if itemCount == 0 then
				dialogObject:hideGui("<font color='rgb(255,255,255)'>Your inventory is empty!</font>", true)
				task.wait(2)
				dialogObject:triggerDialog(player, 1)
				return
			end
			
			-- Request sell all from server
			local success, moneyEarned, itemsSold = sellInventoryEvent:InvokeServer()
			if success then
				playSoundEvent:FireServer("SellSound")
				dialogObject:hideGui(string.format("<font color='rgb(255,255,255)'>Sold %d items! You received $%d!</font>", itemsSold, moneyEarned))
			else
				dialogObject:hideGui("<font color='rgb(255,255,255)'>Something went wrong!</font>")
			end
			
		elseif responseNum == 3 then
			-- Check item worth
			local equippedTool = character:FindFirstChildOfClass("Tool")
			if not equippedTool then
				dialogObject:hideGui("<font color='rgb(255,255,255)'>You don't have anything equipped! Equip an item to check its value.</font>", true)
				task.wait(2)
				dialogObject:triggerDialog(player, 1)
				return
			end
			
			local itemIndex = equippedTool:GetAttribute("InventoryIndex")
			if not itemIndex then
				dialogObject:hideGui("<font color='rgb(255,255,255)'>I can't appraise that!</font>", true)
				task.wait(2)
				dialogObject:triggerDialog(player, 1)
				return
			end
			
			-- Request value from server
			local value, itemName = getItemValueEvent:InvokeServer(itemIndex)
			if value then
				dialogObject:hideGui(string.format("<font color='rgb(255,255,255)'>%s is worth $%d!</font>", itemName, value), true)
				task.wait(2)
				dialogObject:triggerDialog(player, 1)
			else
				dialogObject:hideGui("<font color='rgb(255,255,255)'>I can't appraise that!</font>")
			end
			
		elseif responseNum == 4 then
			-- Goodbye
			dialogObject:hideGui("<font color='rgb(255,255,255)'>Come back anytime!</font>")
		end
	end
end)