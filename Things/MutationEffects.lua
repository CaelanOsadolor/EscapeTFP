-- MutationEffects.lua
-- Applies visual effects to mutated things (recolors all parts with shine and outline)
-- Place in: ServerScriptService/Things/

local MutationEffects = {}

-- Mutation color and material definitions
local MUTATION_STYLES = {
	["Gold"] = {
		Color = Color3.fromRGB(255, 215, 0), -- Bright gold
		TextColor = Color3.fromRGB(255, 215, 0),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.4
	},
	["Emerald"] = {
		Color = Color3.fromRGB(0, 201, 87), -- Rich emerald green
		TextColor = Color3.fromRGB(0, 201, 87),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.3
	},
	["Diamond"] = {
		Color = Color3.fromRGB(185, 242, 255), -- Pale blue diamond
		TextColor = Color3.fromRGB(185, 242, 255),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.5
	},
	["Night"] = {
		Color = Color3.fromRGB(50, 50, 100), -- Dark blue
		TextColor = Color3.fromRGB(100, 100, 255), -- Lighter blue for text
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.2
	},
	["Love"] = {
		Color = Color3.fromRGB(255, 100, 200), -- Pink
		TextColor = Color3.fromRGB(255, 100, 200),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.3
	}
}

-- Get mutation text color
function MutationEffects.GetMutationColor(mutation)
	local style = MUTATION_STYLES[mutation]
	return style and style.TextColor or Color3.fromRGB(255, 255, 255)
end

-- Apply mutation effects to a thing model
function MutationEffects.ApplyEffects(thing)
	if not thing then return end

	-- Get mutation attribute
	local mutation = thing:GetAttribute("Mutation")
	if not mutation or mutation == "" then return end

	-- Get mutation style
	local style = MUTATION_STYLES[mutation]
	if not style then return end -- Unknown mutation type

	-- Apply color effects to all BaseParts in the model (including accessories)
	for _, descendant in ipairs(thing:GetDescendants()) do
		if descendant:IsA("BasePart") then
			-- Skip if it's a MeshPart with TextureID OR MeshId (phones use these!)
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
				-- Apply color
				descendant.Color = style.Color

				-- Apply material for better appearance
				descendant.Material = style.Material

				-- Apply reflectance for shine effect
				descendant.Reflectance = style.Reflectance
			end
		end

		-- Apply color to accessories (hats, etc)
		if descendant:IsA("Accessory") then
			local handle = descendant:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Color = style.Color
				handle.Material = style.Material
				handle.Reflectance = style.Reflectance
			end
		end
	end

	-- Add Highlight for full-body gold/diamond/emerald coating effect
	local highlight = Instance.new("Highlight")
	highlight.Name = "MutationHighlight"
	highlight.Parent = thing
	highlight.FillColor = style.Color
	highlight.OutlineColor = style.Color
	highlight.FillTransparency = 0.5 -- More opaque fill for "coated in gold" look
	highlight.OutlineTransparency = 0 -- Subtle outline
	highlight.Adornee = thing

	-- Add sparkle particles to the primary part
	local primaryPart = thing.PrimaryPart or thing:FindFirstChildWhichIsA("BasePart")
	if primaryPart then
		local particleEmitter = Instance.new("ParticleEmitter")
		particleEmitter.Name = "MutationSparkles"
		particleEmitter.Parent = primaryPart

		-- Particle appearance
		particleEmitter.Color = ColorSequence.new(style.Color)
		particleEmitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
		particleEmitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

		-- Particle behavior
		particleEmitter.Lifetime = NumberRange.new(1, 2)
		particleEmitter.Rate = 8
		particleEmitter.Speed = NumberRange.new(1, 3)
		particleEmitter.SpreadAngle = Vector2.new(180, 180)
		particleEmitter.Rotation = NumberRange.new(0, 360)
		particleEmitter.RotSpeed = NumberRange.new(-100, 100)

		-- Special texture for Love mutation (hearts), otherwise sparkles
		if mutation == "Love" then
			-- Heart particles for Love mutation
			particleEmitter.Texture = "rbxassetid://15256774849"
			particleEmitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 0.3)
			})
			particleEmitter.Rate = 15
			particleEmitter.Lifetime = NumberRange.new(1.5, 2.5)
			particleEmitter.Speed = NumberRange.new(0.3, 1)
			particleEmitter.SpreadAngle = Vector2.new(180, 180)
			particleEmitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.8, 0.5),
				NumberSequenceKeypoint.new(1, 1)
			})
		else
			-- Sparkle texture for other mutations
			particleEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		end

		particleEmitter.LightEmission = 1
		particleEmitter.LightInfluence = 0
	end
end

-- Remove mutation effects (restore original appearance)
function MutationEffects.RemoveEffects(thing)
	-- This would require storing original colors/materials
	-- For now, just a placeholder if needed later
end

return MutationEffects
