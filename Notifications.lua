local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local NotificationTemplate = script:WaitForChild("Notification")
local NotificationsGui = PlayerGui:WaitForChild("NotificationsGui")

-- Wait for RemoteEvents folder
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

-- Wait for Notification event
local NotificationEvent = RemoteEvents:WaitForChild("Notification")

-- Get the Notifications frame from NotificationsGui (make sure it's a Frame, not the script)
local Notifications = nil
for _, child in NotificationsGui:GetChildren() do
	if child.Name == "Notifications" and child:IsA("Frame") then
		Notifications = child
		break
	end
end

if not Notifications then
	warn("[Notifications] Could not find Notifications Frame in NotificationsGui")
end

NotificationEvent.OnClientEvent:Connect(function(Text, Polarity, CustomColor, CustomDuration)
	if not Notifications then
		warn("[Notifications] Could not find Notifications Frame")
		return
	end

	local Notification = NotificationTemplate:Clone()
	Notification.Visible = true

	-- Use custom color if provided, otherwise use polarity-based colors
	if CustomColor then
		Notification.Text = Text
		Notification.TextColor3 = CustomColor
	elseif Polarity then
		Notification.Text = Text
		Notification.TextColor3 = Color3.fromRGB(0, 255, 0)
	else
		Notification.Text = Text
		Notification.TextColor3 = Color3.fromRGB(196, 40, 28)
	end

	Notification.Parent = Notifications

	-- Hold for custom duration (default 2 seconds), then smooth fade out
	local holdDuration = CustomDuration or 2
	task.delay(holdDuration, function()
		if not Notification or not Notification.Parent then return end

		local fadeOutInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local fadeOut = TweenService:Create(Notification, fadeOutInfo, {
			TextTransparency = 1,
			Position = Notification.Position + UDim2.new(0, 0, -0.1, 0) -- Slight upward drift
		})
		fadeOut:Play()

		if Notification:FindFirstChildOfClass("UIStroke") then
			TweenService:Create(Notification:FindFirstChildOfClass("UIStroke"), fadeOutInfo, {Transparency = 1}):Play()
		end

		fadeOut.Completed:Connect(function()
			if Notification and Notification.Parent then
				Notification:Destroy()
			end
		end)
	end)

	task.spawn(function()
		while Notification and Notification.Parent do
			local TopLimit = Notifications.AbsolutePosition.Y - (Notifications.AbsoluteSize.Y / 2)
			if Notification.AbsolutePosition.Y < TopLimit then
				Notification:Destroy()
				break
			end
			task.wait(0.1)
		end
	end)
end)

