local Tool = script.Parent
local Remote = Tool:WaitForChild("Remote")
local Handle = Tool:WaitForChild("Handle")

local FriendlyFire = false

local ArmMesh

local HitAble = false
local HitWindup = 0.15
local HitWindow = 0.75
local HitVictims = {}

local SwingAble = true
local SwingRestTime = 7

--returns the wielding player of this tool
function getPlayer()
	local char = Tool.Parent
	return game:GetService("Players"):GetPlayerFromCharacter(char)
end

--helpfully checks a table for a specific value
function contains(t, v)
	for _, val in pairs(t) do
		if val == v then
			return true
		end
	end
	return false
end

--tags a human for the ROBLOX KO system
function tagHuman(human)
	local tag = Instance.new("ObjectValue")
	tag.Value = getPlayer()
	tag.Name = "creator"
	tag.Parent = human
	game:GetService("Debris"):AddItem(tag)
end

--used by checkTeams
function sameTeam(otherHuman)
	local player = getPlayer()
	local otherPlayer = game:GetService("Players"):GetPlayerFromCharacter(otherHuman.Parent)
	if player and otherPlayer then
		if player == otherPlayer then
			return true
		end
		if otherPlayer.Neutral then
			return false
		end
		return player.TeamColor == otherPlayer.TeamColor
	end
	return false
end

--use this to determine if you want this human to be harmed or not, returns boolean
function checkTeams(otherHuman)
	return not (sameTeam(otherHuman) and not FriendlyFire)
end

-- Ragdoll function - breaks all motor6d joints and replaces with ball socket constraints
function ragdollCharacter(character)
	local human = character:FindFirstChild("Humanoid")
	if not human then return end

	human.PlatformStand = true

	-- Store original motor6d joints
	local motors = {}
	for _, desc in pairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") then
			local socket = Instance.new("BallSocketConstraint")
			local a1 = Instance.new("Attachment")
			local a2 = Instance.new("Attachment")

			a1.Parent = desc.Part0
			a2.Parent = desc.Part1
			socket.Attachment0 = a1
			socket.Attachment1 = a2

			a1.CFrame = desc.C0
			a2.CFrame = desc.C1

			socket.Parent = desc.Parent

			table.insert(motors, {motor = desc, socket = socket, a1 = a1, a2 = a2})
			desc.Enabled = false
		end
	end

	-- Unragdoll after delay
	task.delay(2, function()
		for _, data in pairs(motors) do
			if data.motor and data.motor.Parent then
				data.motor.Enabled = true
			end
			if data.socket then data.socket:Destroy() end
			if data.a1 then data.a1:Destroy() end
			if data.a2 then data.a2:Destroy() end
		end
		if human and human.Parent then
			human.PlatformStand = false
		end
	end)
end

function onTouched(part)
	if part:IsDescendantOf(Tool.Parent) then return end
	if not HitAble then return end

	if part.Parent and part.Parent:FindFirstChild("Humanoid") then
		local human = part.Parent.Humanoid

		if contains(HitVictims, human) then return end

		local root = part.Parent:FindFirstChild("HumanoidRootPart")
		if root and not root.Anchored then
			local myRoot = Tool.Parent:FindFirstChild("HumanoidRootPart")
			if myRoot and checkTeams(human) then
				local delta = root.Position - myRoot.Position

				tagHuman(human)
				table.insert(HitVictims, human)

				-- Apply ragdoll effect
				ragdollCharacter(part.Parent)

				local bv = Instance.new("BodyVelocity")
				bv.maxForce = Vector3.new(1e9, 1e9, 1e9)
				bv.velocity = delta.unit * 25
				bv.Parent = root
				game:GetService("Debris"):AddItem(bv, 0.05)

				Handle.Smack:Play()
			end
		end
	end
end

function onEquip()
	--put in our right arm
	local char = Tool.Parent
	local armMeshTemplate = Tool:FindFirstChild("ArmMesh")
	if armMeshTemplate then
		-- Try R6 first
		local rightArm = char:FindFirstChild("Right Arm")
		-- If R15, try RightHand or RightLowerArm
		if not rightArm then
			rightArm = char:FindFirstChild("RightHand") or char:FindFirstChild("RightLowerArm")
		end

		if rightArm then
			local arm = armMeshTemplate:Clone()
			arm.Parent = rightArm
			ArmMesh = arm
		end
	end
end

function onUnequip()
	if ArmMesh then
		ArmMesh:Destroy()
		ArmMesh = nil
	end
end

function onLeftDown()
	if not SwingAble then return end

	SwingAble = false
	delay(SwingRestTime, function()
		SwingAble = true
	end)

	delay(HitWindup, function()
		HitAble = true
		delay(HitWindow, function()
			HitAble = false
		end)
	end)

	HitVictims = {}

	Remote:FireClient(getPlayer(), "PlayAnimation", "Swing")

	wait(0.25)
	Handle.Boom.Pitch = math.random(80, 100)/100
	Handle.Boom:Play()
end

function onRemote(player, func, ...)
	if player ~= getPlayer() then return end

	if func == "LeftDown" then
		onLeftDown(...)
	end
end

Tool.Equipped:connect(onEquip)
Tool.Unequipped:connect(onUnequip)
Handle.Touched:connect(onTouched)
Remote.OnServerEvent:connect(onRemote)