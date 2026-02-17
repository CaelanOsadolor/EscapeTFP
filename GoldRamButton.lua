-- Gold Ram Monster Purchase Button
-- Place as SERVER Script inside the Ram Monster model in Workspace

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local GOLD_RAM_PRODUCT_ID = 3526740159

-- Get the model and prompt
local ramModel = script.Parent
local promptFolder = ramModel:FindFirstChild("Prompt")
local prompt = promptFolder and promptFolder:FindFirstChildOfClass("ProximityPrompt")

if not prompt then
	warn("[GoldRamButton] ProximityPrompt not found in model!")
	return
end

print("[GoldRamButton] Initialized for", ramModel.Name)

-- Gold mutation effect configuration
local GOLD_COLOR = Color3.fromRGB(255, 215, 0)
local GOLD_MATERIAL = Enum.Material.SmoothPlastic
local GOLD_REFLECTANCE = 0.4

-- Apply gold mutation effect to the model
local function applyGoldEffect()
	-- Apply color effects to all BaseParts in the model
	for _, descendant in ipairs(ramModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			-- Skip if it's a MeshPart with TextureID OR MeshId
			local skipColoring = false
			if descendant:IsA("MeshPart") then
				if descendant.TextureID ~= "" or descendant.MeshId ~= "" then
					skipColoring = true
				end
			end
			
			-- Also skip Parts that have SpecialMesh children with textures/meshes
			if not skipColoring then
				local specialMesh = descendant:FindFirstChildOfClass("SpecialMesh")
				if specialMesh and (specialMesh.TextureId ~= "" or specialMesh.MeshId ~= "") then
					skipColoring = true
				end
			end

			if not skipColoring then
				descendant.Color = GOLD_COLOR
				descendant.Material = GOLD_MATERIAL
				descendant.Reflectance = GOLD_REFLECTANCE
			end
		end

		-- Apply color to accessories (hats, etc)
		if descendant:IsA("Accessory") then
			local handle = descendant:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Color = GOLD_COLOR
				handle.Material = GOLD_MATERIAL
				handle.Reflectance = GOLD_REFLECTANCE
			end
		end
	end

	-- Add Highlight for full-body gold coating effect
	if not ramModel:FindFirstChild("MutationHighlight") then
		local highlight = Instance.new("Highlight")
		highlight.Name = "MutationHighlight"
		highlight.Parent = ramModel
		highlight.FillColor = GOLD_COLOR
		highlight.OutlineColor = GOLD_COLOR
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.Adornee = ramModel
	end

	-- Add sparkle particles to the primary part
	local primaryPart = ramModel.PrimaryPart or ramModel:FindFirstChildWhichIsA("BasePart")
	if primaryPart and not primaryPart:FindFirstChild("MutationSparkles") then
		local particleEmitter = Instance.new("ParticleEmitter")
		particleEmitter.Name = "MutationSparkles"
		particleEmitter.Parent = primaryPart

		particleEmitter.Color = ColorSequence.new(GOLD_COLOR)
		particleEmitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
		particleEmitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
		particleEmitter.Lifetime = NumberRange.new(1, 2)
		particleEmitter.Rate = 8
		particleEmitter.Speed = NumberRange.new(1, 3)
		particleEmitter.SpreadAngle = Vector2.new(180, 180)
		particleEmitter.Rotation = NumberRange.new(0, 360)
		particleEmitter.RotSpeed = NumberRange.new(-100, 100)
		particleEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		particleEmitter.LightEmission = 1
		particleEmitter.LightInfluence = 0
	end

	print("[GoldRamButton] Gold effect applied to", ramModel.Name)
end

-- Apply gold effect immediately
applyGoldEffect()

-- Sounds
local soundsFolder = ReplicatedStorage:WaitForChild("Sounds")
local buttonPressSound = soundsFolder:FindFirstChild("ButtonPress")
local playSoundEvent = ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("PlaySoundEvent")

-- Handle proximity prompt trigger
prompt.Triggered:Connect(function(player)
	print("[GoldRamButton] Prompt triggered by", player.Name)
	
	-- Play button sound for the player
	if playSoundEvent and buttonPressSound then
		playSoundEvent:FireClient(player, "ButtonPress", 0.2, nil, nil)
	end
	
	-- Prompt purchase
	MarketplaceService:PromptProductPurchase(player, GOLD_RAM_PRODUCT_ID)
end)
