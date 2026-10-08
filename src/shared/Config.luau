--!strict
-- Tunable constants shared by server and client. No behaviour lives here.

local Config = {}

Config.Debug = true

Config.Grid = {
	SlotSize = 76, -- studs per macro-grid slot
	MinRoom = 24,
	MaxRoom = 48,
	JunctionSize = 16,
	CorridorWidth = 8,
	WallHeight = 10,
	WallThickness = 2,
	DoorWidth = 8,
	RunSpacing = 4000, -- X offset between concurrent per-player dungeons
	FloorY = 0,
}

Config.Player = {
	MaxHealth = 20,
	HealthPerLevel = 4,
	Strength = 16, -- each point above 16 adds 1 melee damage
	WalkSpeed = 14,
	CreepSpeed = 7,
	PackSlots = 12, -- slots 1-4 are the hotbar
	HotbarSlots = 4,
	InvulnerableAfterHit = 0.8,
	StartWeapon = "Quarterstaff",
	StartArmor = "LeatherArmor",
}

-- Experience needed to reach level N (index = level). Rogue doubles each
-- level; this curve is gentler so abilities arrive within a few floors.
Config.Levels = { 0, 8, 20, 36, 56, 80, 110, 150, 200, 260, 330, 410 }
Config.ArmorPerPoint = 0.07
Config.ArmorCap = 0.6
Config.DescendExp = 4

Config.Lantern = {
	MaxFuel = 100,
	DrainPerSecond = 0.6,
	DimDrainMultiplier = 0.25,
	RefillAmount = 60,
	LitRange = 30,
	DimRange = 11,
	EmptyRange = 7,
	LitBrightness = 1.6,
	DimBrightness = 0.7,
	Color = Color3.fromRGB(255, 176, 96),
}

Config.Combat = {
	StrikeRange = 7.5,
	StrikeArcDegrees = 110,
	StrikeCooldown = 0.75,
	StrikeWindup = 0.15,
	StrikeNoise = 22,
	ThrowRange = 42,
}

Config.Noise = {
	WalkRadius = 13,
	CreepRadius = 0,
	DoorRadius = 16,
	BellRadius = 70,
	ShatterRadius = 30,
	WallBreakRadius = 34,
	FootstepInterval = 0.45,
}

Config.Watcher = {
	SightHalfAngle = 65, -- degrees either side of the player's facing
	MoveSpeed = 17,
	StrikeRange = 4.5,
	Damage = 7,
	StrikeCooldown = 1.6,
}

Config.Listener = {
	WanderSpeed = 5,
	InvestigateSpeed = 9,
	PursueSpeed = 12.5,
	AlertRadius = 18, -- noises this close escalate to pursuit
	AttackRange = 5.5,
	AttackWindup = 0.75,
	AttackReach = 7,
	Damage = 4,
	Health = 9,
	SearchDuration = 7,
	LightLureRadius = 46, -- Hungry Dark rule only
}

-- Generic hunters (Creatures/Beast.luau). Sight is also limited by how far
-- the player's lantern reaches + 6, so dimming the lantern hides you.
Config.Beasts = {
	Rat = { Health = 5, Damage = 2, Speed = 15, WanderSpeed = 6, Sight = 24, Hearing = 1, Windup = 0.35, Reach = 4.5, Cooldown = 1.0, Size = 0.8, Fly = false },
	Kobold = { Health = 8, Damage = 3, Speed = 12, WanderSpeed = 5, Sight = 30, Hearing = 0.8, Windup = 0.5, Reach = 6, Cooldown = 1.3, Size = 1, Fly = false },
	Bat = { Health = 4, Damage = 2, Speed = 17, WanderSpeed = 9, Sight = 22, Hearing = 0.6, Windup = 0.25, Reach = 4.5, Cooldown = 1.1, Size = 0.9, Fly = true },
	Zombie = { Health = 18, Damage = 6, Speed = 7.5, WanderSpeed = 3, Sight = 22, Hearing = 1, Windup = 0.9, Reach = 6.5, Cooldown = 1.8, Size = 1.2, Fly = false },
}

Config.Chest = {
	Noise = 18,
}

Config.Tolling = {
	Interval = 24,
	BellGateRadius = 26,
}

Config.Brazier = {
	LightRadius = 22,
	BurnTime = 40,
}

Config.OilFire = {
	Damage = 3,
	Radius = 9,
	Duration = 14,
	LightRange = 24,
}

Config.Interaction = {
	MaxDistance = 11,
	RateLimitPerSecond = 8,
}

return Config
