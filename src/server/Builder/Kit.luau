--!strict
-- Low-level construction helpers and the restrained material palette
-- (ART_BIBLE §4, §8). All builder modules create parts through here so the
-- look stays consistent.

local Kit = {}

Kit.Palette = {
	Soot = Color3.fromRGB(28, 26, 26),
	Charcoal = Color3.fromRGB(44, 42, 42),
	AgedStone = Color3.fromRGB(92, 86, 78),
	DarkStone = Color3.fromRGB(62, 58, 54),
	PaleStone = Color3.fromRGB(122, 116, 104),
	DarkBrown = Color3.fromRGB(58, 42, 32),
	Wood = Color3.fromRGB(84, 62, 44),
	OldIron = Color3.fromRGB(52, 50, 50),
	Rust = Color3.fromRGB(110, 62, 40),
	Brick = Color3.fromRGB(104, 58, 48),
	Parchment = Color3.fromRGB(196, 178, 140),
	Moss = Color3.fromRGB(58, 70, 48),
	Burgundy = Color3.fromRGB(72, 28, 32),
	Gold = Color3.fromRGB(150, 122, 70),
	Amber = Color3.fromRGB(255, 160, 80),
	Candle = Color3.fromRGB(255, 196, 130),
	Moon = Color3.fromRGB(150, 170, 205),
	DeepBlue = Color3.fromRGB(70, 96, 140),
	Bone = Color3.fromRGB(176, 168, 150),
}

export type PartProps = {
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	CanCollide: boolean?,
	CastShadow: boolean?,
	Transparency: number?,
	Name: string?,
	Shape: Enum.PartType?,
	CanQuery: boolean?,
}

function Kit.Part(parent: Instance, p: PartProps): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = p.Size
	part.CFrame = p.CFrame
	part.Color = p.Color or Kit.Palette.AgedStone
	part.Material = p.Material or Enum.Material.Slate
	part.CanCollide = if p.CanCollide == nil then true else p.CanCollide
	part.CastShadow = if p.CastShadow == nil then true else p.CastShadow
	part.Transparency = p.Transparency or 0
	part.Name = p.Name or "Part"
	if p.Shape then
		part.Shape = p.Shape
	end
	if p.CanQuery ~= nil then
		part.CanQuery = p.CanQuery
	end
	if not part.CanCollide then
		part.CanTouch = false
	end
	part.Parent = parent
	return part
end

-- Non-colliding decorative part.
function Kit.Deco(parent: Instance, p: PartProps): Part
	p.CanCollide = false
	return Kit.Part(parent, p)
end

function Kit.Model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit.Folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Slight per-part colour variation so masonry never looks flat.
function Kit.Vary(color: Color3, amount: number, seed: number): Color3
	local r = Random.new(seed)
	local k = 1 + (r:NextNumber() * 2 - 1) * amount
	return Color3.new(math.clamp(color.R * k, 0, 1), math.clamp(color.G * k, 0, 1), math.clamp(color.B * k, 0, 1))
end

function Kit.PointLight(parent: Instance, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = if shadows == nil then true else shadows
	l.Parent = parent
	return l
end

function Kit.Attachment(parent: Instance, offset: Vector3?): Attachment
	local a = Instance.new("Attachment")
	a.Position = offset or Vector3.zero
	a.Parent = parent
	return a
end

-- Restrained flame: small, dim, few particles (ART_BIBLE §17).
function Kit.Flame(parent: Instance, scale: number?): ParticleEmitter
	local s = scale or 1
	local e = Instance.new("ParticleEmitter")
	e.Name = "Flame"
	e.Texture = "rbxasset://textures/particles/fire_main.dds"
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 70, 30)),
	})
	e.LightEmission = 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1 * s), NumberSequenceKeypoint.new(1, 0.1 * s) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Rate = 16
	e.Speed = NumberRange.new(2 * s, 3.5 * s)
	e.SpreadAngle = Vector2.new(8, 8)
	e.Acceleration = Vector3.new(0, 2, 0)
	e.LockedToPart = false
	e.Parent = parent
	return e
end

function Kit.Embers(parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Embers"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 150, 70))
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.15)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.2, 2.2)
	e.Rate = 3
	e.Speed = NumberRange.new(1.5, 3)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, 1, 0)
	e.Parent = parent
	return e
end

-- Dust that drifts along `direction` (world space). Used for the draft law.
function Kit.Dust(parent: Instance, direction: Vector3, rate: number?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Draft"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(170, 160, 140))
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.6) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(2.2, 3.2)
	e.Rate = rate or 7
	e.Speed = NumberRange.new(0.2, 0.5)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Acceleration = direction.Unit * 2.2
	e.Drag = 0.6
	e.Parent = parent
	return e
end

return Kit
