--!strict
-- Spells. You learn them from spellbooks (or pick one at character
-- creation) and keep them in a limited number of spell slots. Casting costs
-- mana and starts a short cooldown. Behaviour lives in SpellService.
--
-- Glyph strokes (unit square, y down) are drawn as the spell's icon.

export type SpellDef = {
	Id: string,
	Name: string,
	School: "Arcane" | "Fire" | "Frost" | "Storm" | "Shadow" | "Light",
	Mana: number,
	Cooldown: number,
	Starter: boolean, -- can be chosen at character creation
	Rarity: number, -- spellbook weight in loot (higher = more common)
	Color: Color3,
	Description: string,
	Glyph: { { number } },
}

local list: { SpellDef } = {
	{
		Id = "MagicMissile", Name = "Magic Missile", School = "Arcane", Mana = 7, Cooldown = 1.4, Starter = true, Rarity = 3,
		Color = Color3.fromRGB(170, 160, 255),
		Description = "Three bolts that seek the nearest monsters in front of you. 4 damage each.",
		Glyph = { { 0.15, 0.85, 0.85, 0.15 }, { 0.55, 0.15, 0.85, 0.15 }, { 0.85, 0.15, 0.85, 0.45 } },
	},
	{
		Id = "Firebolt", Name = "Firebolt", School = "Fire", Mana = 12, Cooldown = 3, Starter = true, Rarity = 3,
		Color = Color3.fromRGB(255, 140, 60),
		Description = "Hurl a ball of fire that explodes for 10 damage and sets monsters burning.",
		Glyph = { { 0.5, 0.1, 0.25, 0.6 }, { 0.5, 0.1, 0.75, 0.6 }, { 0.25, 0.6, 0.5, 0.9 }, { 0.75, 0.6, 0.5, 0.9 } },
	},
	{
		Id = "FrostNova", Name = "Frost Nova", School = "Frost", Mana = 15, Cooldown = 9, Starter = true, Rarity = 2.5,
		Color = Color3.fromRGB(150, 210, 255),
		Description = "Freeze every monster within 11 studs solid for 2.5 seconds and deal 4 damage.",
		Glyph = { { 0.5, 0.1, 0.5, 0.9 }, { 0.15, 0.3, 0.85, 0.7 }, { 0.15, 0.7, 0.85, 0.3 } },
	},
	{
		Id = "Blink", Name = "Blink", School = "Arcane", Mana = 9, Cooldown = 5, Starter = true, Rarity = 2.5,
		Color = Color3.fromRGB(190, 170, 255),
		Description = "Teleport up to 20 studs toward your aim. Walls stop you.",
		Glyph = { { 0.15, 0.5, 0.4, 0.5 }, { 0.6, 0.5, 0.85, 0.5 }, { 0.7, 0.35, 0.85, 0.5 }, { 0.7, 0.65, 0.85, 0.5 } },
	},
	{
		Id = "ChainLightning", Name = "Chain Lightning", School = "Storm", Mana = 14, Cooldown = 4, Starter = false, Rarity = 2,
		Color = Color3.fromRGB(200, 220, 255),
		Description = "Lightning strikes the nearest monster you aim at and jumps to 3 more. 8 damage each.",
		Glyph = { { 0.6, 0.1, 0.35, 0.5 }, { 0.35, 0.5, 0.65, 0.5 }, { 0.65, 0.5, 0.4, 0.9 } },
	},
	{
		Id = "DrainLife", Name = "Drain Life", School = "Shadow", Mana = 12, Cooldown = 5, Starter = false, Rarity = 2,
		Color = Color3.fromRGB(170, 60, 90),
		Description = "Draw 7 health out of the nearest monster you aim at and into yourself.",
		Glyph = { { 0.2, 0.2, 0.8, 0.8 }, { 0.8, 0.8, 0.55, 0.8 }, { 0.8, 0.8, 0.8, 0.55 } },
	},
	{
		Id = "Stoneskin", Name = "Stoneskin", School = "Light", Mana = 16, Cooldown = 16, Starter = false, Rarity = 2,
		Color = Color3.fromRGB(210, 200, 170),
		Description = "A shield that absorbs the next 15 damage within 12 seconds.",
		Glyph = { { 0.2, 0.15, 0.8, 0.15 }, { 0.2, 0.15, 0.2, 0.55 }, { 0.8, 0.15, 0.8, 0.55 }, { 0.2, 0.55, 0.5, 0.9 }, { 0.8, 0.55, 0.5, 0.9 } },
	},
	{
		Id = "Haste", Name = "Haste", School = "Arcane", Mana = 14, Cooldown = 18, Starter = false, Rarity = 1.8,
		Color = Color3.fromRGB(255, 230, 140),
		Description = "Move 40% faster and attack 30% faster for 8 seconds. Stamina refills instantly.",
		Glyph = { { 0.2, 0.3, 0.5, 0.5 }, { 0.5, 0.5, 0.2, 0.7 }, { 0.5, 0.3, 0.8, 0.5 }, { 0.8, 0.5, 0.5, 0.7 } },
	},
	{
		Id = "ScareMonster", Name = "Scare Monster", School = "Shadow", Mana = 10, Cooldown = 14, Starter = false, Rarity = 2,
		Color = Color3.fromRGB(140, 110, 160),
		Description = "Every monster within 14 studs flees from you for 5 seconds.",
		Glyph = { { 0.3, 0.3, 0.3, 0.45 }, { 0.7, 0.3, 0.7, 0.45 }, { 0.25, 0.8, 0.5, 0.62 }, { 0.5, 0.62, 0.75, 0.8 } },
	},
	{
		Id = "HoldMonster", Name = "Hold Monster", School = "Shadow", Mana = 11, Cooldown = 9, Starter = false, Rarity = 2,
		Color = Color3.fromRGB(120, 150, 130),
		Description = "Paralyse the monster you aim at for 5 seconds. Paralysed monsters take double damage.",
		Glyph = { { 0.2, 0.2, 0.8, 0.2 }, { 0.2, 0.8, 0.8, 0.8 }, { 0.35, 0.2, 0.35, 0.8 }, { 0.65, 0.2, 0.65, 0.8 } },
	},
	{
		Id = "Light", Name = "Light", School = "Light", Mana = 6, Cooldown = 10, Starter = false, Rarity = 2.5,
		Color = Color3.fromRGB(255, 226, 170),
		Description = "A floating light at your aim for 25 seconds. Counts as firelight: Watchers in it can't move, Wraiths in it can be hurt.",
		Glyph = { { 0.5, 0.1, 0.5, 0.3 }, { 0.5, 0.7, 0.5, 0.9 }, { 0.1, 0.5, 0.3, 0.5 }, { 0.7, 0.5, 0.9, 0.5 }, { 0.35, 0.35, 0.65, 0.65 } },
	},
	{
		Id = "SlowMonster", Name = "Slow Monster", School = "Frost", Mana = 9, Cooldown = 12, Starter = false, Rarity = 2,
		Color = Color3.fromRGB(120, 150, 210),
		Description = "Monsters within 16 studs move and attack at half speed for 7 seconds.",
		Glyph = { { 0.15, 0.5, 0.85, 0.5 }, { 0.5, 0.2, 0.5, 0.8 }, { 0.3, 0.3, 0.7, 0.7 } },
	},
	{
		Id = "Meteor", Name = "Meteor", School = "Fire", Mana = 26, Cooldown = 14, Starter = false, Rarity = 0.8,
		Color = Color3.fromRGB(255, 110, 50),
		Description = "After a moment, a meteor crashes down at your aim: 22 damage in a wide area and burning ground.",
		Glyph = { { 0.15, 0.15, 0.6, 0.6 }, { 0.6, 0.6, 0.85, 0.85 }, { 0.6, 0.85, 0.85, 0.6 } },
	},
}

local byId: { [string]: SpellDef } = {}
for _, s in list do
	byId[s.Id] = s
end

return {
	List = list,
	ById = byId,
}
