--!strict
-- Abilities and spells unlocked by reaching experience levels. Each has a
-- cooldown instead of a mana cost. The server checks level and cooldown;
-- the client only asks.

export type AbilityDef = {
	Id: string,
	Name: string,
	Short: string,
	Level: number, -- experience level that unlocks it
	Cooldown: number,
	Key: string, -- keyboard key name, shown in the HUD
	Kind: "Ability" | "Spell",
	Description: string,
}

local list: { AbilityDef } = {
	{
		Id = "Dash", Name = "Dash", Short = "Dash", Level = 2, Cooldown = 3, Key = "Space", Kind = "Ability",
		Description = "Lunge forward. You can't be hurt during the dash. Noisy.",
	},
	{
		Id = "MagicMissile", Name = "Magic Missile", Short = "Msl", Level = 3, Cooldown = 5, Key = "Z", Kind = "Spell",
		Description = "Fire a bolt at your aim point that deals 7 damage to the first monster it hits.",
	},
	{
		Id = "Light", Name = "Light", Short = "Lght", Level = 4, Cooldown = 25, Key = "X", Kind = "Spell",
		Description = "Place a floating light at your aim point for 20 seconds. Counts as firelight: Watchers in it can't move.",
	},
	{
		Id = "SlowMonster", Name = "Slow Monster", Short = "Slow", Level = 5, Cooldown = 20, Key = "C", Kind = "Spell",
		Description = "Monsters within 16 studs move at half speed for 6 seconds.",
	},
	{
		Id = "Teleport", Name = "Blink", Short = "Blnk", Level = 6, Cooldown = 18, Key = "V", Kind = "Spell",
		Description = "Teleport up to 20 studs toward your aim point. Walls stop you.",
	},
}

local byId: { [string]: AbilityDef } = {}
for _, a in list do
	byId[a.Id] = a
end

return {
	List = list,
	ById = byId,
}
