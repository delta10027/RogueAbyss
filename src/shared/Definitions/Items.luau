--!strict
-- Item definitions. Names follow the original Rogue where it fits (mace,
-- ring mail, scroll of magic mapping...). Every item has a plain one-line
-- description that tells the player exactly what it does.
--
-- Pack entries are { Id, Count, Bonus } tables (see PlayerStateService).
-- "Gold" and "Curio" are pickups only: they never sit in the pack.

export type WeaponStats = {
	Damage: number,
	Range: number,
	Arc: number, -- degrees
	Cooldown: number,
	Windup: number,
	Noise: number,
}

export type ItemDef = {
	Id: string,
	Name: string,
	Plural: string?,
	Short: string, -- 1-4 char hotbar label
	Category: "Tool" | "Potion" | "Scroll" | "Food" | "Weapon" | "Armor" | "Key" | "Gold" | "Treasure",
	Description: string,
	Use: "Throw" | "Drink" | "Read" | "Eat" | "Equip" | "Passive",
	Stackable: boolean,
	Color: Color3,
	Heal: number?,
	Weapon: WeaponStats?,
	Armor: number?,
}

local Items: { [string]: ItemDef } = {
	-- Tools -----------------------------------------------------------------
	OilFlask = {
		Id = "OilFlask", Name = "Oil Flask", Plural = "Oil Flasks", Short = "Oil", Category = "Tool",
		Description = "Throw it to start a fire that burns monsters and lights the area. Press R to refill your lantern with it instead.",
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
		Description = "Drink to restore 8 health.",
		Use = "Drink", Stackable = true, Color = Color3.fromRGB(150, 60, 56), Heal = 8,
	},
	ExtraHealing = {
		Id = "ExtraHealing", Name = "Potion of Extra Healing", Plural = "Potions of Extra Healing", Short = "XHl", Category = "Potion",
		Description = "Drink to restore all of your health and raise your max health by 2.",
		Use = "Drink", Stackable = true, Color = Color3.fromRGB(176, 92, 120),
	},
	StrengthPotion = {
		Id = "StrengthPotion", Name = "Potion of Strength", Plural = "Potions of Strength", Short = "Str", Category = "Potion",
		Description = "Drink to permanently gain 1 strength (+1 melee damage) for this run.",
		Use = "Drink", Stackable = true, Color = Color3.fromRGB(96, 120, 84),
	},

	-- Scrolls ---------------------------------------------------------------
	EnchantWeapon = {
		Id = "EnchantWeapon", Name = "Scroll of Enchant Weapon", Plural = "Scrolls of Enchant Weapon", Short = "EnW", Category = "Scroll",
		Description = "Read to give the weapon you are holding +1 damage.",
		Use = "Read", Stackable = true, Color = Color3.fromRGB(196, 178, 140),
	},
	EnchantArmor = {
		Id = "EnchantArmor", Name = "Scroll of Enchant Armor", Plural = "Scrolls of Enchant Armor", Short = "EnA", Category = "Scroll",
		Description = "Read to give the armor you are wearing +1 armor.",
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

	-- Food ------------------------------------------------------------------
	Ration = {
		Id = "Ration", Name = "Food Ration", Plural = "Food Rations", Short = "Food", Category = "Food",
		Description = "Eat to restore 4 health.",
		Use = "Eat", Stackable = true, Color = Color3.fromRGB(150, 120, 80), Heal = 4,
	},

	-- Weapons (Damage per hit, reach in studs, swing arc, seconds between swings)
	Quarterstaff = {
		Id = "Quarterstaff", Name = "Quarterstaff", Short = "Staf", Category = "Weapon",
		Description = "A plain wooden staff. Reliable, nothing special.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(110, 82, 56),
		Weapon = { Damage = 3, Range = 7.5, Arc = 110, Cooldown = 0.75, Windup = 0.15, Noise = 22 },
	},
	Dagger = {
		Id = "Dagger", Name = "Dagger", Short = "Dagr", Category = "Weapon",
		Description = "Weak and short, but very fast and quiet.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(168, 168, 160),
		Weapon = { Damage = 2, Range = 6, Arc = 80, Cooldown = 0.38, Windup = 0.06, Noise = 10 },
	},
	Mace = {
		Id = "Mace", Name = "Mace", Short = "Mace", Category = "Weapon",
		Description = "Heavy and hard-hitting, a bit slow.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(120, 116, 110),
		Weapon = { Damage = 5, Range = 7, Arc = 100, Cooldown = 0.95, Windup = 0.2, Noise = 26 },
	},
	Spear = {
		Id = "Spear", Name = "Spear", Short = "Sper", Category = "Weapon",
		Description = "Long reach in a narrow line. Hit things before they reach you.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(140, 120, 90),
		Weapon = { Damage = 4, Range = 11, Arc = 45, Cooldown = 0.8, Windup = 0.18, Noise = 20 },
	},
	LongSword = {
		Id = "LongSword", Name = "Long Sword", Short = "Swrd", Category = "Weapon",
		Description = "A good all-round blade with a wide swing.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(190, 190, 186),
		Weapon = { Damage = 6, Range = 8, Arc = 120, Cooldown = 0.85, Windup = 0.16, Noise = 24 },
	},
	TwoHandedSword = {
		Id = "TwoHandedSword", Name = "Two-Handed Sword", Short = "2HS", Category = "Weapon",
		Description = "Huge damage and a very wide swing, but slow and loud.",
		Use = "Equip", Stackable = false, Color = Color3.fromRGB(200, 196, 180),
		Weapon = { Damage = 9, Range = 9, Arc = 160, Cooldown = 1.35, Windup = 0.32, Noise = 34 },
	},

	-- Armor (each point blocks 7% of incoming damage, up to 60%)
	LeatherArmor = {
		Id = "LeatherArmor", Name = "Leather Armor", Short = "Lthr", Category = "Armor",
		Description = "Light armor. Armor 1.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(110, 80, 56), Armor = 1,
	},
	RingMail = {
		Id = "RingMail", Name = "Ring Mail", Short = "Ring", Category = "Armor",
		Description = "Leather sewn with iron rings. Armor 2.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(120, 116, 108), Armor = 2,
	},
	ScaleMail = {
		Id = "ScaleMail", Name = "Scale Mail", Short = "Scal", Category = "Armor",
		Description = "Overlapping metal scales. Armor 3.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(130, 124, 100), Armor = 3,
	},
	ChainMail = {
		Id = "ChainMail", Name = "Chain Mail", Short = "Chan", Category = "Armor",
		Description = "A full shirt of linked chain. Armor 4.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(150, 150, 146), Armor = 4,
	},
	BandedMail = {
		Id = "BandedMail", Name = "Banded Mail", Short = "Band", Category = "Armor",
		Description = "Strips of metal over chain. Armor 5.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(140, 130, 112), Armor = 5,
	},
	PlateMail = {
		Id = "PlateMail", Name = "Plate Mail", Short = "Plat", Category = "Armor",
		Description = "The heaviest protection there is. Armor 6.", Use = "Equip", Stackable = false,
		Color = Color3.fromRGB(176, 172, 164), Armor = 6,
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

-- Display name for a pack entry, e.g. "+1 Mace" or "3 Oil Flasks".
local function entryName(entry: { Id: string, Count: number?, Bonus: number? }?): string
	if not entry then
		return ""
	end
	local def = Items[entry.Id]
	if not def then
		return entry.Id
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
