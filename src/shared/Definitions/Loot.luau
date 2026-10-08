--!strict
-- Loot tables for floor items and chests. Pure data + a roll function that
-- takes an RNG stream, so generation stays deterministic per seed.

local Loot = {}

export type Roll = { ItemId: string, Count: number, Bonus: number }

local WEAPONS = {
	{ Id = "Dagger", MinDepth = 1, Weight = 3 },
	{ Id = "Mace", MinDepth = 1, Weight = 3 },
	{ Id = "Spear", MinDepth = 1, Weight = 2.5 },
	{ Id = "LongSword", MinDepth = 2, Weight = 2 },
	{ Id = "TwoHandedSword", MinDepth = 3, Weight = 1.2 },
}

local ARMOR = {
	{ Id = "RingMail", MinDepth = 1, Weight = 3 },
	{ Id = "ScaleMail", MinDepth = 2, Weight = 2.5 },
	{ Id = "ChainMail", MinDepth = 3, Weight = 2 },
	{ Id = "BandedMail", MinDepth = 4, Weight = 1.4 },
	{ Id = "PlateMail", MinDepth = 5, Weight = 1 },
}

local POTIONS = { Tincture = 6, ExtraHealing = 1.2, StrengthPotion = 1.5 }
local SCROLLS = { EnchantWeapon = 2, EnchantArmor = 2, MagicMapping = 2.5, Teleportation = 2 }

local function pickGear(stream, list, depth: number): string
	local weights = {}
	for _, g in list do
		if depth >= g.MinDepth then
			weights[g.Id] = g.Weight
		end
	end
	return stream:Weighted(weights) :: string
end

local function bonus(stream, quality: number): number
	local r = stream:Float()
	if r < 0.06 * quality then
		return 2
	elseif r < 0.28 * quality then
		return 1
	end
	return 0
end

-- `quality` 1 = floor item, 2 = chest, 3 = vault chest.
function Loot.Roll(stream, depth: number, quality: number): Roll
	local kind = stream:Weighted({
		Potion = 30,
		Scroll = 20,
		Weapon = 10 + 4 * quality,
		Armor = 8 + 4 * quality,
		Food = 12,
		Oil = 16,
	})
	if kind == "Weapon" then
		return { ItemId = pickGear(stream, WEAPONS, depth + quality - 1), Count = 1, Bonus = bonus(stream, quality) }
	elseif kind == "Armor" then
		return { ItemId = pickGear(stream, ARMOR, depth + quality - 1), Count = 1, Bonus = bonus(stream, quality) }
	elseif kind == "Potion" then
		return { ItemId = stream:Weighted(POTIONS) :: string, Count = 1, Bonus = 0 }
	elseif kind == "Scroll" then
		return { ItemId = stream:Weighted(SCROLLS) :: string, Count = 1, Bonus = 0 }
	elseif kind == "Food" then
		return { ItemId = "Ration", Count = 1, Bonus = 0 }
	end
	return { ItemId = "OilFlask", Count = 1, Bonus = 0 }
end

function Loot.Gold(stream, depth: number, quality: number): number
	return stream:Int(4 + depth * 2, 10 + depth * 6) * quality
end

return Loot
