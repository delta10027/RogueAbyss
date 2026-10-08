--!strict
-- Turns the character's boons, flaws and level-up perks into stat
-- modifiers (run.Mods), derives max health / mana / stamina / spell slots,
-- and runs the level-up perk choice.
--
-- Mod keys (all additive; "fraction" keys are +0.1 = +10%):
--   MaxHP MaxMana Str Armor SpellSlots StaminaMax          flat
--   DamageMult SpellPower AttackSpeed MoveSpeed CritChance  fraction
--   CritMult HeavyMult BackstabMult FireMult ExpMult GoldMult fraction
--   StaminaRegen ManaRegen LanternRange LanternDrain        fraction
--   DashCost DamageTaken NoiseMult DetectMult               fraction
--   Lifesteal Thorns SpellbladeMana LootLuck                flat
--   Riposte SecondWind StartPotions NoFood                  flags / counts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Boons = require(Shared.Definitions.Boons)
local Spells = require(Shared.Definitions.Spells)
local Items = require(Shared.Definitions.Items)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ProgressionService = {}

local S: any

local function addMods(into: { [string]: number }, mods: { [string]: number }, times: number?)
	for k, v in mods do
		into[k] = (into[k] or 0) + v * (times or 1)
	end
end

-- Recomputes run.Mods and every derived maximum.
function ProgressionService.Recalc(run)
	local mods: { [string]: number } = {}
	local ch = run.Character
	if ch then
		for _, id in ch.Boons do
			local t = Boons.BoonById[id]
			if t then
				addMods(mods, t.Mods)
			end
		end
		for _, id in ch.Flaws do
			local t = Boons.FlawById[id]
			if t then
				addMods(mods, t.Mods)
			end
		end
	end
	for id, stacks in run.Perks or {} do
		local t = Boons.PerkById[id]
		if t then
			addMods(mods, t.Mods, stacks)
		end
	end
	-- The wielded staff adds spell power and mana.
	local ps = run.PS
	local wdef = ps and Items[ps.Weapon.Id]
	if wdef then
		mods.SpellPower = (mods.SpellPower or 0) + (wdef.SpellPower or 0)
		mods.MaxMana = (mods.MaxMana or 0) + (wdef.ManaBonus or 0)
	end
	run.Mods = mods
	if not ps then
		return
	end
	local level = ps.Level
	local oldMax = ps.MaxHP
	ps.MaxHP = math.max(6, Config.Player.MaxHealth + (level - 1) * Config.Player.HealthPerLevel + (mods.MaxHP or 0) + (ps.ExtraMaxHP or 0))
	if ps.MaxHP > oldMax and oldMax > 0 then
		ps.HP += ps.MaxHP - oldMax
	end
	ps.HP = math.min(ps.HP, ps.MaxHP)
	ps.MaxMana = math.max(0, Config.Mana.Base + (level - 1) * Config.Mana.PerLevel + (mods.MaxMana or 0))
	ps.Mana = math.min(ps.Mana, ps.MaxMana)
	ps.MaxStamina = Config.Stamina.Max + (mods.StaminaMax or 0)
	local slots = Config.Spells.BaseSlots + (mods.SpellSlots or 0)
	for _, lv in Config.Spells.SlotLevels do
		if level >= lv then
			slots += 1
		end
	end
	ps.SpellSlots = math.clamp(slots, 1, Config.Spells.MaxSlots)
end

function ProgressionService.Mod(run, key: string): number
	return (run.Mods and run.Mods[key]) or 0
end

---------------------------------------------------------------------------
-- Character creation
---------------------------------------------------------------------------

local function filterName(player: Player, raw: string): string
	local name = string.sub(string.gsub(raw, "[%c]", ""), 1, 20)
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	if name == "" then
		return player.DisplayName
	end
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" and result ~= "" then
		return result
	end
	return player.DisplayName
end

-- Validates a creation request from the client. Anything invalid falls back
-- to a safe default rather than failing the run.
function ProgressionService.Validate(player: Player, config: any)
	local out = { Name = player.DisplayName, Boons = {}, Flaws = {}, Spell = "MagicMissile" }
	if type(config) ~= "table" then
		return out
	end
	if type(config.Name) == "string" then
		out.Name = filterName(player, config.Name)
	end
	local seen = {}
	if type(config.Flaws) == "table" then
		for _, id in config.Flaws do
			if type(id) == "string" and Boons.FlawById[id] and not seen[id] and #out.Flaws < Boons.MaxFlaws then
				seen[id] = true
				table.insert(out.Flaws, id)
			end
		end
	end
	local allowed = Boons.FreeBoons + #out.Flaws
	if type(config.Boons) == "table" then
		for _, id in config.Boons do
			if type(id) == "string" and Boons.BoonById[id] and not seen[id] and #out.Boons < allowed then
				seen[id] = true
				table.insert(out.Boons, id)
			end
		end
	end
	local spell = type(config.Spell) == "string" and Spells.ById[config.Spell]
	if spell and spell.Starter then
		out.Spell = spell.Id
	end
	return out
end

-- Applies the creation choices to a fresh run.
function ProgressionService.ApplyCreation(run, ch)
	run.Character = ch
	run.Perks = {}
	run.PendingPerks = 0
	run.PerkOffer = nil
	ProgressionService.Recalc(run)
	local ps = run.PS
	ps.HP = ps.MaxHP
	ps.Mana = ps.MaxMana
	ps.Stamina = ps.MaxStamina
	ps.Spells = { ch.Spell }
	local potions = 1 + ProgressionService.Mod(run, "StartPotions")
	local slot = 1
	if potions > 0 then
		ps.Pack[slot] = S.PlayerStateService.Entry("Tincture", potions)
		slot += 1
	end
	if ProgressionService.Mod(run, "NoFood") <= 0 then
		ps.Pack[slot] = S.PlayerStateService.Entry("Ration", 1)
	end
end

---------------------------------------------------------------------------
-- Level-up perks
---------------------------------------------------------------------------

local function offer(run)
	local rng = Random.new()
	local pool = {}
	local total = 0
	for _, p in Boons.Perks do
		local stacks = run.Perks[p.Id] or 0
		if stacks < (p.MaxStacks or 1) then
			table.insert(pool, p)
			total += p.Weight or 1
		end
	end
	local picks = {}
	for _ = 1, 3 do
		if #pool == 0 then
			break
		end
		local roll = rng:NextNumber() * total
		for i, p in pool do
			roll -= p.Weight or 1
			if roll <= 0 or i == #pool then
				table.insert(picks, p.Id)
				total -= p.Weight or 1
				table.remove(pool, i)
				break
			end
		end
	end
	run.PerkOffer = picks
end

function ProgressionService.OnLevelUp(run)
	run.PendingPerks = (run.PendingPerks or 0) + 1
	if not run.PerkOffer then
		offer(run)
	end
	ProgressionService.Recalc(run)
end

function ProgressionService.ChoosePerk(run, id: string)
	if not run.PerkOffer or (run.PendingPerks or 0) <= 0 or not table.find(run.PerkOffer, id) then
		return
	end
	local def = Boons.PerkById[id]
	if not def then
		return
	end
	run.Perks[id] = (run.Perks[id] or 0) + 1
	run.PendingPerks -= 1
	run.PerkOffer = nil
	if run.PendingPerks > 0 then
		offer(run)
	end
	ProgressionService.Recalc(run)
	S.PlayerStateService.Message(run, "You gain the " .. def.Name .. " perk: " .. def.Description)
	S.RunDirector.RecordEvent(run, "Perk" .. id .. (run.Perks[id] or 1), "Learned the " .. def.Name .. " perk.")
	Remotes.Effect:FireClient(run.Player, { Kind = "Perk" })
	S.PlayerStateService.ApplySpeed(run)
	S.PlayerStateService.Push(run.Player)
end

function ProgressionService.Init(registry)
	S = registry
	Remotes.RequestPerk.OnServerEvent:Connect(function(player, id)
		if type(id) ~= "string" then
			return
		end
		local run = S.RunDirector.GetRun(player)
		if run and (run.State == "Active" or run.State == "Transition") then
			ProgressionService.ChoosePerk(run, id)
		end
	end)
end

return ProgressionService
