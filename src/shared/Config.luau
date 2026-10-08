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
	InvulnerableAfterHit = 0.9,
	StartWeapon = "Quarterstaff",
	StartArmor = "LeatherArmor",
}

-- Stamina: every attack and dash spends it, so mashing runs dry.
Config.Stamina = {
	Max = 100,
	Regen = 45, -- per second
	RegenDelay = 0.55, -- seconds after spending before it refills
	WindedTime = 1.1, -- locked out of attacks when emptied
	Dash = 22,
	HeavyMultiplier = 2.2,
}

Config.Mana = {
	Base = 30,
	PerLevel = 6,
	Regen = 1.6, -- per second
}

Config.Spells = {
	BaseSlots = 2,
	SlotLevels = { 4, 7, 10 }, -- extra slot at each of these experience levels
	MaxSlots = 5,
	Keys = { "Z", "X", "C", "V", "B" },
}

Config.Crit = {
	Chance = 0.06,
	Multiplier = 1.75,
}

Config.Combo = {
	Window = 0.85, -- seconds after a swing in which the next swing continues the combo
	FinisherMultiplier = 1.6,
	HeavyHold = 0.32, -- seconds the attack button must be held for a heavy attack
	HeavyMultiplier = 2.1,
	BackstabMultiplier = 2.5,
}

-- Monsters grow tougher every level; elites are rarer, larger and deadlier.
Config.Scaling = {
	HealthPerDepth = 0.2,
	DamagePerDepth = 0.12,
	EliteChance = { 0, 0.08, 0.1, 0.12, 0.15, 0.18, 0.2, 0.22 }, -- by depth (last value repeats)
	EliteHealth = 2.3,
	EliteDamage = 1.4,
	EliteExp = 2.5,
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

-- Dungeon monsters (Creatures/Beast.luau). Sight is also limited by how far
-- the player's lantern reaches + 6 studs, so dimming the lantern hides you.
-- Health/damage are depth-1 values; Config.Scaling raises them per level.
Config.Beasts = {
	Rat = { Health = 6, Damage = 2, Speed = 16, WanderSpeed = 6, Sight = 24, Hearing = 1, Windup = 0.35, Reach = 4.5, Cooldown = 1.3, Size = 0.8 },
	Kobold = { Health = 9, Damage = 3, Speed = 12, WanderSpeed = 5, Sight = 30, Hearing = 0.8, Windup = 0.45, Reach = 6, Cooldown = 1.4, Size = 1, ThrowRange = 26, ThrowDamage = 3 },
	Bat = { Health = 5, Damage = 3, Speed = 15, WanderSpeed = 9, Sight = 22, Hearing = 0.6, Windup = 0.5, Reach = 4, Cooldown = 1.6, Size = 0.9 },
	Slime = { Health = 14, Damage = 4, Speed = 9, WanderSpeed = 3, Sight = 18, Hearing = 0.7, Windup = 0.4, Reach = 4.5, Cooldown = 1.2, Size = 1.1 },
	Zombie = { Health = 24, Damage = 8, Speed = 7, WanderSpeed = 3, Sight = 22, Hearing = 1, Windup = 1.0, Reach = 7.5, Cooldown = 2.2, Size = 1.2 },
	Skeleton = { Health = 18, Damage = 6, Speed = 11, WanderSpeed = 4, Sight = 28, Hearing = 0.9, Windup = 0.45, Reach = 6, Cooldown = 1.3, Size = 1.05 },
	Orc = { Health = 34, Damage = 11, Speed = 10, WanderSpeed = 4, Sight = 30, Hearing = 0.9, Windup = 0.75, Reach = 7, Cooldown = 1.8, Size = 1.35, ChargeSpeed = 38 },
	Wraith = { Health = 20, Damage = 7, Speed = 12, WanderSpeed = 5, Sight = 34, Hearing = 0, Windup = 0.6, Reach = 5.5, Cooldown = 1.6, Size = 1.1 },
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
