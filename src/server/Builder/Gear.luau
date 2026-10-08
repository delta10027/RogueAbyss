--!strict
-- Visible equipment: weapon models (in hand and lying on the ground) and
-- armor worn on the character. Every weapon has its own silhouette, every
-- armor tier visibly changes the explorer, and enchantments glow.
--
-- Weapon models are built pointing up (+Y) from the grip at the origin.
-- They carry two attachments, TrailBase and TrailTip, and a disabled Trail
-- that the client switches on while swinging.

local Gear = {}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = parent
	return p
end

-- A pointed tip (triangle in the Y-Z plane) whose base sits at `baseY`.
local function tip(parent: Instance, x: number, width: number, height: number, baseY: number, color: Color3, material: Enum.Material)
	wedge(parent, "TipA", Vector3.new(x, height, width / 2), CFrame.new(0, baseY + height / 2, -width / 4), color, material)
	wedge(parent, "TipB", Vector3.new(x, height, width / 2), CFrame.new(0, baseY + height / 2, width / 4) * CFrame.Angles(0, math.pi, 0), color, material)
end

local STEEL = Color3.fromRGB(196, 196, 190)
local DARK_STEEL = Color3.fromRGB(110, 110, 112)
local LEATHER = Color3.fromRGB(70, 46, 32)
local WOOD = Color3.fromRGB(96, 68, 44)
local BRASS = Color3.fromRGB(170, 132, 70)

local ENCHANT_COLOR = Color3.fromRGB(130, 170, 255)

local function glowGem(parent: Instance, name: string, size: number, cf: CFrame, color: Color3, lightRange: number)
	local g = part(parent, name, Vector3.new(size, size, size), cf, color, Enum.Material.Neon, Enum.PartType.Ball)
	g.Transparency = 0.15
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = lightRange
	l.Brightness = 1.4
	l.Shadows = false
	l.Parent = g
	return g
end

local function sparkles(parent: Instance, color: Color3, rate: number, size: number?)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.25), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 1)
	e.Rate = rate
	e.Speed = NumberRange.new(0.3, 1)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LockedToPart = false
	e.Parent = parent
	return e
end

local BUILDERS: { [string]: (Model) -> (number, BasePart) } = {}
-- Each builder returns (blade length from grip, part that carries the blade).

BUILDERS.Quarterstaff = function(m)
	local shaft = part(m, "Shaft", Vector3.new(5.6, 0.26, 0.26), CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	for _, y in { 4.1, -1.3 } do
		part(m, "Cap", Vector3.new(0.4, 0.32, 0.32), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	part(m, "Wrap", Vector3.new(0.9, 0.3, 0.3), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), LEATHER, Enum.Material.Fabric, Enum.PartType.Cylinder)
	return 4.2, shaft
end

BUILDERS.Dagger = function(m)
	part(m, "Grip", Vector3.new(0.18, 0.7, 0.18), CFrame.new(0, 0, 0), LEATHER, Enum.Material.Fabric)
	part(m, "Pommel", Vector3.new(0.28, 0.28, 0.28), CFrame.new(0, -0.42, 0), BRASS, Enum.Material.Metal, Enum.PartType.Ball)
	part(m, "Guard", Vector3.new(0.16, 0.12, 0.8), CFrame.new(0, 0.4, 0), BRASS, Enum.Material.Metal)
	local blade = part(m, "Blade", Vector3.new(0.08, 1.1, 0.3), CFrame.new(0, 1.01, 0), STEEL, Enum.Material.Metal)
	tip(m, 0.08, 0.3, 0.45, 1.56, STEEL, Enum.Material.Metal)
	return 2, blade
end

BUILDERS.Mace = function(m)
	part(m, "Haft", Vector3.new(0.2, 2.8, 0.2), CFrame.new(0, 0.8, 0), DARK_STEEL, Enum.Material.Metal)
	part(m, "Grip", Vector3.new(0.26, 0.8, 0.26), CFrame.new(0, 0, 0), LEATHER, Enum.Material.Fabric)
	local head = part(m, "Head", Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, 2.35, 0), DARK_STEEL, Enum.Material.Metal, Enum.PartType.Ball)
	for i = 0, 5 do
		local a = i * math.pi / 3
		part(m, "Flange", Vector3.new(0.12, 0.85, 0.42), CFrame.new(0, 2.35, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 0.38), DARK_STEEL, Enum.Material.Metal)
	end
	part(m, "Spike", Vector3.new(0.14, 0.4, 0.14), CFrame.new(0, 2.9, 0), STEEL, Enum.Material.Metal)
	return 2.6, head
end

BUILDERS.Spear = function(m)
	part(m, "Shaft", Vector3.new(0.2, 6.4, 0.2), CFrame.new(0, 1.6, 0), WOOD, Enum.Material.Wood)
	part(m, "Binding", Vector3.new(0.3, 0.35, 0.3), CFrame.new(0, 4.7, 0), LEATHER, Enum.Material.Fabric)
	local head = part(m, "Head", Vector3.new(0.08, 0.7, 0.42), CFrame.new(0, 5.2, 0), STEEL, Enum.Material.Metal)
	tip(m, 0.08, 0.42, 0.8, 5.55, STEEL, Enum.Material.Metal)
	part(m, "Butt", Vector3.new(0.26, 0.3, 0.26), CFrame.new(0, -1.55, 0), BRASS, Enum.Material.Metal)
	return 6.3, head
end

BUILDERS.LongSword = function(m)
	part(m, "Grip", Vector3.new(0.2, 0.95, 0.2), CFrame.new(0, 0, 0), LEATHER, Enum.Material.Fabric)
	part(m, "Pommel", Vector3.new(0.34, 0.34, 0.34), CFrame.new(0, -0.58, 0), BRASS, Enum.Material.Metal, Enum.PartType.Ball)
	part(m, "Guard", Vector3.new(0.2, 0.18, 1.4), CFrame.new(0, 0.55, 0), DARK_STEEL, Enum.Material.Metal)
	local blade = part(m, "Blade", Vector3.new(0.1, 3.2, 0.36), CFrame.new(0, 2.24, 0), STEEL, Enum.Material.Metal)
	part(m, "Fuller", Vector3.new(0.11, 2.6, 0.08), CFrame.new(0, 2.1, 0), DARK_STEEL, Enum.Material.Metal)
	tip(m, 0.1, 0.36, 0.55, 3.84, STEEL, Enum.Material.Metal)
	return 4.3, blade
end

BUILDERS.TwoHandedSword = function(m)
	part(m, "Grip", Vector3.new(0.22, 1.5, 0.22), CFrame.new(0, -0.2, 0), LEATHER, Enum.Material.Fabric)
	part(m, "Pommel", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, -1.05, 0), DARK_STEEL, Enum.Material.Metal, Enum.PartType.Ball)
	part(m, "Guard", Vector3.new(0.24, 0.22, 2.1), CFrame.new(0, 0.62, 0), DARK_STEEL, Enum.Material.Metal)
	for _, z in { -1.05, 1.05 } do
		part(m, "Quillon", Vector3.new(0.24, 0.5, 0.2), CFrame.new(0, 0.45, z), DARK_STEEL, Enum.Material.Metal)
	end
	part(m, "Ricasso", Vector3.new(0.14, 0.7, 0.34), CFrame.new(0, 1.07, 0), DARK_STEEL, Enum.Material.Metal)
	local blade = part(m, "Blade", Vector3.new(0.12, 4.3, 0.55), CFrame.new(0, 3.55, 0), STEEL, Enum.Material.Metal)
	part(m, "Fuller", Vector3.new(0.13, 3.6, 0.1), CFrame.new(0, 3.3, 0), DARK_STEEL, Enum.Material.Metal)
	tip(m, 0.12, 0.55, 0.7, 5.7, STEEL, Enum.Material.Metal)
	return 6.3, blade
end

BUILDERS.BattleAxe = function(m)
	part(m, "Haft", Vector3.new(0.22, 3.6, 0.22), CFrame.new(0, 1.1, 0), WOOD, Enum.Material.Wood)
	part(m, "Grip", Vector3.new(0.28, 0.8, 0.28), CFrame.new(0, -0.2, 0), LEATHER, Enum.Material.Fabric)
	local head = part(m, "Head", Vector3.new(0.18, 0.7, 0.5), CFrame.new(0, 2.6, 0.3), DARK_STEEL, Enum.Material.Metal)
	-- Crescent blade: three slabs fanning out.
	for i, a in { -28, 0, 28 } do
		part(m, "Bit" .. i, Vector3.new(0.12, 0.55, 0.9), CFrame.new(0, 2.6, 0.6) * CFrame.Angles(math.rad(a), 0, 0) * CFrame.new(0, 0, 0.35), STEEL, Enum.Material.Metal)
	end
	part(m, "BackSpike", Vector3.new(0.12, 0.25, 0.6), CFrame.new(0, 2.6, -0.3), DARK_STEEL, Enum.Material.Metal)
	part(m, "Cap", Vector3.new(0.26, 0.3, 0.26), CFrame.new(0, 3.0, 0), DARK_STEEL, Enum.Material.Metal)
	return 3.1, head
end

local function staffShaft(m: Model, color: Color3, material: Enum.Material): BasePart
	local low = part(m, "ShaftLow", Vector3.new(0.24, 3.2, 0.24), CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(2)), color, material)
	part(m, "ShaftHigh", Vector3.new(0.22, 2.2, 0.22), CFrame.new(0.05, 3.2, 0) * CFrame.Angles(0, 0, math.rad(-4)), color, material)
	part(m, "Wrap", Vector3.new(0.3, 0.7, 0.3), CFrame.new(0, 0.1, 0), LEATHER, Enum.Material.Fabric)
	return low
end

BUILDERS.StaffOfFire = function(m)
	staffShaft(m, Color3.fromRGB(46, 30, 24), Enum.Material.Wood)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		part(m, "Claw", Vector3.new(0.1, 0.8, 0.1), CFrame.new(0.05, 4.5, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 0.22) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(40, 30, 26), Enum.Material.Metal)
	end
	local gem = glowGem(m, "Gem", 0.48, CFrame.new(0.05, 4.75, 0), Color3.fromRGB(255, 120, 40), 9)
	local f = Instance.new("ParticleEmitter")
	f.Texture = "rbxasset://textures/particles/fire_main.dds"
	f.Color = ColorSequence.new(Color3.fromRGB(255, 170, 80), Color3.fromRGB(200, 60, 20))
	f.LightEmission = 0.8
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	f.Lifetime = NumberRange.new(0.3, 0.6)
	f.Rate = 18
	f.Speed = NumberRange.new(1, 2)
	f.Parent = gem
	return 4.9, gem
end

BUILDERS.StaffOfFrost = function(m)
	staffShaft(m, Color3.fromRGB(150, 160, 170), Enum.Material.Ice)
	local core = glowGem(m, "Gem", 0.36, CFrame.new(0.05, 4.65, 0), Color3.fromRGB(150, 210, 255), 9)
	for i, a in { { 0, 0 }, { 25, 60 }, { -25, 140 }, { 20, 240 } } do
		local c = part(m, "Crystal" .. i, Vector3.new(0.22, 0.9, 0.22), CFrame.new(0.05, 4.6, 0) * CFrame.Angles(0, math.rad(a[2]), math.rad(a[1])) * CFrame.new(0, 0.35, 0), Color3.fromRGB(170, 220, 255), Enum.Material.Glass)
		c.Transparency = 0.25
	end
	sparkles(core, Color3.fromRGB(200, 235, 255), 6)
	return 4.9, core
end

BUILDERS.StaffOfStorms = function(m)
	staffShaft(m, Color3.fromRGB(60, 50, 44), Enum.Material.Wood)
	local ring = part(m, "Ring", Vector3.new(0.12, 1.0, 1.0), CFrame.new(0.05, 4.7, 0) * CFrame.Angles(0, 0, math.rad(90)), BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
	ring.Size = Vector3.new(0.12, 1, 1)
	ring.Transparency = 0
	local orb = glowGem(m, "Gem", 0.38, CFrame.new(0.05, 4.7, 0), Color3.fromRGB(200, 220, 255), 10)
	sparkles(orb, Color3.fromRGB(220, 230, 255), 12, 0.35)
	return 5, orb
end

BUILDERS.StaffOfShadows = function(m)
	staffShaft(m, Color3.fromRGB(24, 20, 26), Enum.Material.Slate)
	for i = 0, 3 do
		local a = i * math.pi / 2
		part(m, "Thorn", Vector3.new(0.1, 0.7, 0.1), CFrame.new(0.05, 4.4, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 0.18) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(30, 24, 34), Enum.Material.Slate)
	end
	local eye = glowGem(m, "Gem", 0.42, CFrame.new(0.05, 4.7, 0), Color3.fromRGB(160, 70, 200), 8)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(40, 20, 50))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.2) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(0.3, 0.8)
	smoke.Parent = eye
	return 4.9, eye
end

-- Builds a weapon model. The model's PrimaryPart ("GripPoint") sits where
-- the hand holds it; everything is welded to it.
function Gear.Weapon(weaponId: string, bonus: number?, tint: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "Weapon_" .. weaponId
	local builder = BUILDERS[weaponId] or BUILDERS.Quarterstaff
	local length, bladePart = builder(m)
	local grip = part(m, "GripPoint", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), LEATHER, Enum.Material.Fabric)
	grip.Transparency = 1
	m.PrimaryPart = grip
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p ~= grip then
			local w = Instance.new("WeldConstraint")
			w.Part0 = grip
			w.Part1 = p
			w.Parent = p
		end
	end
	-- Trail along the striking part.
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.Position = Vector3.new(0, length * 0.45, 0)
	base.Parent = grip
	local tipAtt = Instance.new("Attachment")
	tipAtt.Name = "TrailTip"
	tipAtt.Position = Vector3.new(0, length, 0)
	tipAtt.Parent = grip
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = base
	trail.Attachment1 = tipAtt
	trail.Lifetime = 0.16
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.6
	local b = bonus or 0
	local trailColor = tint or (if b > 0 then ENCHANT_COLOR else Color3.fromRGB(235, 225, 200))
	trail.Color = ColorSequence.new(trailColor)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
	trail.Enabled = false
	trail.Parent = grip
	-- Enchantments: a cold glow that grows with the bonus.
	if b > 0 then
		local l = Instance.new("PointLight")
		l.Color = ENCHANT_COLOR
		l.Range = 4 + b * 2
		l.Brightness = 0.6 + b * 0.3
		l.Shadows = false
		l.Parent = bladePart
		sparkles(bladePart, ENCHANT_COLOR, 2 + b * 3)
		if b >= 2 then
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") and (p.Name == "Blade" or p.Name == "Head" or p.Name == "Shaft" or p.Name == "TipA" or p.Name == "TipB") then
					local glow = p:Clone()
					glow.Name = "EnchantEdge"
					glow:ClearAllChildren()
					glow.Material = Enum.Material.ForceField
					glow.Color = ENCHANT_COLOR
					glow.Size = p.Size * 1.08
					glow.Parent = m
					local w = Instance.new("WeldConstraint")
					w.Part0 = grip
					w.Part1 = glow
					w.Parent = glow
				end
			end
		end
	end
	m:SetAttribute("Length", length)
	return m
end

---------------------------------------------------------------------------
-- Armor
---------------------------------------------------------------------------

local function bodyPart(character: Model, r15: string, r6: string): BasePart?
	return (character:FindFirstChild(r15) or character:FindFirstChild(r6)) :: BasePart?
end

local function wear(folder: Instance, to: BasePart?, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): BasePart?
	if not to then
		return nil
	end
	local p = part(folder, name, size, to.CFrame * offset, color, material, shape)
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
	return p
end

local RUNE = Color3.fromRGB(140, 190, 255)

-- Dresses `character` in the given armor. `level` adds trim to the cloak.
function Gear.Outfit(character: Model, armorId: string?, bonus: number?, level: number?)
	local old = character:FindFirstChild("Outfit")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Outfit"
	folder.Parent = character

	local head = bodyPart(character, "Head", "Head")
	local torso = bodyPart(character, "UpperTorso", "Torso")
	local lower = bodyPart(character, "LowerTorso", "Torso")
	local lArm = bodyPart(character, "LeftUpperArm", "Left Arm")
	local rArm = bodyPart(character, "RightUpperArm", "Right Arm")
	local lFore = bodyPart(character, "LeftLowerArm", "Left Arm")
	local rFore = bodyPart(character, "RightLowerArm", "Right Arm")
	local lLeg = bodyPart(character, "LeftLowerLeg", "Left Leg")
	local rLeg = bodyPart(character, "RightLowerLeg", "Right Leg")
	local hood = character:FindFirstChild("Hood") :: BasePart?
	if not torso then
		return
	end
	local ts = torso.Size
	local tier = 0
	local id = armorId or "LeatherArmor"
	local metal = Enum.Material.Metal

	local function shoulders(color: Color3, scale: number, material: Enum.Material)
		for _, arm in { lArm, rArm } do
			if arm then
				local side = if arm == lArm then -1 else 1
				wear(folder, torso, "Pauldron", Vector3.new(1.3, 0.75, 1.35) * scale, CFrame.new(side * (ts.X / 2 + 0.25), ts.Y / 2 - 0.05, 0) * CFrame.Angles(0, 0, math.rad(-side * 18)), color, material, Enum.PartType.Ball)
			end
		end
	end
	local function vest(color: Color3, material: Enum.Material, grow: number)
		wear(folder, torso, "Vest", ts + Vector3.new(grow, 0.05, grow), CFrame.new(0, 0.02, 0), color, material)
		if lower and lower ~= torso then
			wear(folder, lower, "Skirt", lower.Size + Vector3.new(grow + 0.1, 0.2, grow + 0.1), CFrame.new(0, -0.1, 0), color, material)
		end
	end
	local function belt(color: Color3)
		if lower then
			local y = if lower == torso then -ts.Y / 2 + 0.2 else lower.Size.Y / 2 - 0.1
			wear(folder, lower, "Belt", Vector3.new(lower.Size.X + 0.2, 0.25, lower.Size.Z + 0.2), CFrame.new(0, y, 0), color, Enum.Material.Fabric)
			wear(folder, lower, "Buckle", Vector3.new(0.35, 0.3, 0.1), CFrame.new(0, y, -lower.Size.Z / 2 - 0.12), BRASS, metal)
		end
	end
	local function bracers(color: Color3, material: Enum.Material)
		for _, f in { lFore, rFore } do
			if f then
				wear(folder, f, "Bracer", f.Size + Vector3.new(0.12, -0.1, 0.12), CFrame.new(0, -0.05, 0), color, material)
			end
		end
	end
	local function greaves(color: Color3, material: Enum.Material)
		for _, l in { lLeg, rLeg } do
			if l then
				wear(folder, l, "Greave", l.Size + Vector3.new(0.12, -0.05, 0.12), CFrame.new(0, 0, 0), color, material)
			end
		end
	end
	local function setHood(visible: boolean)
		if hood then
			hood.Transparency = if visible then 0 else 1
		end
	end

	setHood(true)
	if id == "LeatherArmor" then
		vest(Color3.fromRGB(96, 66, 44), Enum.Material.Leather, 0.12)
		belt(Color3.fromRGB(50, 34, 24))
		bracers(Color3.fromRGB(80, 56, 38), Enum.Material.Leather)
	elseif id == "RingMail" then
		tier = 1
		vest(Color3.fromRGB(104, 100, 94), Enum.Material.DiamondPlate, 0.14)
		belt(Color3.fromRGB(50, 34, 24))
		shoulders(Color3.fromRGB(90, 62, 42), 0.85, Enum.Material.Leather)
		bracers(Color3.fromRGB(80, 56, 38), Enum.Material.Leather)
	elseif id == "ScaleMail" then
		tier = 2
		vest(Color3.fromRGB(150, 116, 66), Enum.Material.Cobblestone, 0.16)
		belt(Color3.fromRGB(60, 40, 26))
		shoulders(Color3.fromRGB(160, 124, 70), 1, metal)
		bracers(Color3.fromRGB(140, 108, 62), metal)
	elseif id == "ChainMail" then
		tier = 3
		vest(Color3.fromRGB(150, 150, 146), Enum.Material.DiamondPlate, 0.16)
		belt(Color3.fromRGB(50, 34, 24))
		shoulders(Color3.fromRGB(140, 140, 136), 0.95, Enum.Material.DiamondPlate)
		bracers(Color3.fromRGB(140, 140, 136), Enum.Material.DiamondPlate)
		if head then
			setHood(false)
			wear(folder, head, "Coif", head.Size * Vector3.new(1.3, 1.2, 1.3), CFrame.new(0, 0.1, 0.06), Color3.fromRGB(140, 140, 136), Enum.Material.DiamondPlate)
		end
	elseif id == "BandedMail" then
		tier = 4
		vest(Color3.fromRGB(120, 120, 118), Enum.Material.DiamondPlate, 0.16)
		for i = 0, 2 do
			wear(folder, torso, "Band", Vector3.new(ts.X + 0.3, 0.22, ts.Z + 0.3), CFrame.new(0, ts.Y / 2 - 0.35 - i * 0.55, 0), Color3.fromRGB(150, 154, 162), metal)
		end
		belt(Color3.fromRGB(50, 34, 24))
		shoulders(Color3.fromRGB(150, 154, 162), 1.1, metal)
		bracers(Color3.fromRGB(150, 154, 162), metal)
		greaves(Color3.fromRGB(130, 134, 140), metal)
		if head then
			setHood(false)
			wear(folder, head, "Helm", head.Size * Vector3.new(1.15, 0.75, 1.15), CFrame.new(0, 0.3, 0), Color3.fromRGB(150, 154, 162), metal, Enum.PartType.Ball)
			wear(folder, head, "Brim", Vector3.new(0.12, head.Size.X * 1.7, head.Size.X * 1.7), CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(130, 134, 140), metal, Enum.PartType.Cylinder)
		end
	elseif id == "PlateMail" then
		tier = 5
		local steel = Color3.fromRGB(190, 190, 186)
		wear(folder, torso, "Breastplate", ts + Vector3.new(0.3, 0.1, 0.35), CFrame.new(0, 0.05, 0), steel, metal)
		wear(folder, torso, "Ridge", Vector3.new(0.18, ts.Y * 0.8, 0.2), CFrame.new(0, 0.05, -ts.Z / 2 - 0.2), Color3.fromRGB(210, 210, 206), metal)
		wear(folder, torso, "Tabard", Vector3.new(ts.X * 0.55, ts.Y * 1.3, 0.08), CFrame.new(0, -0.6, -ts.Z / 2 - 0.25), Color3.fromRGB(96, 30, 34), Enum.Material.Fabric)
		if lower and lower ~= torso then
			wear(folder, lower, "Tassets", lower.Size + Vector3.new(0.35, 0.25, 0.35), CFrame.new(0, -0.15, 0), steel, metal)
		end
		shoulders(steel, 1.3, metal)
		for _, arm in { lArm, rArm } do
			if arm then
				wear(folder, arm, "Rerebrace", arm.Size + Vector3.new(0.15, -0.1, 0.15), CFrame.new(0, -0.1, 0), steel, metal)
			end
		end
		bracers(steel, metal)
		greaves(steel, metal)
		if head then
			setHood(false)
			wear(folder, head, "GreatHelm", head.Size * Vector3.new(1.22, 1.25, 1.22), CFrame.new(0, 0.08, 0), steel, metal)
			wear(folder, head, "Visor", Vector3.new(head.Size.X * 0.9, 0.12, 0.1), CFrame.new(0, 0.12, -head.Size.Z * 0.62), Color3.fromRGB(10, 10, 12), Enum.Material.SmoothPlastic)
			wear(folder, head, "Crest", Vector3.new(0.14, 0.4, head.Size.Z * 1.1), CFrame.new(0, head.Size.Y * 0.72, 0), Color3.fromRGB(96, 30, 34), Enum.Material.Fabric)
		end
	end

	-- Enchanted armor is etched with glowing runes; more bonus, more runes.
	local b = bonus or 0
	if b > 0 then
		for i = 1, math.min(b, 4) do
			local y = ts.Y / 2 - 0.4 - (i - 1) * 0.45
			local r = wear(folder, torso, "Rune", Vector3.new(0.6, 0.1, 0.08), CFrame.new(0, y, -ts.Z / 2 - 0.22) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 20 else -20)), RUNE, Enum.Material.Neon)
			if r and i == 1 then
				local l = Instance.new("PointLight")
				l.Color = RUNE
				l.Range = 5 + b * 1.5
				l.Brightness = 0.5 + b * 0.2
				l.Shadows = false
				l.Parent = r
			end
		end
		if b >= 3 then
			sparkles(torso, RUNE, 3)
		end
	end

	-- Experience shows on the cloak: trim at level 4, crimson and gold at 7.
	local lv = level or 1
	local cloak = character:FindFirstChild("Cloak") :: BasePart?
	if cloak then
		cloak.Color = if lv >= 7 then Color3.fromRGB(110, 26, 30) else Color3.fromRGB(70, 36, 34)
		if lv >= 4 then
			local trim = part(folder, "CloakTrim", Vector3.new(cloak.Size.X + 0.05, 0.18, cloak.Size.Z + 0.04), cloak.CFrame * CFrame.new(0, -cloak.Size.Y / 2 + 0.1, 0), BRASS, metal)
			local w = Instance.new("WeldConstraint")
			w.Part0 = cloak
			w.Part1 = trim
			w.Parent = trim
		end
		if lv >= 10 then
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120))
			e.LightEmission = 1
			e.Size = NumberSequence.new(0.15)
			e.Lifetime = NumberRange.new(1, 1.6)
			e.Rate = 4
			e.Speed = NumberRange.new(0.3, 0.8)
			e.Parent = cloak
		end
	end
	return tier
end

return Gear
