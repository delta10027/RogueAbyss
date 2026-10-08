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
	MaxVigor = 5,
	WalkSpeed = 14,
	CreepSpeed = 7,
	InventorySlots = 4,
	InvulnerableAfterHit = 1.2,
}

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
	Damage = 2,
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
	Damage = 1,
	Health = 3,
	SearchDuration = 7,
	LightLureRadius = 46, -- Hungry Dark rule only
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
	Radius = 9,
	Duration = 14,
	LightRange = 24,
}

Config.Interaction = {
	MaxDistance = 11,
	RateLimitPerSecond = 8,
}

return Config
