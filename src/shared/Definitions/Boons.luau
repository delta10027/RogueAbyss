--!strict
-- Character traits.
--   Boons  - chosen at character creation (2 free, +1 for each flaw taken).
--   Flaws  - optional drawbacks chosen at creation (up to 2).
--   Perks  - offered 3 at a time on every level up; pick one.
-- All of them are expressed as stat modifiers that ProgressionService adds up
-- (see ProgressionService.Mods for what each key does).

export type Trait = {
	Id: string,
	Name: string,
	Description: string,
	Mods: { [string]: number },
	MaxStacks: number?, -- perks only
	Weight: number?, -- perks only
}

local boons: { Trait } = {
	{ Id = "Tough", Name = "Tough", Description = "+8 max health.", Mods = { MaxHP = 8 } },
	{ Id = "Strong", Name = "Strong", Description = "+2 strength (+2 melee damage).", Mods = { Str = 2 } },
	{ Id = "Gifted", Name = "Arcane Gift", Description = "+1 spell slot and +15 max mana.", Mods = { SpellSlots = 1, MaxMana = 15 } },
	{ Id = "Nimble", Name = "Nimble", Description = "Move 10% faster. Dashing costs 40% less stamina.", Mods = { MoveSpeed = 0.1, DashCost = -0.4 } },
	{ Id = "Lucky", Name = "Lucky", Description = "+40% gold, and chests hold an extra item.", Mods = { GoldMult = 0.4, LootLuck = 1 } },
	{ Id = "KeenEyes", Name = "Keen Eyes", Description = "Your lantern lights 25% farther and burns 30% slower.", Mods = { LanternRange = 0.25, LanternDrain = -0.3 } },
	{ Id = "ThickHide", Name = "Thick Hide", Description = "+2 armor.", Mods = { Armor = 2 } },
	{ Id = "Duelist", Name = "Duelist", Description = "+10% critical hit chance.", Mods = { CritChance = 0.1 } },
	{ Id = "Blessed", Name = "Blessed", Description = "Start with 2 extra Potions of Healing.", Mods = { StartPotions = 2 } },
	{ Id = "QuickLearner", Name = "Quick Learner", Description = "+25% experience.", Mods = { ExpMult = 0.25 } },
	{ Id = "Enduring", Name = "Enduring", Description = "+30 max stamina and it refills 25% faster.", Mods = { StaminaMax = 30, StaminaRegen = 0.25 } },
	{ Id = "Shadowborn", Name = "Shadowborn", Description = "Monsters spot you from 25% less far away.", Mods = { DetectMult = -0.25 } },
}

local flaws: { Trait } = {
	{ Id = "Frail", Name = "Frail", Description = "-6 max health.", Mods = { MaxHP = -6 } },
	{ Id = "Clumsy", Name = "Clumsy", Description = "Attacks are 15% slower.", Mods = { AttackSpeed = -0.15 } },
	{ Id = "Brittle", Name = "Brittle", Description = "You take 20% more damage.", Mods = { DamageTaken = 0.2 } },
	{ Id = "HeavyFooted", Name = "Heavy-Footed", Description = "Your footsteps are 50% louder.", Mods = { NoiseMult = 0.5 } },
	{ Id = "ShortSighted", Name = "Short-Sighted", Description = "Your lantern lights 25% less far.", Mods = { LanternRange = -0.25 } },
	{ Id = "Hunted", Name = "Hunted", Description = "Monsters spot you from 25% farther away.", Mods = { DetectMult = 0.25 } },
	{ Id = "Poor", Name = "Poor", Description = "You start with no potion and no food.", Mods = { StartPotions = -1, NoFood = 1 } },
	{ Id = "SlowLearner", Name = "Slow Learner", Description = "-20% experience.", Mods = { ExpMult = -0.2 } },
}

local perks: { Trait } = {
	{ Id = "Brute", Name = "Brute", Description = "+15% melee damage.", Mods = { DamageMult = 0.15 }, MaxStacks = 3, Weight = 3 },
	{ Id = "Precision", Name = "Precision", Description = "+8% critical hit chance.", Mods = { CritChance = 0.08 }, MaxStacks = 3, Weight = 3 },
	{ Id = "Executioner", Name = "Executioner", Description = "Critical hits deal +60% more damage.", Mods = { CritMult = 0.6 }, MaxStacks = 2, Weight = 1.5 },
	{ Id = "Vampiric", Name = "Vampiric", Description = "Heal 2 health every time you defeat a monster.", Mods = { Lifesteal = 2 }, MaxStacks = 3, Weight = 2 },
	{ Id = "IronSkin", Name = "Iron Skin", Description = "+2 armor.", Mods = { Armor = 2 }, MaxStacks = 3, Weight = 2.5 },
	{ Id = "Vigor", Name = "Vigor", Description = "+10 max health.", Mods = { MaxHP = 10 }, MaxStacks = 3, Weight = 3 },
	{ Id = "Endurance", Name = "Endurance", Description = "+25 max stamina and +20% stamina regeneration.", Mods = { StaminaMax = 25, StaminaRegen = 0.2 }, MaxStacks = 2, Weight = 2 },
	{ Id = "ArcaneMind", Name = "Arcane Mind", Description = "+20 max mana and +30% mana regeneration.", Mods = { MaxMana = 20, ManaRegen = 0.3 }, MaxStacks = 3, Weight = 2.5 },
	{ Id = "Spellweaver", Name = "Spellweaver", Description = "+1 spell slot.", Mods = { SpellSlots = 1 }, MaxStacks = 1, Weight = 1.2 },
	{ Id = "Sorcery", Name = "Sorcery", Description = "Spells deal +25% damage.", Mods = { SpellPower = 0.25 }, MaxStacks = 3, Weight = 2.5 },
	{ Id = "Spellblade", Name = "Spellblade", Description = "Every melee hit restores 2 mana.", Mods = { SpellbladeMana = 2 }, MaxStacks = 2, Weight = 1.8 },
	{ Id = "Pyromaniac", Name = "Pyromaniac", Description = "Fire (spells, oil and burning) deals +50% damage.", Mods = { FireMult = 0.5 }, MaxStacks = 2, Weight = 1.5 },
	{ Id = "Thorns", Name = "Thorns", Description = "Monsters that hit you take 4 damage.", Mods = { Thorns = 4 }, MaxStacks = 3, Weight = 1.5 },
	{ Id = "Fleet", Name = "Fleet-Footed", Description = "Move 8% faster and dashing costs 25% less stamina.", Mods = { MoveSpeed = 0.08, DashCost = -0.25 }, MaxStacks = 2, Weight = 2 },
	{ Id = "Frenzy", Name = "Frenzy", Description = "Attack 12% faster.", Mods = { AttackSpeed = 0.12 }, MaxStacks = 3, Weight = 2.5 },
	{ Id = "HeavyHitter", Name = "Heavy Hitter", Description = "Charged (held) attacks deal +50% damage and stun longer.", Mods = { HeavyMult = 0.5 }, MaxStacks = 2, Weight = 1.8 },
	{ Id = "Riposte", Name = "Riposte", Description = "After a dash, your next attack within 1.5 seconds is a guaranteed critical hit.", Mods = { Riposte = 1 }, MaxStacks = 1, Weight = 1.3 },
	{ Id = "SecondWind", Name = "Second Wind", Description = "Once per dungeon level, dropping below 25% health instantly heals you to half.", Mods = { SecondWind = 1 }, MaxStacks = 1, Weight = 1.2 },
	{ Id = "TreasureHunter", Name = "Treasure Hunter", Description = "+30% gold and chests hold an extra item.", Mods = { GoldMult = 0.3, LootLuck = 1 }, MaxStacks = 2, Weight = 1.5 },
	{ Id = "Stalker", Name = "Stalker", Description = "Monsters spot you from 15% less far away, and backstabs deal +50% damage.", Mods = { DetectMult = -0.15, BackstabMult = 0.5 }, MaxStacks = 2, Weight = 1.5 },
}

local function index(list: { Trait }): { [string]: Trait }
	local out = {}
	for _, t in list do
		out[t.Id] = t
	end
	return out
end

return {
	Boons = boons,
	Flaws = flaws,
	Perks = perks,
	BoonById = index(boons),
	FlawById = index(flaws),
	PerkById = index(perks),
	FreeBoons = 2,
	MaxFlaws = 2,
}
