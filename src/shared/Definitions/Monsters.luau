--!strict
-- Player-facing facts about each monster: its name in messages, how much
-- experience it is worth and how often it drops gold. Behaviour lives in
-- ServerScriptService.Server.Creatures.

export type MonsterInfo = {
	Id: string,
	Name: string, -- lower case, used in messages ("You hit the rat.")
	Exp: number,
	GoldChance: number,
	Gold: { number }, -- min, max
}

local Monsters: { [string]: MonsterInfo } = {
	Rat = { Id = "Rat", Name = "giant rat", Exp = 2, GoldChance = 0.15, Gold = { 2, 6 } },
	Kobold = { Id = "Kobold", Name = "kobold", Exp = 3, GoldChance = 0.45, Gold = { 4, 12 } },
	Bat = { Id = "Bat", Name = "bat", Exp = 3, GoldChance = 0.1, Gold = { 2, 6 } },
	Zombie = { Id = "Zombie", Name = "zombie", Exp = 8, GoldChance = 0.5, Gold = { 8, 20 } },
	Listener = { Id = "Listener", Name = "Listener", Exp = 6, GoldChance = 0.4, Gold = { 6, 16 } },
	Watcher = { Id = "Watcher", Name = "Watcher", Exp = 0, GoldChance = 0, Gold = { 0, 0 } },
}

return Monsters
