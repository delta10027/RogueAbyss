--!strict
-- Player-facing facts about each monster: its name in messages, experience,
-- gold drops, the first dungeon level it appears on and how it is placed.
-- Behaviour lives in ServerScriptService.Server.Creatures.

export type MonsterInfo = {
	Id: string,
	Name: string, -- lower case, used in messages ("You hit the rat.")
	Exp: number,
	GoldChance: number,
	Gold: { number }, -- min, max
	MinDepth: number,
	Pack: { number }?, -- min, max group size
}

local Monsters: { [string]: MonsterInfo } = {
	Rat = { Id = "Rat", Name = "giant rat", Exp = 2, GoldChance = 0.15, Gold = { 2, 6 }, MinDepth = 1, Pack = { 2, 3 } },
	Kobold = { Id = "Kobold", Name = "kobold", Exp = 4, GoldChance = 0.45, Gold = { 4, 12 }, MinDepth = 1 },
	Bat = { Id = "Bat", Name = "bat", Exp = 3, GoldChance = 0.1, Gold = { 2, 6 }, MinDepth = 2, Pack = { 1, 2 } },
	Slime = { Id = "Slime", Name = "slime", Exp = 4, GoldChance = 0.3, Gold = { 3, 9 }, MinDepth = 2 },
	Zombie = { Id = "Zombie", Name = "zombie", Exp = 8, GoldChance = 0.5, Gold = { 8, 20 }, MinDepth = 3 },
	Skeleton = { Id = "Skeleton", Name = "skeleton", Exp = 9, GoldChance = 0.5, Gold = { 8, 22 }, MinDepth = 3 },
	Orc = { Id = "Orc", Name = "orc", Exp = 14, GoldChance = 0.7, Gold = { 15, 35 }, MinDepth = 5 },
	Wraith = { Id = "Wraith", Name = "wraith", Exp = 14, GoldChance = 0.4, Gold = { 10, 30 }, MinDepth = 6 },
	Listener = { Id = "Listener", Name = "Listener", Exp = 7, GoldChance = 0.4, Gold = { 6, 16 }, MinDepth = 1 },
	Watcher = { Id = "Watcher", Name = "Watcher", Exp = 0, GoldChance = 0, Gold = { 0, 0 }, MinDepth = 2 },
}

-- Elite monsters get a prefix ("You hit the hulking zombie").
local ELITE_PREFIXES = { "hulking", "frenzied", "ancient", "savage", "bloated", "cursed" }

return setmetatable(Monsters, {
	__index = {
		ElitePrefixes = ELITE_PREFIXES,
	},
}) :: any
