--!strict
-- Ordinary dungeon monsters. They share senses and movement, but each one
-- fights differently so every encounter asks for a different answer:
--
--   Rat       fast pack hunter: bites, then darts back out and circles
--   Kobold    keeps its distance and throws spears; stabs if you close in
--   Bat       flutters erratically, then dive-bombs in a straight line
--   Slime     hops toward you; splits into two small slimes when killed
--   Zombie    slow; a telegraphed area slam, then it is left exposed
--   Skeleton  blocks frontal light hits with its shield (flank it, charge
--             a heavy attack, use a mace or magic)
--   Orc       charges in a straight line; slams into walls and is dazed
--   Wraith    only visible and hurtable inside light
--
-- Monsters see the player only within the lantern's reach + 6 studs and
-- with a clear line of sight, so dimming the lantern and sneaking matter.
-- Every attack is telegraphed (Effect "Telegraph") and can be dodged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Body = require(script.Parent.Body)

local Beast = {}

local LOSE_TIME = 4
local SEARCH_TIME = 6

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

---------------------------------------------------------------------------
-- Bodies (part-built silhouettes, readable from the top-down camera)
---------------------------------------------------------------------------

local BUILDERS: { [string]: (any, number) -> { [string]: any } } = {}

local function eyes(parts, s: number, y: number, z: number, spread: number, color: Color3, size: number?)
	local sz = (size or 0.18) * s
	for _, x in { -spread, spread } do
		Body.Piece(parts, { Name = "Eye", Size = Vector3.new(sz, sz, sz), Color = color, Material = Enum.Material.Neon, Shape = Enum.PartType.Ball }, CFrame.new(x * s, y * s, z * s))
	end
end

BUILDERS.Rat = function(parts, s)
	local fur = Color3.fromRGB(78, 66, 58)
	Body.Piece(parts, { Name = "Body", Size = Vector3.new(1.4, 1, 2.6) * s, Color = fur, Material = Enum.Material.Fabric }, CFrame.new(0, -0.3 * s, 0.2 * s))
	Body.Piece(parts, { Name = "Head", Size = Vector3.new(0.9, 0.8, 1.2) * s, Color = fur, Material = Enum.Material.Fabric }, CFrame.new(0, -0.2 * s, -1.5 * s))
	Body.Piece(parts, { Name = "Snout", Size = Vector3.new(0.4, 0.4, 0.5) * s, Color = Color3.fromRGB(150, 110, 104), Material = Enum.Material.SmoothPlastic }, CFrame.new(0, -0.3 * s, -2.2 * s))
	Body.Piece(parts, { Name = "EarL", Size = Vector3.new(0.4, 0.5, 0.1) * s, Color = Color3.fromRGB(130, 96, 90), Material = Enum.Material.SmoothPlastic }, CFrame.new(-0.35 * s, 0.25 * s, -1.4 * s))
	Body.Piece(parts, { Name = "EarR", Size = Vector3.new(0.4, 0.5, 0.1) * s, Color = Color3.fromRGB(130, 96, 90), Material = Enum.Material.SmoothPlastic }, CFrame.new(0.35 * s, 0.25 * s, -1.4 * s))
	Body.Piece(parts, { Name = "Tail", Size = Vector3.new(0.15, 0.15, 2.4) * s, Color = Color3.fromRGB(150, 110, 104), Material = Enum.Material.SmoothPlastic }, CFrame.new(0, -0.5 * s, 2.6 * s) * CFrame.Angles(0, math.rad(15), 0))
	eyes(parts, s, -0.05, -1.95, 0.25, Color3.fromRGB(200, 60, 50), 0.14)
	return {}
end

BUILDERS.Kobold = function(parts, s)
	local skin = Color3.fromRGB(96, 84, 60)
	local rag = Color3.fromRGB(70, 52, 40)
	Body.Piece(parts, { Name = "Body", Size = Vector3.new(1.6, 2, 1.2) * s, Color = rag, Material = Enum.Material.Fabric }, CFrame.new(0, -0.3 * s, 0))
	Body.Piece(parts, { Name = "Head", Size = Vector3.new(1.2, 1, 1.5) * s, Color = skin, Material = Enum.Material.Slate }, CFrame.new(0, 1.2 * s, -0.3 * s))
	Body.Piece(parts, { Name = "HornL", Size = Vector3.new(0.2, 0.7, 0.2) * s, Color = Color3.fromRGB(170, 160, 140), Material = Enum.Material.SmoothPlastic }, CFrame.new(-0.4 * s, 1.9 * s, 0) * CFrame.Angles(math.rad(-30), 0, math.rad(15)))
	Body.Piece(parts, { Name = "HornR", Size = Vector3.new(0.2, 0.7, 0.2) * s, Color = Color3.fromRGB(170, 160, 140), Material = Enum.Material.SmoothPlastic }, CFrame.new(0.4 * s, 1.9 * s, 0) * CFrame.Angles(math.rad(-30), 0, math.rad(-15)))
	Body.Piece(parts, { Name = "LegL", Size = Vector3.new(0.5, 1.2, 0.5) * s, Color = skin, Material = Enum.Material.Slate }, CFrame.new(-0.45 * s, -1.7 * s, 0))
	Body.Piece(parts, { Name = "LegR", Size = Vector3.new(0.5, 1.2, 0.5) * s, Color = skin, Material = Enum.Material.Slate }, CFrame.new(0.45 * s, -1.7 * s, 0))
	local _, spear = Body.Piece(parts, { Name = "Spear", Size = Vector3.new(0.2, 0.2, 4.5) * s, Color = Color3.fromRGB(110, 86, 60), Material = Enum.Material.Wood }, CFrame.new(1 * s, 0.2 * s, -0.8 * s))
	Body.Piece(parts, { Name = "Tip", Size = Vector3.new(0.3, 0.3, 0.6) * s, Color = Color3.fromRGB(140, 136, 128), Material = Enum.Material.Metal }, CFrame.new(1 * s, 0.2 * s, -3.3 * s))
	eyes(parts, s, 1.3, -1.05, 0.28, Color3.fromRGB(230, 190, 80), 0.15)
	return { Weapon = spear }
end

BUILDERS.Bat = function(parts, s)
	local hide = Color3.fromRGB(52, 44, 44)
	Body.Piece(parts, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2) * s, Color = hide, Material = Enum.Material.Fabric }, CFrame.new())
	Body.Piece(parts, { Name = "EarL", Size = Vector3.new(0.25, 0.5, 0.1) * s, Color = hide, Material = Enum.Material.Fabric }, CFrame.new(-0.3 * s, 0.7 * s, -0.2 * s))
	Body.Piece(parts, { Name = "EarR", Size = Vector3.new(0.25, 0.5, 0.1) * s, Color = hide, Material = Enum.Material.Fabric }, CFrame.new(0.3 * s, 0.7 * s, -0.2 * s))
	local _, wl = Body.Piece(parts, { Name = "WingL", Size = Vector3.new(2.6, 0.1, 1.4) * s, Color = Color3.fromRGB(70, 58, 58), Material = Enum.Material.Fabric }, CFrame.new(-1.7 * s, 0, 0))
	local _, wr = Body.Piece(parts, { Name = "WingR", Size = Vector3.new(2.6, 0.1, 1.4) * s, Color = Color3.fromRGB(70, 58, 58), Material = Enum.Material.Fabric }, CFrame.new(1.7 * s, 0, 0))
	eyes(parts, s, 0.15, -0.55, 0.2, Color3.fromRGB(220, 70, 60), 0.14)
	local info = TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(wl, info, { C0 = CFrame.new(-1.3 * s, 0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(-40)) }):Play()
	TweenService:Create(wr, info, { C0 = CFrame.new(1.3 * s, 0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(40)) }):Play()
	return {}
end

BUILDERS.Slime = function(parts, s)
	local gel = Color3.fromRGB(96, 150, 70)
	local _, body = Body.Piece(parts, { Name = "Gel", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 2.2, 3) * s, Color = gel, Material = Enum.Material.Glass, Transparency = 0.35 }, CFrame.new(0, -0.2 * s, 0))
	Body.Piece(parts, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * s, Color = Color3.fromRGB(60, 100, 40), Material = Enum.Material.SmoothPlastic }, CFrame.new(0, -0.2 * s, 0))
	Body.Piece(parts, { Name = "Bone", Size = Vector3.new(0.2, 0.2, 1) * s, Color = Color3.fromRGB(190, 180, 160), Material = Enum.Material.SmoothPlastic }, CFrame.new(0.5 * s, 0, 0.3 * s) * CFrame.Angles(0.5, 0.8, 0))
	eyes(parts, s, 0.3, -1.25, 0.35, Color3.fromRGB(230, 240, 180), 0.2)
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(body, info, { C0 = CFrame.new(0, -0.35 * s, 0) }):Play()
	return {}
end

BUILDERS.Zombie = function(parts, s)
	local flesh = Color3.fromRGB(104, 112, 88)
	local cloth = Color3.fromRGB(56, 50, 46)
	Body.Piece(parts, { Name = "Torso", Size = Vector3.new(2.2, 2.4, 1.2) * s, Color = cloth, Material = Enum.Material.Fabric }, CFrame.new(0, 0.3 * s, 0) * CFrame.Angles(math.rad(-12), 0, 0))
	Body.Piece(parts, { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2) * s, Color = flesh, Material = Enum.Material.Slate }, CFrame.new(0.2 * s, 2 * s, -0.4 * s) * CFrame.Angles(0, 0, math.rad(14)))
	Body.Piece(parts, { Name = "LegL", Size = Vector3.new(0.8, 2.2, 0.8) * s, Color = cloth, Material = Enum.Material.Fabric }, CFrame.new(-0.55 * s, -2 * s, 0))
	Body.Piece(parts, { Name = "LegR", Size = Vector3.new(0.8, 2.2, 0.8) * s, Color = cloth, Material = Enum.Material.Fabric }, CFrame.new(0.55 * s, -2 * s, 0))
	local _, al = Body.Piece(parts, { Name = "ArmL", Size = Vector3.new(0.6, 0.6, 2.4) * s, Color = flesh, Material = Enum.Material.Slate }, CFrame.new(-1.4 * s, 1 * s, -1.2 * s))
	local _, ar = Body.Piece(parts, { Name = "ArmR", Size = Vector3.new(0.6, 0.6, 2.4) * s, Color = flesh, Material = Enum.Material.Slate }, CFrame.new(1.4 * s, 1 * s, -1.2 * s))
	eyes(parts, s, 2.1, -1.0, 0.25, Color3.fromRGB(190, 210, 120), 0.14)
	return { ArmL = al, ArmR = ar }
end

BUILDERS.Skeleton = function(parts, s)
	local bone = Color3.fromRGB(200, 192, 170)
	local iron = Color3.fromRGB(96, 92, 88)
	Body.Piece(parts, { Name = "Skull", Size = Vector3.new(1, 1.1, 1.1) * s, Color = bone, Material = Enum.Material.SmoothPlastic }, CFrame.new(0, 1.9 * s, 0))
	Body.Piece(parts, { Name = "Jaw", Size = Vector3.new(0.8, 0.3, 0.8) * s, Color = bone, Material = Enum.Material.SmoothPlastic }, CFrame.new(0, 1.25 * s, -0.1 * s))
	Body.Piece(parts, { Name = "Spine", Size = Vector3.new(0.3, 2, 0.3) * s, Color = bone, Material = Enum.Material.SmoothPlastic }, CFrame.new(0, 0.3 * s, 0.2 * s))
	for i = 0, 3 do
		Body.Piece(parts, { Name = "Rib", Size = Vector3.new(1.6 - i * 0.15, 0.16, 0.9) * s, Color = bone, Material = Enum.Material.SmoothPlastic }, CFrame.new(0, (1 - i * 0.35) * s, 0))
	end
	Body.Piece(parts, { Name = "Pelvis", Size = Vector3.new(1.2, 0.4, 0.6) * s, Color = bone, Material = Enum.Material.SmoothPlastic }, CFrame.new(0, -0.8 * s, 0))
	Body.Piece(parts, { Name = "LegL", Size = Vector3.new(0.25, 2.2, 0.25) * s, Color = bone, Material = Enum.Material.SmoothPlastic }, CFrame.new(-0.4 * s, -2 * s, 0))
	Body.Piece(parts, { Name = "LegR", Size = Vector3.new(0.25, 2.2, 0.25) * s, Color = bone, Material = Enum.Material.SmoothPlastic }, CFrame.new(0.4 * s, -2 * s, 0))
	-- Round shield on the left arm, rusted sword on the right.
	local _, shield = Body.Piece(parts, { Name = "Shield", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 2.2, 2.2) * s, Color = iron, Material = Enum.Material.CorrodedMetal }, CFrame.new(-0.9 * s, 0.4 * s, -0.9 * s) * CFrame.Angles(0, math.rad(90), 0))
	Body.Piece(parts, { Name = "Boss", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5) * s, Color = Color3.fromRGB(150, 130, 90), Material = Enum.Material.Metal }, CFrame.new(-0.9 * s, 0.4 * s, -1.05 * s))
	local _, sword = Body.Piece(parts, { Name = "Sword", Size = Vector3.new(0.12, 0.3, 3) * s, Color = Color3.fromRGB(140, 120, 100), Material = Enum.Material.CorrodedMetal }, CFrame.new(1 * s, 0.4 * s, -1.4 * s))
	eyes(parts, s, 1.95, -0.52, 0.22, Color3.fromRGB(120, 200, 255), 0.16)
	return { Weapon = sword, Shield = shield }
end

BUILDERS.Orc = function(parts, s)
	local skin = Color3.fromRGB(86, 100, 70)
	local hide = Color3.fromRGB(70, 50, 36)
	Body.Piece(parts, { Name = "Torso", Size = Vector3.new(3, 2.6, 1.8) * s, Color = skin, Material = Enum.Material.Slate }, CFrame.new(0, 0.4 * s, 0) * CFrame.Angles(math.rad(-10), 0, 0))
	Body.Piece(parts, { Name = "Belly", Size = Vector3.new(2.6, 1.2, 1.6) * s, Color = hide, Material = Enum.Material.Leather }, CFrame.new(0, -0.9 * s, 0))
	Body.Piece(parts, { Name = "Head", Size = Vector3.new(1.4, 1.2, 1.4) * s, Color = skin, Material = Enum.Material.Slate }, CFrame.new(0, 2.1 * s, -0.5 * s))
	Body.Piece(parts, { Name = "TuskL", Size = Vector3.new(0.18, 0.5, 0.18) * s, Color = Color3.fromRGB(220, 210, 180), Material = Enum.Material.SmoothPlastic }, CFrame.new(-0.35 * s, 1.75 * s, -1.2 * s))
	Body.Piece(parts, { Name = "TuskR", Size = Vector3.new(0.18, 0.5, 0.18) * s, Color = Color3.fromRGB(220, 210, 180), Material = Enum.Material.SmoothPlastic }, CFrame.new(0.35 * s, 1.75 * s, -1.2 * s))
	Body.Piece(parts, { Name = "ShoulderL", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.1, 1.3) * s, Color = Color3.fromRGB(80, 70, 60), Material = Enum.Material.CorrodedMetal }, CFrame.new(-1.7 * s, 1.4 * s, 0))
	Body.Piece(parts, { Name = "ShoulderR", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.1, 1.3) * s, Color = Color3.fromRGB(80, 70, 60), Material = Enum.Material.CorrodedMetal }, CFrame.new(1.7 * s, 1.4 * s, 0))
	Body.Piece(parts, { Name = "LegL", Size = Vector3.new(1, 2, 1) * s, Color = hide, Material = Enum.Material.Leather }, CFrame.new(-0.7 * s, -2.3 * s, 0))
	Body.Piece(parts, { Name = "LegR", Size = Vector3.new(1, 2, 1) * s, Color = hide, Material = Enum.Material.Leather }, CFrame.new(0.7 * s, -2.3 * s, 0))
	local _, club = Body.Piece(parts, { Name = "Club", Size = Vector3.new(0.8, 0.8, 3.4) * s, Color = Color3.fromRGB(80, 60, 44), Material = Enum.Material.Wood }, CFrame.new(1.9 * s, 0.4 * s, -1.6 * s))
	eyes(parts, s, 2.2, -1.2, 0.3, Color3.fromRGB(255, 140, 60), 0.18)
	return { Weapon = club }
end

BUILDERS.Wraith = function(parts, s)
	local shroud = Color3.fromRGB(26, 24, 30)
	Body.Piece(parts, { Name = "Shroud", Size = Vector3.new(2.4, 4.2, 1.6) * s, Color = shroud, Material = Enum.Material.Fabric, Transparency = 0.15 }, CFrame.new(0, 0, 0))
	Body.Piece(parts, { Name = "Tatters", Size = Vector3.new(2.8, 1.2, 2) * s, Color = shroud, Material = Enum.Material.Fabric, Transparency = 0.4 }, CFrame.new(0, -2.4 * s, 0))
	Body.Piece(parts, { Name = "Hood", Size = Vector3.new(1.6, 1.7, 1.6) * s, Color = Color3.fromRGB(18, 16, 22), Material = Enum.Material.Fabric }, CFrame.new(0, 2.6 * s, -0.1 * s))
	local _, al = Body.Piece(parts, { Name = "ArmL", Size = Vector3.new(0.4, 0.4, 2.8) * s, Color = shroud, Material = Enum.Material.Fabric }, CFrame.new(-1.3 * s, 0.8 * s, -1.2 * s))
	local _, ar = Body.Piece(parts, { Name = "ArmR", Size = Vector3.new(0.4, 0.4, 2.8) * s, Color = shroud, Material = Enum.Material.Fabric }, CFrame.new(1.3 * s, 0.8 * s, -1.2 * s))
	eyes(parts, s, 2.6, -0.82, 0.28, Color3.fromRGB(200, 230, 255), 0.2)
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(40, 36, 50))
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 2.5) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime = NumberRange.new(1, 1.6)
	mist.Rate = 8
	mist.Speed = NumberRange.new(0.5, 1)
	mist.Parent = parts.Root
	return { ArmL = al, ArmR = ar }
end

local ROOT_SIZE = {
	Rat = Vector3.new(1.4, 1.4, 2.6),
	Bat = Vector3.new(1.4, 1.4, 1.4),
	Slime = Vector3.new(2.6, 2.2, 2.6),
	Zombie = Vector3.new(2.2, 3.2, 1.4),
	Skeleton = Vector3.new(1.6, 3, 1.2),
	Orc = Vector3.new(3, 3.6, 2),
	Wraith = Vector3.new(2, 4, 1.6),
	Kobold = Vector3.new(1.6, 2.6, 1.2),
}
local HIP = {
	Rat = 0.2, Bat = 4.5, Slime = 0.1, Zombie = 1.6, Skeleton = 1.7, Orc = 1.7, Wraith = 2.2, Kobold = 1.2,
}

function Beast.Build(parent: Instance, pos: Vector3, kind: string, opts: any?)
	local cfg = Config.Beasts[kind]
	local s = cfg.Size * ((opts and opts.Scale) or 1)
	local parts = Body.Root(kind, parent, pos, ROOT_SIZE[kind] * s, HIP[kind] * s)
	local welds = BUILDERS[kind](parts, s)
	parts.Humanoid.WalkSpeed = cfg.WanderSpeed
	Body.ServerOwn(parts.Root)
	local w = {}
	for k, v in welds do
		w[k] = v
		w[k .. "0"] = v.C0
	end
	return {
		Kind = kind,
		Model = parts.Model,
		Root = parts.Root,
		Humanoid = parts.Humanoid,
		Cfg = cfg,
		Welds = w,
		Radius = math.max(ROOT_SIZE[kind].X, ROOT_SIZE[kind].Z) * s * 0.5,
		Health = cfg.Health,
		State = "Idle",
		StateTime = 0,
		Target = nil :: Vector3?,
		NextWander = math.random() * 3,
		LastSeen = 0,
		LastAttack = 0,
		NextSpecial = os.clock() + 2 + math.random() * 2,
		Jitter = Vector3.zero,
		NextJitter = 0,
		Small = opts and opts.Small or false,
	}
end

local function setState(cr, state: string, target: Vector3?)
	cr.State = state
	cr.StateTime = 0
	if target then
		cr.Target = target
	end
	cr.Model:SetAttribute("State", state)
end

-- Raised weapon / arms: every attack is telegraphed.
local function pose(cr, alert: number)
	local w = cr.Welds
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad)
	if w.Weapon then
		TweenService:Create(w.Weapon, info, { C0 = w.Weapon0 * CFrame.new(0, alert * 0.8, alert * 1.2) * CFrame.Angles(math.rad(35 * alert), 0, 0) }):Play()
	end
	if w.ArmL then
		TweenService:Create(w.ArmL, info, { C0 = w.ArmL0 * CFrame.new(0, alert * 1.2, alert * 0.4) * CFrame.Angles(math.rad(50 * alert), 0, 0) }):Play()
		TweenService:Create(w.ArmR, info, { C0 = w.ArmR0 * CFrame.new(0, alert * 1.2, alert * 0.4) * CFrame.Angles(math.rad(50 * alert), 0, 0) }):Play()
	end
end

local function face(cr, at: Vector3)
	local look = Vector3.new(at.X, cr.Root.Position.Y, at.Z)
	if (look - cr.Root.Position).Magnitude > 0.5 and not cr.Root.Anchored then
		cr.Root.CFrame = CFrame.lookAt(cr.Root.Position, look)
	end
end

local function stopMoving(cr)
	cr.Route = nil
	cr.RouteGoal = nil
	if not cr.Root.Anchored then
		cr.Humanoid:MoveTo(cr.Root.Position)
	end
end

local function telegraph(run, cr, radius: number, time: number, shape: string)
	Remotes.Effect:FireClient(run.Player, {
		Kind = "Telegraph",
		Pos = cr.Root.Position,
		Creature = cr.Kind,
		Radius = radius,
		Time = time,
		Shape = shape,
		Dir = flat(cr.Root.CFrame.LookVector),
		Model = cr.Model,
	})
end

-- Can this monster see the player right now?
local function seesPlayer(cr, run, ctx, root: BasePart): boolean
	local d = (root.Position - cr.Root.Position).Magnitude
	if d < 3.5 then
		return true
	end
	local reach = ctx.LanternRange(run) + 6
	local sight = cr.Cfg.Sight
	if cr.Kind == "Bat" and not run.PS.Dim and run.PS.Fuel > 0 then
		sight *= 1.5 -- bats are drawn to a bright lantern
	elseif cr.Kind == "Wraith" then
		reach = sight -- wraiths see in the dark
	end
	local limit = math.min(sight, reach) * math.max(0.3, 1 + ctx.Mod(run, "DetectMult")) * (if cr.Elite then 1.2 else 1)
	if run.PS.Creep then
		limit *= 0.6
	end
	if d > limit then
		return false
	end
	return ctx.LineOfSight(run, cr.Root.Position + Vector3.new(0, 1, 0), root.Position + Vector3.new(0, 1, 0))
end

local BUSY = { Chase = true, Windup = true, Recover = true, Dead = true, Stagger = true, Retreat = true, Charge = true, Dive = true }

function Beast.OnNoise(cr, _run, noise, _ctx)
	if cr.Cfg.Hearing <= 0 or BUSY[cr.State] then
		return
	end
	local dist = (noise.Pos - cr.Root.Position).Magnitude
	if dist <= noise.Radius * cr.Cfg.Hearing then
		setState(cr, "Investigate", noise.Pos)
	end
end

-- Returns the damage actually dealt (0 when blocked or immune).
function Beast.OnStruck(cr, run, damage: number, fromPos: Vector3, ctx, hit): number
	if cr.State == "Dead" then
		return 0
	end
	hit = hit or {}
	local now = os.clock()
	local toAttacker = flat(fromPos - cr.Root.Position)
	local facing = flat(cr.Root.CFrame.LookVector)

	-- Wraiths are only solid inside light (spells always reach them).
	if cr.Kind == "Wraith" and hit.Source ~= "Spell" and not ctx.Lit(run, cr.Root.Position) then
		hit.Immune = true
		if now - (cr.LastImmuneMsg or 0) > 3 then
			cr.LastImmuneMsg = now
			ctx.Message(run, "Your weapon passes straight through the wraith! Hit it while it's in your light.")
		end
		return 0
	end
	-- Skeletons block light melee hits from the front.
	if cr.Kind == "Skeleton" and hit.Source == "Melee" and not hit.Heavy and hit.Weapon ~= "Mace" and not hit.Backstabbed
		and not ctx.Disabled(cr) and toAttacker.Magnitude > 0.1 and facing.Magnitude > 0.01 and facing.Unit:Dot(toAttacker.Unit) > 0.3 then
		hit.Blocked = true
		ctx.Blocked(run, cr)
		cr.LastAttack = 0 -- a block leaves it ready to strike back
		return 0
	end

	if cr.Exposed and now < cr.Exposed then
		damage *= 1.5
	end
	cr.Health -= damage
	if cr.Health <= 0 then
		cr.State = "Dead"
		ctx.Kill(run, cr)
		return damage
	end
	-- Heavy monsters shrug off small hits; light ones get knocked about.
	local knock = (hit.Knockback or 12) * (if cr.Kind == "Orc" or cr.Kind == "Zombie" then 0.35 else 1)
	if not hit.NoKnockback and toAttacker.Magnitude > 0.1 and knock > 0 and not cr.Root.Anchored then
		cr.Root.AssemblyLinearVelocity = -toAttacker.Unit * knock + Vector3.new(0, 3, 0)
	end
	-- Heavy hits and finishers interrupt; ordinary hits only interrupt small monsters.
	local small = cr.Kind == "Rat" or cr.Kind == "Bat" or cr.Kind == "Kobold" or cr.Kind == "Slime"
	if (hit.Heavy or hit.Finisher or small) and cr.State ~= "Charge" then
		pose(cr, 0)
		setState(cr, "Stagger", fromPos)
	elseif not BUSY[cr.State] then
		setState(cr, "Chase", fromPos)
		cr.LastSeen = now
		cr.LastSeenPos = fromPos
	end
	return damage
end

---------------------------------------------------------------------------
-- Attacks
---------------------------------------------------------------------------

local function startWindup(run, cr, kind: string, time: number, radius: number, shape: string)
	stopMoving(cr)
	cr.AttackKind = kind
	cr.WindupTime = time
	setState(cr, "Windup")
	pose(cr, 1)
	telegraph(run, cr, radius, time, shape)
end

local function damageAt(run, cr, ctx, root: BasePart, reach: number, amount: number, arcDot: number?): boolean
	local to = flat(root.Position - cr.Root.Position)
	if to.Magnitude > reach or ctx.InSafeRoom(run, root.Position) then
		return false
	end
	if arcDot and to.Magnitude > 1.5 then
		local facing = flat(cr.Root.CFrame.LookVector)
		if facing.Magnitude > 0.01 and facing.Unit:Dot(to.Unit) < arcDot then
			return false
		end
	end
	ctx.DamagePlayer(run, amount, cr.Kind, cr.Root.Position, cr)
	return true
end

-- Called when a windup completes.
local function release(run, cr, ctx, root: BasePart?)
	local cfg = cr.Cfg
	local dmg = cfg.Damage * (cr.DamageMult or 1)
	local kind = cr.AttackKind
	cr.LastAttack = os.clock()
	pose(cr, 0.2)
	if not root then
		setState(cr, "Recover")
		return
	end
	if kind == "Slam" then
		-- Zombie: a ring around itself, then it is left exposed.
		local hitIt = damageAt(run, cr, ctx, root, cfg.Reach, dmg)
		Remotes.Effect:FireClient(run.Player, { Kind = "Slam", Pos = cr.Root.Position, Radius = cfg.Reach })
		cr.Exposed = os.clock() + 1.4
		cr.Model:SetAttribute("Exposed", true)
		task.delay(1.4, function()
			if cr.Model.Parent then
				cr.Model:SetAttribute("Exposed", false)
			end
		end)
		if not hitIt then
			ctx.Message(run, "The " .. ctx.MonsterName(cr) .. " slams the ground and misses. It's exposed!")
		end
		setState(cr, "Recover")
		cr.RecoverTime = 1.4
	elseif kind == "Throw" then
		local target = root.Position + flat(root.AssemblyLinearVelocity) * 0.25
		local dir = flat(target - cr.Root.Position)
		if dir.Magnitude > 0.1 then
			ctx.Projectile(run, cr, cr.Root.Position + Vector3.new(0, 1.5, 0), dir.Unit, 48, cfg.ThrowDamage * (cr.DamageMult or 1), "Spear")
		end
		setState(cr, "Recover")
		cr.RecoverTime = 0.5
	elseif kind == "Charge" then
		local dir = flat(root.Position - cr.Root.Position)
		cr.ChargeDir = if dir.Magnitude > 0.1 then dir.Unit else flat(cr.Root.CFrame.LookVector).Unit
		cr.ChargeHit = false
		cr.LastPos = cr.Root.Position
		setState(cr, "Charge")
	elseif kind == "Dive" then
		local dir = flat(root.Position - cr.Root.Position)
		cr.ChargeDir = if dir.Magnitude > 0.1 then dir.Unit else flat(cr.Root.CFrame.LookVector).Unit
		cr.ChargeHit = false
		setState(cr, "Dive")
	else
		-- Plain melee in front.
		if not damageAt(run, cr, ctx, root, cfg.Reach, dmg, -0.2) then
			ctx.Message(run, "The " .. ctx.MonsterName(cr) .. " misses.")
		end
		if cr.Kind == "Rat" then
			setState(cr, "Retreat") -- hit and run
			return
		end
		setState(cr, "Recover")
		cr.RecoverTime = if cr.Kind == "Skeleton" then 0.5 else 0.6
	end
end

-- Decide whether to start an attack this tick while chasing.
local function tryAttack(run, cr, ctx, root: BasePart, d: number, sees: boolean): boolean
	local cfg = cr.Cfg
	local now = os.clock()
	local slow = if now < (cr.SlowUntil or 0) then 2 else 1
	local ready = now - cr.LastAttack > cfg.Cooldown * slow
	if not ready or ctx.InSafeRoom(run, root.Position) then
		return false
	end
	local kind = cr.Kind
	if kind == "Kobold" and sees and d > 8 and d <= cfg.ThrowRange and now > cr.NextSpecial then
		cr.NextSpecial = now + 3 + math.random()
		face(cr, root.Position)
		startWindup(run, cr, "Throw", 0.65 * slow, 3, "Throw")
		return true
	elseif kind == "Orc" and sees and d > 9 and d < 26 and now > cr.NextSpecial then
		cr.NextSpecial = now + 6 + math.random() * 2
		face(cr, root.Position)
		startWindup(run, cr, "Charge", 0.85 * slow, 3, "Line")
		Remotes.Effect:FireClient(run.Player, { Kind = "Roar", Pos = cr.Root.Position })
		return true
	elseif kind == "Bat" then
		if d > 4 and d < 15 and now > cr.NextSpecial then
			cr.NextSpecial = now + 3.5 + math.random()
			face(cr, root.Position)
			startWindup(run, cr, "Dive", cfg.Windup * slow, 2.5, "Line")
			return true
		end
		return false
	elseif kind == "Zombie" and d <= cfg.Reach * 0.85 then
		face(cr, root.Position)
		startWindup(run, cr, "Slam", cfg.Windup * slow, cfg.Reach, "Circle")
		return true
	elseif d <= cfg.Reach * 0.85 then
		face(cr, root.Position)
		startWindup(run, cr, "Melee", cfg.Windup * slow, cfg.Reach, "Arc")
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- Tick
---------------------------------------------------------------------------

function Beast.Tick(cr, run, dt: number, ctx)
	cr.StateTime += dt
	local cfg = cr.Cfg
	local root = ctx.PlayerRoot(run)
	local state = cr.State
	if state == "Dead" then
		return
	end
	local now = os.clock()

	-- Wraiths fade unless something lights them.
	if cr.Kind == "Wraith" then
		local lit = ctx.Lit(run, cr.Root.Position)
		if cr.Model:GetAttribute("Lit") ~= lit then
			cr.Model:SetAttribute("Lit", lit)
		end
	end

	local sees = root ~= nil and seesPlayer(cr, run, ctx, root)
	if sees and root then
		cr.LastSeen = now
		cr.LastSeenPos = root.Position
		if state == "Idle" or state == "Wander" or state == "Investigate" or state == "Search" or state == "Return" then
			setState(cr, "Chase", root.Position)
			Remotes.Effect:FireClient(run.Player, { Kind = "Alert", Pos = cr.Root.Position, Creature = cr.Kind, Model = cr.Model })
			ctx.Discover(run, "Creature" .. cr.Kind)
			state = "Chase"
		end
	end

	if state == "Idle" then
		ctx.Stop(cr)
		cr.NextWander -= dt
		if cr.NextWander <= 0 then
			cr.NextWander = 3 + math.random() * 4
			setState(cr, "Wander", ctx.RandomPointNear(run, cr.Home, 9))
		end
	elseif state == "Wander" then
		if ctx.MoveTo(cr, cr.Target, cfg.WanderSpeed) or cr.StateTime > 8 then
			setState(cr, "Idle")
		end
	elseif state == "Investigate" then
		if ctx.MoveTo(cr, cr.Target, cfg.Speed * 0.7) or cr.StateTime > 15 then
			setState(cr, "Search", cr.Target)
		end
	elseif state == "Chase" then
		if not root then
			setState(cr, "Search")
			return
		end
		if now - cr.LastSeen > LOSE_TIME then
			setState(cr, "Search", cr.LastSeenPos)
			return
		end
		local d = flat(root.Position - cr.Root.Position).Magnitude
		if tryAttack(run, cr, ctx, root, d, sees) then
			return
		end
		local goal = if sees then root.Position else (cr.LastSeenPos or root.Position)
		local speed = cfg.Speed
		local away = flat(cr.Root.Position - root.Position)
		if cr.Kind == "Kobold" and sees and d < 7 and now - cr.LastAttack < cfg.Cooldown and away.Magnitude > 0.1 then
			-- Too close and not ready to stab: back off.
			goal = cr.Root.Position + away.Unit * 8
		elseif cr.Kind == "Kobold" and sees and d > 9 and d < cfg.ThrowRange and away.Magnitude > 0.1 then
			-- Hold range: drift sideways instead of closing in.
			local side = away.Unit:Cross(Vector3.yAxis)
			goal = cr.Root.Position + side * (if math.floor(now / 2) % 2 == 0 then 5 else -5)
			speed = cfg.WanderSpeed + 2
		elseif cr.Kind == "Rat" and now - cr.LastAttack < cfg.Cooldown and d < 9 then
			-- Circle while waiting to bite again.
			local around = CFrame.Angles(0, (now * 1.8) % (math.pi * 2), 0):VectorToWorldSpace(Vector3.new(6, 0, 0))
			goal = root.Position + around
		elseif cr.Kind == "Bat" then
			if now > cr.NextJitter then
				cr.NextJitter = now + 0.35
				local a = math.random() * math.pi * 2
				cr.Jitter = Vector3.new(math.cos(a), 0, math.sin(a)) * math.min(6, d * 0.6)
			end
			goal += cr.Jitter
		elseif cr.Kind == "Slime" then
			-- Hops: moves in bursts.
			if (now * 1.6) % 1 > 0.55 then
				ctx.Stop(cr)
				return
			end
			speed = cfg.Speed * 1.6
		end
		if d > 2.2 or cr.Kind == "Rat" or cr.Kind == "Bat" then
			ctx.MoveTo(cr, goal, speed)
		else
			ctx.Stop(cr)
		end
	elseif state == "Windup" then
		if root and cr.AttackKind ~= "Charge" and cr.AttackKind ~= "Dive" then
			face(cr, root.Position)
		end
		if cr.StateTime >= (cr.WindupTime or cfg.Windup) then
			release(run, cr, ctx, root)
		end
	elseif state == "Charge" then
		-- Orc: a straight run that only stops at a wall or the player.
		cr.Humanoid.WalkSpeed = cfg.ChargeSpeed
		cr.Humanoid:Move(cr.ChargeDir, false)
		if root and not cr.ChargeHit and flat(root.Position - cr.Root.Position).Magnitude < 4 then
			cr.ChargeHit = true
			ctx.DamagePlayer(run, cfg.Damage * 1.3 * (cr.DamageMult or 1), cr.Kind, cr.Root.Position, cr)
		end
		local moved = flat(cr.Root.Position - (cr.LastPos or cr.Root.Position)).Magnitude
		cr.LastPos = cr.Root.Position
		if cr.StateTime > 0.25 and moved < cfg.ChargeSpeed * dt * 0.25 then
			-- Slammed into something solid.
			cr.Humanoid:Move(Vector3.zero)
			Remotes.Effect:FireClient(run.Player, { Kind = "Slam", Pos = cr.Root.Position, Radius = 4 })
			ctx.Message(run, "The " .. ctx.MonsterName(cr) .. " crashes into the wall and is dazed!")
			cr.Exposed = now + 2.2
			ctx.Status(run, cr, "Stun", 2.2)
			setState(cr, "Recover")
			cr.RecoverTime = 0.3
		elseif cr.StateTime > 1.3 or cr.ChargeHit then
			cr.Humanoid:Move(Vector3.zero)
			setState(cr, "Recover")
			cr.RecoverTime = 0.8
		end
	elseif state == "Dive" then
		cr.Humanoid.WalkSpeed = 42
		cr.Humanoid:Move(cr.ChargeDir, false)
		if root and not cr.ChargeHit and flat(root.Position - cr.Root.Position).Magnitude < 3.5 then
			cr.ChargeHit = true
			ctx.DamagePlayer(run, cfg.Damage * (cr.DamageMult or 1), cr.Kind, cr.Root.Position, cr)
		end
		if cr.StateTime > 0.45 then
			cr.Humanoid:Move(Vector3.zero)
			setState(cr, "Retreat")
		end
	elseif state == "Retreat" then
		if root then
			local away = flat(cr.Root.Position - root.Position)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
			ctx.MoveTo(cr, cr.Root.Position + away * 8, cfg.Speed)
		end
		if cr.StateTime > 0.8 then
			setState(cr, "Chase")
		end
	elseif state == "Recover" then
		ctx.Stop(cr)
		if cr.StateTime > (cr.RecoverTime or 0.5) then
			pose(cr, 0)
			setState(cr, "Chase")
		end
	elseif state == "Stagger" then
		if cr.StateTime > 0.4 then
			setState(cr, "Chase", if root then root.Position else cr.Target)
			cr.LastSeen = now
			cr.LastSeenPos = if root then root.Position else cr.Root.Position
		end
	elseif state == "Search" then
		if cr.StateTime > SEARCH_TIME then
			setState(cr, "Return", cr.Home)
		elseif not cr.SearchPoint or ctx.MoveTo(cr, cr.SearchPoint, cfg.WanderSpeed + 1) then
			cr.SearchPoint = ctx.RandomPointNear(run, cr.Target or cr.Root.Position, 8)
		end
	elseif state == "Return" then
		if ctx.MoveTo(cr, cr.Home, cfg.WanderSpeed + 1) or cr.StateTime > 30 then
			setState(cr, "Idle")
		end
	end
end

return Beast
