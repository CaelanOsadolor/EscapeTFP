local debounce = {}
local tracks = {} -- Store animation tracks per player

local handle = script.Parent.Handle
local canHit = true
local swinging = false

-- Ragdoll function - breaks all motor6d joints and replaces with ball socket constraints
local function ragdollCharacter(character)
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
	task.delay(1, function()
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

script.Parent.ToolEquippedUnequipped.OnServerEvent:Connect(function(plr, equipped)
	local char = plr.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	tracks[plr] = tracks[plr] or {}

	if equipped then
		local equipTrack = animator:LoadAnimation(script.Parent.Animations.equip)
		equipTrack.Priority = Enum.AnimationPriority.Action3
		equipTrack:Play()
		tracks[plr].equip = equipTrack
	else
		if tracks[plr] and tracks[plr].equip then
			tracks[plr].equip:Stop()
		end
	end
end)

script.Parent.ToolActivated.OnServerEvent:Connect(function(plr)
	if debounce[plr] then return end
	debounce[plr] = true
	task.delay(0.5, function()
		debounce[plr] = false
	end)

	local char = plr.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if swinging then return end

	swinging = true

	local useTrack = animator:LoadAnimation(script.Parent.Animations.use)
	useTrack.Priority = Enum.AnimationPriority.Action4
	useTrack:Play()
	tracks[plr] = tracks[plr] or {}
	tracks[plr].use = useTrack
	useTrack.Ended:Connect(function()
		swinging = false
		canHit = true
	end)
end)


handle.Touched:Connect(function(hit)
	if not swinging then return end
	local hum = hit.Parent:FindFirstChild("Humanoid")
	if hum then
		if hum.Parent == script.Parent.Parent then return end
		if canHit then
			canHit = false

			-- Get root parts for knockback calculation
			local victimRoot = hit.Parent:FindFirstChild("HumanoidRootPart")
			local attackerRoot = script.Parent.Parent:FindFirstChild("HumanoidRootPart")

			if victimRoot and attackerRoot and not victimRoot.Anchored then
				-- Calculate knockback direction
				local delta = victimRoot.Position - attackerRoot.Position

				-- Apply ragdoll effect
				ragdollCharacter(hit.Parent)

				-- Apply knockback using BodyVelocity
				local bv = Instance.new("BodyVelocity")
				bv.maxForce = Vector3.new(1e9, 1e9, 1e9)
				bv.velocity = delta.unit * 35
				bv.Parent = victimRoot
				game:GetService("Debris"):AddItem(bv, 0.05)

				-- Play hit sound
				if handle:FindFirstChild("Smack") then
					handle.Smack:Play()
				end
			end
		end
	end
end)