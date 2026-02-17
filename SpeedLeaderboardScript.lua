--[[
  SpeedLeaderboardClass
  
  A script designed to update a leaderboard with
  the top 10 players who have the highest speed.
  
  Connects to SaveManager's PlayerData_V1 datastore and player attributes.
]]

local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(script.Parent.SpeedLeaderboardSettings)

local SpeedLeaderboardClass = {}
SpeedLeaderboardClass.__index = SpeedLeaderboardClass


function SpeedLeaderboardClass.new()
	local new = {}
	setmetatable(new, SpeedLeaderboardClass)

	new._dataStoreName = Config.DATA_STORE
	new._dataStoreStatName = Config.NAME_OF_STAT
	new._boardUpdateDelay = Config.LEADERBOARD_UPDATE * 60
	new._useLeaderstats = Config.USE_LEADERSTATS
	new._nameLeaderstats = Config.NAME_LEADERSTATS
	new._show1stPlaceAvatar = Config.SHOW_1ST_PLACE_AVATAR
	if new._show1stPlaceAvatar == nil then new._show1stPlaceAvatar = true end
	new._doDebug = Config.DO_DEBUG

	new._datastore = nil
	new._scoreBlock = script.Parent.ScoreBlock
	new._updateBoardTimer = script.Parent.UpdateBoardTimer.Timer.TextLabel

	new._apiServicesEnabled = false
	new._isMainScript = nil

	new._isDancingRigEnabled = false
	new._dancingRigModule = nil

	new:_init()

	return new
end


function SpeedLeaderboardClass:_init()

	self:_checkIsMainScript()

	if self._isMainScript then
		if not self:_checkDataStoreUp() then
			self:_clearBoard()
			self._scoreBlock.NoAPIServices.Warning.Visible = true
			return
		end
	else
		self._apiServicesEnabled = (ServerStorage:WaitForChild("SpeedLeaderboard_NoAPIServices_Flag", 99) :: BoolValue).Value
		if not self._apiServicesEnabled then
			self:_clearBoard()
			self._scoreBlock.NoAPIServices.Warning.Visible = true
			return
		end
	end

	local suc, err = pcall(function ()
		self._datastore = DataStoreService:GetOrderedDataStore(self._dataStoreName)
	end)
	if not suc or self._datastore == nil then warn("Failed to load OrderedDataStore. Error:", err) script.Parent:Destroy() end

	self:_checkDancingRigEnabled()

	-- Sync speed from player attributes to OrderedDataStore every minute
	task.spawn(function ()
		if not self._isMainScript then return end
		while true do
			task.wait(60) -- Update every minute
			self:_syncSpeedToOrderedDataStore()
		end
	end)

	-- update leaderboard
	task.spawn(function ()
		self:_updateBoard() -- update once
		local count = self._boardUpdateDelay
		while true do
			task.wait(1)
			count -= 1
			self._updateBoardTimer.Text = ("Updating the board in %d seconds"):format(count)
			if count <= 0 then
				self:_updateBoard()
				count = self._boardUpdateDelay
			end
		end
	end)

end


function SpeedLeaderboardClass:_clearBoard ()
	for _, folder in pairs({self._scoreBlock.Leaderboard.Names, self._scoreBlock.Leaderboard.Photos, self._scoreBlock.Leaderboard.Score}) do
		for _, item in pairs(folder:GetChildren()) do
			item.Visible = false
		end
	end
end


function SpeedLeaderboardClass:_syncSpeedToOrderedDataStore()
	-- Sync current players' speed from attributes
	for _, player in pairs(game:GetService("Players"):GetPlayers()) do
		local speed = player:GetAttribute("Speed")
		if speed and speed > 0 then
			pcall(function()
				local stat = self._dataStoreStatName .. player.UserId
				-- Convert speed to integer for OrderedDataStore (multiply by 100 to preserve decimals)
				local speedValue = math.floor(speed * 100)
				self._datastore:SetAsync(stat, speedValue)
				if self._doDebug then print("Synced", player.Name, "speed:", speed) end
			end)
		end
	end
end


function SpeedLeaderboardClass:_updateBoard ()
	if self._doDebug then print("Updating Speed board") end
	local results = nil

	local suc, results = pcall(function ()
		return self._datastore:GetSortedAsync(false, 10, 1):GetCurrentPage()
	end)

	if not suc or not results then
		if self._doDebug then warn("Failed to retrieve top 10 with highest speed. Error:", results) end
		return
	end

	local sufgui = self._scoreBlock.Leaderboard
	self._scoreBlock.Credits.Enabled = true
	self._scoreBlock.Leaderboard.Enabled = #results ~= 0
	self._scoreBlock.NoDataFound.Enabled = #results == 0
	self:_clearBoard()

	for k, v in pairs(results) do
		local userid = tonumber(string.split(v.key, self._dataStoreStatName)[2])

		-- Try to get username, skip if user doesn't exist
		local suc, name = pcall(function()
			return game:GetService("Players"):GetNameFromUserIdAsync(userid)
		end)

		if not suc or not name then
			if self._doDebug then warn("Skipping invalid user ID:", userid) end
			continue
		end

		-- Convert back from integer storage (divide by 100)
		local actualSpeed = v.value / 100
		local score = self:_speedToString(actualSpeed)
		self:_onPlayerScoreUpdate(userid, actualSpeed)
		sufgui.Names["Name"..k].Visible = true
		sufgui.Score["Score"..k].Visible = true
		sufgui.Photos["Photo"..k].Visible = true
		sufgui.Names["Name"..k].Text = name
		sufgui.Score["Score"..k].Text = score

		-- Try to get thumbnail, use default if fails
		local thumbSuc, thumbnail = pcall(function()
			return game:GetService("Players"):GetUserThumbnailAsync(userid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		sufgui.Photos["Photo"..k].Image = thumbSuc and thumbnail or ""

		if k == 1 and self._dancingRigModule then
			task.spawn(function ()
				self._dancingRigModule.SetRigHumanoidDescription(userid)
			end)
		end
	end

	if self._scoreBlock:FindFirstChild("_backside") then self._scoreBlock["_backside"]:Destroy() end
	local temp = self._scoreBlock.Leaderboard:Clone()
	temp.Parent = self._scoreBlock
	temp.Name = "_backside"
	temp.Face = Enum.NormalId.Back
	if self._doDebug then print("Speed board updated sucessfully") end
end


function SpeedLeaderboardClass:_onPlayerScoreUpdate (userid, speed)
	-- Speed is stored as an attribute, not in leaderstats
	-- No need to update anything since we read from attributes already
	return
end


function SpeedLeaderboardClass:_checkDancingRigEnabled()
	if self._show1stPlaceAvatar then
		local rigFolder = script.Parent:FindFirstChild("First Place Avatar")
		if not rigFolder then return end
		local rig = rigFolder:FindFirstChild("Rig")
		local rigModule = rigFolder:FindFirstChild("PlayAnimationInRig")
		if not rig or not rigModule then return end
		-- Safely require the module (may have errors from old game)
		local success, result = pcall(function()
			return require(rigModule)
		end)
		if success and result then
			self._dancingRigModule = result
			self._isDancingRigEnabled = true
		else
			if self._doDebug then warn("Failed to load dancing rig module:", result) end
		end
	else
		local rigFolder = script.Parent:FindFirstChild("First Place Avatar")
		if not rigFolder then return end
		rigFolder:Destroy()
	end
end


function SpeedLeaderboardClass:_checkIsMainScript()
	local speedLeaderboardRunning = ServerStorage:FindFirstChild("SpeedLeaderboard_Running_Flag")
	if speedLeaderboardRunning then
		self._isMainScript = false
	else
		self._isMainScript = true
		local boolValue = Instance.new("BoolValue", ServerStorage)
		boolValue.Name = "SpeedLeaderboard_Running_Flag"
		boolValue.Value = true
	end
end


function SpeedLeaderboardClass:_checkDataStoreUp()
	local status, message = pcall(function()
		-- This will error if current instance has no Studio API access:
		DataStoreService:GetDataStore("____PS_Speed"):SetAsync("____PS", os.time())
	end)
	if status == false and
		(string.find(message, "404", 1, true) ~= nil or 
			string.find(message, "403", 1, true) ~= nil or -- Cannot write to DataStore from studio if API access is not enabled
			string.find(message, "must publish", 1, true) ~= nil) then -- Game must be published to access live keys
		local boolValue = Instance.new("BoolValue", ServerStorage)
		boolValue.Value = false
		boolValue.Name = "SpeedLeaderboard_NoAPIServices_Flag"
		return false
	end
	self._apiServicesEnabled = true
	local boolValue = Instance.new("BoolValue", ServerStorage)
	boolValue.Value = true
	boolValue.Name = "SpeedLeaderboard_NoAPIServices_Flag"
	return self._apiServicesEnabled
end


function SpeedLeaderboardClass:_speedToString(speed)
	return string.format("%.1f Speed", speed)
end


SpeedLeaderboardClass.new()
