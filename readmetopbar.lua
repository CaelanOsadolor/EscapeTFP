--[[

> TopbarPlus was developed by ForeverHD and is actively maintained
thanks to HD Admin.

> You can get in touch with me on Discord via the social link here:
https://create.roblox.com/store/asset/92368439343389/TopbarPlus

> READ_ME is Script with RunContext set to 'Client' meaning you can
store it in ReplicatedStorage and Workspace and it will still run 
like a normal LocalScript. DO NOT PLACE place in StarterPlayerScripts
(because this is a Script with RunContext). You need to create a separate
LocalScript for anything under StarterPlayerScripts. 

> You're welcome to move `Icon` and require it yourself. You can
then delete this folder and READ_ME.

> Icon is a Package for when Roblox (hopefully soon) release
public packages. This for example will enable you to receive
automatic updates, and to compare code easily between changes

> Have feedback? Post it to devforum.roblox.com/t/topbarplus/1017485
which I actively monitor. Enjoy! ~ForeverHD June 2025

--]]



local container  = script.Parent
local Icon = require(container.Icon)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for UI to load
task.wait(2)

-- Get the specific UI elements to hide
local togglesContainer = nil
local godspeedGui = playerGui:WaitForChild("GodspeedTsunami", 5)
if godspeedGui then
	togglesContainer = godspeedGui:FindFirstChild("Toggles")
end

local shopScriptContainer = nil
local screenGui = playerGui:WaitForChild("ScreenGui", 5)
if screenGui then
	local mainUI = screenGui:FindFirstChild("MainUI")
	if mainUI then
		shopScriptContainer = mainUI:WaitForChild("Script", 5)
	end
end

-- Create the music toggle button
local musicIcon = Icon.new()
	:setName("")
	:setLabel("")
	:setImage(8625422354) -- Music on icon
	:setRight() -- Position on the right side

-- Track music state
local musicOn = true

-- Toggle music when clicked
musicIcon:bindEvent("selected", function()
	musicOn = not musicOn

	-- Mute/unmute all music in workspace camera (LocalMusicHandler music)
	for _, sound in ipairs(workspace.CurrentCamera:GetChildren()) do
		if sound:IsA("Sound") then
			sound.Playing = musicOn
		end
	end

	-- Mute/unmute all music in SoundService (background music)
	for _, sound in ipairs(SoundService:GetChildren()) do
		if sound:IsA("Sound") then
			sound.Playing = musicOn
		end
	end

	if musicOn then
		musicIcon:setImage(8625422354) -- Music on icon
	else
		musicIcon:setImage(8625441570) -- Music off icon
	end
end)

-- Create the Hide UI toggle button
local hideUiIcon = Icon.new()
	:setName("")
	:setLabel("")
	:setImage(78134819718605) -- UI visible icon
	:setRight() -- Position on the right side

-- Track UI state
local uiVisible = true

-- Toggle UI visibility when clicked
hideUiIcon:bindEvent("selected", function()
	uiVisible = not uiVisible
	
	if togglesContainer then
		togglesContainer.Visible = uiVisible
	end
	
	if shopScriptContainer then
		-- Script is a Folder, hide the TextButtons inside it
		for _, button in ipairs(shopScriptContainer:GetChildren()) do
			if button:IsA("TextButton") then
				button.Visible = uiVisible
			end
		end
	end

	if uiVisible then
		hideUiIcon:setImage(78134819718605) -- UI visible icon
	else
		hideUiIcon:setImage(72507073051055) -- UI hidden icon
	end
end)