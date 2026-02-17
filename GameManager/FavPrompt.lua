local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local showFavoritePrompt = remoteEventsFolder:WaitForChild("ShowFavoritePrompt")

showFavoritePrompt.OnClientEvent:Connect(function()
	if Player then
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end
end)
