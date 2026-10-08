--!strict
-- Item definitions. Names follow the original Rogue where it fits (mace,
-- ring mail, scroll of magic mapping...). Every item has a plain one-line
-- description that tells the player exactly what it does.
--
-- Pack entries are { Id, Count, Bonus, Spell? } tables (see PlayerStateService).
-- "Gold" and "Curio" are pickups only: they never sit in the pack.
--
-- Weapons:
--   Style    animation family: "Slash" | "Thrust" | "Smash" | "Staff"
--   Stamina  stamina per light attack (heavy attacks cost more)
--   Quirk    the weapon's passive trait, described in Quirk text
--   Special  the weapon's own move on Q (see CombatService.Specials)

export type WeaponStats = {
	Damage: number,
	Range: number,
	Arc: number, -- degrees
	Cooldown: number,
	Windup: number,
	Noise: number,
	Stamina: number,
	Style: "Slash" | "Thrust" | "Smash" | "Staff",
	Knockback: number,
}

export type Special = {
	Id: string,
	Name: string,
	Cooldown: number,
	Stamina: number,
	Description: string,
}

export type ItemDef = {
	Id: string,
	Name: string,
	Plural: string?,
	Short: string, -- 1-4 char hotbar label
	Category: "Tool" | "Potion" | "Scroll" | "Food" | "Weapon" | "Armor" | "Key" | "Gold" | "Treasure" | "Book",
	Description: string,
	Use: "Throw" | "Drink" | "Read" | "Eat" | "Equip" | "Passive",
	Stackable: boolean,
	Color: Color3,
	Heal: number?,
	Weapon: WeaponStats?,
	Quirk: string?,
	Special: Special?,
	SpellPower: number?, -- staffs: bonus spell damage
	ManaBonus: number?, -- staffs: bonus max mana
	Armor: number?,
	Tier: number?,
}

local Items: { [string]: ItemDef } = {
	-- Tools -----------------------------------------------------------------
	OilFlask = {
		Id = "OilFlask", Name = "Oil Flask", Plural = "Oil Flasks", Short = "Oil", Category = "Tool",
		Description = "Throw it to start a fire that burns monsters and lights the area (and blows up oil barrels). Press R to refill your lantern with it instead.",
		Use = "Throw", Stackable = true, Color = Color3.fromRGB(150, 108, 52),
	},
	TinBell = {
		Id = "TinBell", Name = "Tin Bell", Plural = "Tin Bells", Short = "Bell", Category = "Tool",
		Description = "Throw it to make noise where it lands. Monsters that hunt by sound will go to it. You can pick it up again.",
		Use = "Throw", Stackable = true, Color = Color3.fromRGB(150, 146, 128),
	},
	RustedKey = {
		Id = "RustedKey", Name = "Rusted Key", Plural = "Rusted Keys", Short = "Key", Category = "Key",
		Description = "Opens the iron vault door on this level. It crumbles when you go down the stairs.",
		Use = "Passive", Stackable = false, Color = Color3.fromRGB(128, 84, 58),
	},

	-- Potions ---------------------------------------------------------------
	Tincture = {
		Id = "Tincture", Name = "Potion of Healing", Plural = "Potions of Healing", Short = "Heal", Category = "Potion",
		Description = "Drink to restore 12 health.",
		Use = "Drink", Stackable = true, Color = Color3.fromRGB(170, 52, 48), Heal = 12,
	},
	ExtraHealing = {
		Id = "ExtraHealing", Name = "Potion of Extra Healing", Plural = "Potions of Extra Healing", Short = "XHl", Category = "Potion",
		Description = "Drink to restore all of your health and raise your max health by 3.",
		Use = "Drink", Stackable = true, Color = Color3.fromRGB(196, 80, 120),
	},
	StrengthPotion = {
		Id = "StrengthPotion", Name = "Potion of Strength", Plural = "Potions of Strength", Short = "Str", Category = "Potion",
		Description = "Drink to permanently gain 1 strength (+1 melee damage) for this run.",
		Use = "Drink", Stackable = true, Color = Color3.fromRGB(96, 150, 70),
	},
	ManaPotion = {
		Id = "ManaPotion", Name = "Potion of Mana", Plural = "Potions of Mana", Short = "Mana", Category = "Potion",
		Description = "Drink to restore all of your mana.",
		Use = "Drink", Stackable = true, Color = Color3.fromRGB(70, 110, 200),
	},

	-- Scrolls ---------------------------------------------------------------
	EnchantWeapon = {
		Id = "EnchantWeapon", Name = "Scroll of Enchant Weapon", Plural = "Scrolls of Enchant Weapon", Short = "EnW", Category = "Scroll",
		Description = "Read to give the weapon you are holding +1 damage. Enchanted weapons glow.",
		Use = "Read", Stackable = true, Color = Color3.fromRGB(196, 178, 140),
	},
	EnchantArmor = {
		Id = "EnchantArmor", Name = "Scroll of Enchant Armor", Plural = "Scrolls of Enchant Armor", Short = "EnA", Category = "Scroll",
		Description = "Read to give the armor you are wearing +1 armor. Enchanted armor is etched with glowing runes.",
		Use = "Read", Stackable = true, Color = Color3.fromRGB(186, 172, 150),
	},
	MagicMapping = {
		Id = "MagicMapping", Name = "Scroll of Magic Mapping", Plural = "Scrolls of Magic Mapping", Short = "Map", Category = "Scroll",
		Description = "Read to reveal where the stairs down are on this level.",
		Use = "Read", Stackable = true, Color = Color3.fromRGB(176, 186, 160),
	},
	Teleportation = {
		Id = "Teleportation", Name = "Scroll of Teleportation", Plural = "Scrolls of Teleportation", Short = "Tele", Category = "Scroll",
		Description = "Read to teleport to a random room on this level. Good for escaping a fight.",
		Use = "Read", Stackable = true, Color = Color3.fromRGB(160, 170, 196),
	},

	-- Spellbooks (the entry's Spell field says which spell) ------------------
	Spellbook = {
		Id = "Spellbook", Name = "Spellbook", Short = "Book", Category = "Book",
		Description = "Read to learn the spell inside. You need a free spell slot (or forget a spell first).",
		Use = "Read", Stackable = false, Color = Color3.fromRGB(110, 70, 140),
	},

	-- Food ------------------------------------------------------------------
	Ration = {
		Id = "Ration", Name = "Food Ration", Plural = "Food Rations", Short = "Food", Category = "Food",
		Description = "Eat to restore 6 health and all of your stamina.",
		Use = "Eat", Stackable = true, Color = Color3.fromRGB(150, 120, 80), Heal = 6,
	},

	-- Weapons ---------------------------------------------------------------
	Quarterstaff = {
		Id = "Quarterstaff", Name = "Quarterstaff", Short = "Staf", Category = "Weapon", Tier = 0,
		Description = "A plain wooden staff with good reach.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(110, 82, 56),
		Weapon = { Damage = 3, Range = 8, Arc = 120, Cooldown = 0.6, Windup = 0.12, Noise = 20, Stamina = 14, Style = "Slash", Knockback = 22 },
		Quirk = "Every hit knocks monsters back.",
		Special = { Id = "Sweep", Name = "Sweep", Cooldown = 7, Stamina = 25, Description = "Spin the staff low around you, knocking down every monster in reach for 1.5 seconds." },
	},
	Dagger = {
		Id = "Dagger", Name = "Dagger", Short = "Dagr", Category = "Weapon", Tier = 1,
		Description = "Short and weak, but fast and quiet.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(176, 176, 168),
		Weapon = { Damage = 2, Range = 6, Arc = 80, Cooldown = 0.32, Windup = 0.05, Noise = 8, Stamina = 9, Style = "Thrust", Knockback = 6 },
		Quirk = "Backstabs (hitting a monster from behind or before it notices you) deal triple damage.",
		Special = { Id = "Shadowstep", Name = "Shadowstep", Cooldown = 6, Stamina = 20, Description = "Vanish and reappear behind the nearest monster in front of you, then backstab it." },
	},
	Mace = {
		Id = "Mace", Name = "Mace", Short = "Mace", Category = "Weapon", Tier = 1,
		Description = "Heavy and hard-hitting, a bit slow.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(120, 116, 110),
		Weapon = { Damage = 5, Range = 7, Arc = 100, Cooldown = 0.8, Windup = 0.18, Noise = 26, Stamina = 20, Style = "Smash", Knockback = 18 },
		Quirk = "Stuns monsters briefly, smashes through skeleton shields and breaks cracked walls in one hit.",
		Special = { Id = "GroundSlam", Name = "Ground Slam", Cooldown = 8, Stamina = 35, Description = "Slam the ground: damage and stun every monster within 10 studs for 2 seconds." },
	},
	Spear = {
		Id = "Spear", Name = "Spear", Short = "Sper", Category = "Weapon", Tier = 1,
		Description = "Long reach in a narrow line.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(140, 120, 90),
		Weapon = { Damage = 4, Range = 11.5, Arc = 40, Cooldown = 0.62, Windup = 0.14, Noise = 18, Stamina = 15, Style = "Thrust", Knockback = 14 },
		Quirk = "Pierces: hits every monster in its line.",
		Special = { Id = "Lunge", Name = "Lunge", Cooldown = 6, Stamina = 28, Description = "Charge 16 studs forward, skewering everything you pass through for double damage." },
	},
	LongSword = {
		Id = "LongSword", Name = "Long Sword", Short = "Swrd", Category = "Weapon", Tier = 2,
		Description = "A good all-round blade with a wide swing.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(196, 196, 190),
		Weapon = { Damage = 6, Range = 8.5, Arc = 125, Cooldown = 0.62, Windup = 0.12, Noise = 22, Stamina = 16, Style = "Slash", Knockback = 12 },
		Quirk = "Your third combo hit is a full sweep that hits all around you.",
		Special = { Id = "Whirlwind", Name = "Whirlwind", Cooldown = 9, Stamina = 40, Description = "Spin with the blade out, hitting everything around you three times." },
	},
	TwoHandedSword = {
		Id = "TwoHandedSword", Name = "Two-Handed Sword", Short = "2HS", Category = "Weapon", Tier = 3,
		Description = "Huge damage and a huge swing, but slow, loud and tiring.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(206, 200, 186),
		Weapon = { Damage = 10, Range = 9.5, Arc = 160, Cooldown = 1.05, Windup = 0.3, Noise = 34, Stamina = 26, Style = "Smash", Knockback = 30 },
		Quirk = "Charged attacks can't be interrupted and hurl monsters across the room.",
		Special = { Id = "Cleave", Name = "Cleave", Cooldown = 9, Stamina = 40, Description = "A huge overhead cleave in front of you for triple damage." },
	},
	BattleAxe = {
		Id = "BattleAxe", Name = "Battle Axe", Short = "Axe", Category = "Weapon", Tier = 2,
		Description = "A heavy axe that leaves deep wounds.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(150, 140, 126),
		Weapon = { Damage = 7, Range = 8, Arc = 110, Cooldown = 0.85, Windup = 0.2, Noise = 28, Stamina = 21, Style = "Smash", Knockback = 16 },
		Quirk = "Hits make monsters bleed for 2 damage a second for 3 seconds.",
		Special = { Id = "Rend", Name = "Rend", Cooldown = 8, Stamina = 32, Description = "A brutal swing that makes everything it hits bleed heavily (4 a second for 5 seconds)." },
	},

	-- Magic staffs: weak in melee, but each has its own spell on Q (no mana) -----
	StaffOfFire = {
		Id = "StaffOfFire", Name = "Staff of Fire", Short = "Fire", Category = "Weapon", Tier = 2,
		Description = "A charred staff topped with a burning gem. +25% spell damage, +10 mana.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(200, 90, 40),
		Weapon = { Damage = 2, Range = 7, Arc = 110, Cooldown = 0.7, Windup = 0.12, Noise = 18, Stamina = 14, Style = "Staff", Knockback = 16 },
		SpellPower = 0.25, ManaBonus = 10,
		Quirk = "Melee hits set monsters on fire.",
		Special = { Id = "StaffFire", Name = "Fire Spray", Cooldown = 5, Stamina = 10, Description = "Spray a cone of fire in front of you that burns everything it touches." },
	},
	StaffOfFrost = {
		Id = "StaffOfFrost", Name = "Staff of Frost", Short = "Frst", Category = "Weapon", Tier = 2,
		Description = "A staff rimed with ice that never melts. +25% spell damage, +10 mana.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(140, 200, 240),
		Weapon = { Damage = 2, Range = 7, Arc = 110, Cooldown = 0.7, Windup = 0.12, Noise = 18, Stamina = 14, Style = "Staff", Knockback = 16 },
		SpellPower = 0.25, ManaBonus = 10,
		Quirk = "Melee hits slow monsters.",
		Special = { Id = "StaffFrost", Name = "Ice Shard", Cooldown = 3, Stamina = 8, Description = "Fire a shard of ice that pierces through monsters and freezes them for 1.5 seconds." },
	},
	StaffOfStorms = {
		Id = "StaffOfStorms", Name = "Staff of Storms", Short = "Strm", Category = "Weapon", Tier = 3,
		Description = "A staff that crackles in your hand. +25% spell damage, +10 mana.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(190, 210, 255),
		Weapon = { Damage = 2, Range = 7, Arc = 110, Cooldown = 0.7, Windup = 0.12, Noise = 18, Stamina = 14, Style = "Staff", Knockback = 16 },
		SpellPower = 0.25, ManaBonus = 10,
		Quirk = "Melee hits arc lightning to one more monster nearby.",
		Special = { Id = "StaffStorm", Name = "Thunderclap", Cooldown = 7, Stamina = 15, Description = "Lightning strikes up to 4 monsters near your aim point." },
	},
	StaffOfShadows = {
		Id = "StaffOfShadows", Name = "Staff of Shadows", Short = "Shdw", Category = "Weapon", Tier = 3,
		Description = "A black staff that drinks the light. +40% spell damage, +20 mana.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(90, 60, 110),
		Weapon = { Damage = 2, Range = 7, Arc = 110, Cooldown = 0.7, Windup = 0.12, Noise = 12, Stamina = 14, Style = "Staff", Knockback = 16 },
		SpellPower = 0.4, ManaBonus = 20,
		Quirk = "Melee hits steal 1 health.",
		Special = { Id = "StaffShadow", Name = "Soul Harvest", Cooldown = 10, Stamina = 15, Description = "Rip life from every monster within 12 studs: 6 damage each, and you heal for half of it." },
	},

	-- Armor (each point blocks 7% of incoming damage, up to 60%) -----------
	LeatherArmor = {
		Id = "LeatherArmor", Name = "Leather Armor", Short = "Lthr", Category = "Armor", Tier = 0,
		Description = "Light armor. Armor 1.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(110, 76, 50), Armor = 1,
	},
	RingMail = {
		Id = "RingMail", Name = "Ring Mail", Short = "Ring", Category = "Armor", Tier = 1,
		Description = "Leather sewn with iron rings. Armor 2.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(120, 116, 108), Armor = 2,
	},
	ScaleMail = {
		Id = "ScaleMail", Name = "Scale Mail", Short = "Scal", Category = "Armor", Tier = 2,
		Description = "Overlapping bronze scales and shoulder guards. Armor 3.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(150, 118, 70), Armor = 3,
	},
	ChainMail = {
		Id = "ChainMail", Name = "Chain Mail", Short = "Chan", Category = "Armor", Tier = 3,
		Description = "A full shirt and hood of linked chain. Armor 4.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(150, 150, 146), Armor = 4,
	},
	BandedMail = {
		Id = "BandedMail", Name = "Banded Mail", Short = "Band", Category = "Armor", Tier = 4,
		Description = "Steel bands over chain, with a helmet. Armor 5.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(128, 132, 140), Armor = 5,
	},
	PlateMail = {
		Id = "PlateMail", Name = "Plate Mail", Short = "Plat", Category = "Armor", Tier = 5,
		Description = "A full suit of steel plate and a great helm. Armor 6.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(184, 182, 176), Armor = 6,
	},

	-- Pickups that never enter the pack ------------------------------------
	Gold = {
		Id = "Gold", Name = "Gold", Short = "Gold", Category = "Gold",
		Description = "Gold pieces. Your score at the end of a run.",
		Use = "Passive", Stackable = true, Color = Color3.fromRGB(214, 172, 80),
	},
	Curio = {
		Id = "Curio", Name = "Treasure", Short = "Tres", Category = "Treasure",
		Description = "A valuable trinket, worth gold.",
		Use = "Passive", Stackable = false, Color = Color3.fromRGB(150, 122, 70),
	},
}

export type Entry = { Id: string, Count: number?, Bonus: number?, Spell: string? }

-- Display name for a pack entry, e.g. "+1 Mace", "3 Oil Flasks" or
-- "Spellbook of Firebolt".
local function entryName(entry: Entry?): string
	if not entry then
		return ""
	end
	local def = Items[entry.Id]
	if not def then
		return entry.Id
	end
	if entry.Id == "Spellbook" and entry.Spell then
		local Spells = require(script.Parent.Spells)
		local s = Spells.ById[entry.Spell]
		return "Spellbook of " .. (if s then s.Name else entry.Spell)
	end
	local bonus = entry.Bonus or 0
	local name = def.Name
	if bonus > 0 then
		name = "+" .. bonus .. " " .. name
	elseif bonus < 0 then
		name = tostring(bonus) .. " " .. name
	end
	local count = entry.Count or 1
	if count > 1 then
		return count .. " " .. (def.Plural or def.Name)
	end
	return name
end

return setmetatable(Items, {
	__index = {
		EntryName = entryName,
	},
}) :: any
