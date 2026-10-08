--!strict
-- Authoritative per-run player state: health, mana, stamina, experience,
-- gold, strength, equipment, the pack, spells, lantern fuel and sneaking.
-- Also dresses the character (cloak, hood, lantern) and shows the equipped
-- weapon and armor on it (Builder/Gear).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local FloorRules = require(Shared.Definitions.FloorRules)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Gear = require(script.Parent.Parent.Builder.Gear)

local PlayerStateService = {}

local S: any

local L = Config.Lantern

export type Entry = { Id: string, Count: number, Bonus: number, Spell: string? }

local function entry(id: string, count: number?, bonus: number?, spell: string?): Entry
	return { Id = id, Count = count or 1, Bonus = bonus or 0, Spell = spell }
end
PlayerStateService.Entry = entry

function PlayerStateService.NewState()
	local pack = {}
	for i = 1, Config.Player.PackSlots do
		pack[i] = false
	end
	return {
		HP = Config.Player.MaxHealth,
		MaxHP = Config.Player.MaxHealth,
		ExtraMaxHP = 0,
		Mana = Config.Mana.Base,
		MaxMana = Config.Mana.Base,
		Stamina = Config.Stamina.Max,
		MaxStamina = Config.Stamina.Max,
		StaminaSpentAt = 0,
		WindedUntil = 0,
		Str = Config.Player.Strength,
		Gold = 0,
		Exp = 0,
		Level = 1,
		Weapon = entry(Config.Player.StartWeapon),
		Armor = entry(Config.Player.StartArmor) :: Entry?,
		Spells = {} :: { string },
		SpellSlots = Config.Spells.BaseSlots,
		Fuel = L.MaxFuel,
		Dim = false,
		Creep = false,
		Pack = pack,
		Cooldowns = {} :: { [string]: number },
		Kills = 0,
		InvulnUntil = 0,
		ShieldHP = 0,
		ShieldUntil = 0,
		HasteUntil = 0,
		RiposteUntil = 0,
		SecondWindUsed = false,
		LastNoiseAt = 0,
		LastStepAt = 0,
		LastVitals = 0,
		Light = nil :: PointLight?,
		LanternPart = nil :: BasePart?,
	}
end

local function mod(run, key: string): number
	return (run.Mods and run.Mods[key]) or 0
end

---------------------------------------------------------------------------
-- Character dressing
---------------------------------------------------------------------------

local function weldTo(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = to
	weld.Parent = part
end

local function gear(character: Model, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = character
	return p
end

function PlayerStateService.DressCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = Config.Player.WalkSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	local regen = character:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end

	-- Strip loud avatar items; keep the silhouette simple and muted.
	for _, d in character:GetChildren() do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
	local cloth = Color3.fromRGB(62, 50, 42)
	local dark = Color3.fromRGB(40, 34, 30)
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Player"
			if part.Name ~= "Head" and part.Name ~= "HumanoidRootPart" then
				part.Color = if string.find(part.Name, "Leg") or string.find(part.Name, "Foot") then dark else cloth
				part.Material = Enum.Material.Fabric
			end
		end
	end
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy()
	end

	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	-- The lantern hangs from the left hand; the weapon goes in the right.
	local hand = (character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")) :: BasePart?
	if head then
		local hood = gear(character, "Hood", head.Size * Vector3.new(1.35, 1.25, 1.35), Color3.fromRGB(54, 40, 34), Enum.Material.Fabric)
		weldTo(hood, head, CFrame.new(0, 0.12, 0.08))
	end
	if torso then
		local cloak = gear(character, "Cloak", Vector3.new(torso.Size.X * 1.15, 3.6, 0.3), Color3.fromRGB(70, 36, 34), Enum.Material.Fabric)
		weldTo(cloak, torso, CFrame.new(0, -0.9, torso.Size.Z / 2 + 0.2) * CFrame.Angles(math.rad(-6), 0, 0))
		local pack = gear(character, "Satchel", Vector3.new(1.2, 1, 0.6), Color3.fromRGB(84, 62, 44), Enum.Material.Fabric)
		weldTo(pack, torso, CFrame.new(0.9, -0.8, -0.3))
	end
	if hand then
		local lantern = gear(character, "Lantern", Vector3.new(0.7, 0.9, 0.7), Color3.fromRGB(60, 52, 40), Enum.Material.CorrodedMetal)
		weldTo(lantern, hand, CFrame.new(0, -0.9, -0.25))
		local glass = gear(character, "LanternGlass", Vector3.new(0.5, 0.55, 0.5), Color3.fromRGB(255, 190, 120), Enum.Material.Neon)
		glass.Transparency = 0.3
		weldTo(glass, lantern, CFrame.new())
		local light = Instance.new("PointLight")
		light.Name = "LanternLight"
		light.Color = L.Color
		light.Range = L.LitRange
		light.Brightness = L.LitBrightness
		light.Shadows = true
		light.Parent = glass
	end
end

-- Puts the wielded weapon in the right hand and the armor on the body.
function PlayerStateService.DressGear(run)
	local character = run.Player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("WeaponModel")
	if old then
		old:Destroy()
	end
	local hand = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if hand then
		local w = Gear.Weapon(run.PS.Weapon.Id, run.PS.Weapon.Bonus)
		w.Name = "WeaponModel"
		local grip = w.PrimaryPart :: BasePart
		-- Blade forward along the hand's -Z, grip in the palm.
		local offset = if hand.Name == "Right Arm" then CFrame.new(0, -1, -0.2) else CFrame.new(0, -0.15, -0.1)
		w:PivotTo(hand.CFrame * offset * CFrame.Angles(math.rad(-90), 0, 0))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = grip
		weld.Parent = grip
		w.Parent = character
	end
	local a = run.PS.Armor
	pcall(Gear.Outfit, character, a and a.Id or nil, a and a.Bonus or 0, run.PS.Level)
end

function PlayerStateService.AttachLantern(run)
	local character = run.Player.Character
	local glass = character and character:FindFirstChild("LanternGlass")
	run.PS.LanternPart = glass
	run.PS.Light = glass and glass:FindFirstChild("LanternLight") :: PointLight?
	PlayerStateService.UpdateLantern(run)
	PlayerStateService.DressGear(run)
end

-- Current light radius of the player's lantern.
function PlayerStateService.LanternRange(run): number
	local ps = run.PS
	if ps.Fuel <= 0 then
		return L.EmptyRange
	end
	local mult = 1 + mod(run, "LanternRange")
	return (if ps.Dim then L.DimRange else L.LitRange) * mult
end

function PlayerStateService.UpdateLantern(run)
	local ps = run.PS
	local light = ps.Light
	if not light or not light.Parent then
		return
	end
	light.Range = PlayerStateService.LanternRange(run)
	if ps.Fuel <= 0 then
		light.Brightness = 0.5
	else
		light.Brightness = if ps.Dim then L.DimBrightness else L.LitBrightness
	end
	local glass = ps.LanternPart
	if glass then
		glass.Transparency = if ps.Fuel <= 0 then 0.8 elseif ps.Dim then 0.6 else 0.3
	end
end

-- A plain line for the message log at the top of the screen.
function PlayerStateService.Message(run, text: string)
	Remotes.Notice:FireClient(run.Player, { Kind = "Info", Text = text })
end

---------------------------------------------------------------------------
-- Derived stats
---------------------------------------------------------------------------

function PlayerStateService.ArmorValue(run): number
	local a = run.PS.Armor
	local def = a and Items[a.Id]
	local base = if a and def and def.Armor then def.Armor + a.Bonus else 0
	return math.max(0, base + mod(run, "Armor"))
end

function PlayerStateService.Hasted(run): boolean
	return os.clock() < run.PS.HasteUntil
end

-- Effective stats of the wielded weapon, strength and perks included.
function PlayerStateService.WeaponStats(run)
	local w = run.PS.Weapon
	local def = Items[w.Id]
	local ws = (def and def.Weapon) or (Items.Quarterstaff.Weapon :: any)
	local str = run.PS.Str + mod(run, "Str")
	local strBonus = math.max(0, str - Config.Player.Strength)
	local speed = 1 + mod(run, "AttackSpeed") + (if PlayerStateService.Hasted(run) then 0.3 else 0)
	return {
		Id = w.Id,
		Damage = math.max(1, (ws.Damage + w.Bonus + strBonus) * (1 + mod(run, "DamageMult"))),
		Range = ws.Range,
		Arc = ws.Arc,
		Cooldown = ws.Cooldown / math.max(0.4, speed),
		Windup = ws.Windup / math.max(0.4, speed),
		Noise = ws.Noise,
		Stamina = ws.Stamina,
		Style = ws.Style,
		Knockback = ws.Knockback,
	}
end

function PlayerStateService.MoveSpeed(run, wading: boolean?): number
	local ps = run.PS
	local base = if ps.Creep then Config.Player.CreepSpeed else Config.Player.WalkSpeed
	base *= 1 + mod(run, "MoveSpeed")
	if PlayerStateService.Hasted(run) then
		base *= 1.4
	end
	if os.clock() < ps.WindedUntil then
		base *= 0.75
	end
	if wading then
		base *= 0.7
	end
	return base
end

function PlayerStateService.ApplySpeed(run)
	local humanoid = run.Player.Character and run.Player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = PlayerStateService.MoveSpeed(run)
	end
end

---------------------------------------------------------------------------
-- Snapshots
---------------------------------------------------------------------------

local function copyEntry(e: Entry?)
	return if e then { Id = e.Id, Count = e.Count, Bonus = e.Bonus, Spell = e.Spell } else nil
end

local function nextLevelExp(level: number): number?
	return Config.Levels[level + 1]
end

function PlayerStateService.Push(player: Player)
	local run = S.RunDirector.GetRun(player)
	if not run or not run.Floor then
		return
	end
	local ps = run.PS
	local known = S.DiscoveryService.Knows(player, "Rule" .. run.Floor.RuleId)
	local pack = {}
	for i, e in ps.Pack do
		pack[i] = if e then copyEntry(e) else false
	end
	local cooldowns = {}
	local now = os.clock()
	for id, t in ps.Cooldowns do
		if t > now then
			cooldowns[id] = t - now
		end
	end
	local perks = {}
	for id, n in run.Perks or {} do
		perks[id] = n
	end
	Remotes.StateUpdate:FireClient(player, {
		HP = ps.HP,
		MaxHP = ps.MaxHP,
		Mana = math.floor(ps.Mana),
		MaxMana = ps.MaxMana,
		Stamina = math.floor(ps.Stamina),
		MaxStamina = ps.MaxStamina,
		Shield = math.ceil(ps.ShieldHP),
		Str = ps.Str + mod(run, "Str"),
		Gold = ps.Gold,
		Exp = ps.Exp,
		Level = ps.Level,
		NextExp = nextLevelExp(ps.Level),
		LevelExp = Config.Levels[ps.Level] or 0,
		Armor = PlayerStateService.ArmorValue(run),
		Damage = math.floor(PlayerStateService.WeaponStats(run).Damage + 0.5),
		Crit = math.floor((Config.Crit.Chance + mod(run, "CritChance")) * 100 + 0.5),
		Weapon = copyEntry(ps.Weapon),
		ArmorItem = copyEntry(ps.Armor),
		Spells = table.clone(ps.Spells),
		SpellSlots = ps.SpellSlots,
		Perks = perks,
		PendingPerks = run.PendingPerks or 0,
		PerkOffer = run.PerkOffer,
		Name = run.Character and run.Character.Name or player.DisplayName,
		Boons = run.Character and run.Character.Boons or {},
		Flaws = run.Character and run.Character.Flaws or {},
		Fuel = math.floor(ps.Fuel + 0.5),
		MaxFuel = L.MaxFuel,
		Dim = ps.Dim,
		Creep = ps.Creep,
		Pack = pack,
		Cooldowns = cooldowns,
		Depth = run.Depth,
		RuleId = run.Floor.RuleId,
		RuleName = if known then FloorRules[run.Floor.RuleId].Name else nil,
		Known = S.DiscoveryService.KnownList(player),
		HasKey = PlayerStateService.FindItem(run, "RustedKey") ~= nil,
	})
end

-- Small, frequent update for the bars (health, mana, stamina, shield).
function PlayerStateService.PushVitals(run)
	local ps = run.PS
	Remotes.Vitals:FireClient(run.Player, {
		HP = ps.HP,
		MaxHP = ps.MaxHP,
		Mana = ps.Mana,
		MaxMana = ps.MaxMana,
		Stamina = ps.Stamina,
		MaxStamina = ps.MaxStamina,
		Shield = math.ceil(ps.ShieldHP),
		Winded = os.clock() < ps.WindedUntil,
	})
end

---------------------------------------------------------------------------
-- Pack
---------------------------------------------------------------------------

function PlayerStateService.FindItem(run, itemId: string): number?
	for i, it in run.PS.Pack do
		if it and it.Id == itemId then
			return i
		end
	end
	return nil
end

-- Adds an item to the pack, stacking where possible. Returns success.
function PlayerStateService.AddItem(run, itemId: string, count: number?, bonus: number?, spell: string?): boolean
	local def = Items[itemId]
	if type(def) ~= "table" or def.Category == "Gold" or def.Category == "Treasure" then
		return false
	end
	local n = count or 1
	local pack = run.PS.Pack
	if def.Stackable then
		for _, it in pack do
			if it and it.Id == itemId then
				it.Count += n
				PlayerStateService.Push(run.Player)
				return true
			end
		end
	end
	for i, it in pack do
		if it == false then
			pack[i] = entry(itemId, n, bonus, spell)
			PlayerStateService.Push(run.Player)
			return true
		end
	end
	return false
end

-- Removes one item from a stack (the slot empties when the stack does).
function PlayerStateService.TakeOne(run, slot: number)
	local it = run.PS.Pack[slot]
	if not it then
		return
	end
	it.Count -= 1
	if it.Count <= 0 then
		run.PS.Pack[slot] = false
	end
	PlayerStateService.Push(run.Player)
end

function PlayerStateService.RemoveSlot(run, slot: number)
	run.PS.Pack[slot] = false
	PlayerStateService.Push(run.Player)
end

function PlayerStateService.SwapSlots(run, a: number, b: number)
	local pack = run.PS.Pack
	pack[a], pack[b] = pack[b], pack[a]
	PlayerStateService.Push(run.Player)
end

-- Wields/wears the item in `slot`; whatever was equipped takes its place.
function PlayerStateService.Equip(run, slot: number)
	local ps = run.PS
	local it = ps.Pack[slot]
	local def = it and Items[it.Id]
	if not it or not def then
		return
	end
	local name = Items.EntryName(it)
	if def.Category == "Weapon" then
		local old = ps.Weapon
		ps.Weapon = it
		ps.Pack[slot] = old
		local quirk = if def.Quirk then (" " .. def.Quirk) else ""
		PlayerStateService.Message(run, "You are now wielding the " .. name .. "." .. quirk)
	elseif def.Category == "Armor" then
		local old = ps.Armor
		ps.Armor = it
		ps.Pack[slot] = old or false
		PlayerStateService.Message(run, "You are now wearing the " .. name .. ".")
	else
		return
	end
	S.ProgressionService.Recalc(run)
	PlayerStateService.DressGear(run)
	Remotes.Effect:FireClient(run.Player, { Kind = "Equip" })
	PlayerStateService.Push(run.Player)
end

---------------------------------------------------------------------------
-- Health, mana, stamina, gold, experience
---------------------------------------------------------------------------

function PlayerStateService.Heal(run, amount: number)
	local ps = run.PS
	ps.HP = math.min(ps.MaxHP, ps.HP + amount)
	PlayerStateService.Push(run.Player)
end

function PlayerStateService.AddMana(run, amount: number)
	local ps = run.PS
	ps.Mana = math.clamp(ps.Mana + amount, 0, ps.MaxMana)
end

-- Spends stamina; returns false (and does nothing) if winded or short.
-- An attack can always be started with any stamina left: it just empties
-- the bar and leaves you winded.
function PlayerStateService.SpendStamina(run, amount: number): boolean
	local ps = run.PS
	local now = os.clock()
	if now < ps.WindedUntil or ps.Stamina <= 0 then
		return false
	end
	if PlayerStateService.Hasted(run) then
		amount *= 0.5
	end
	ps.Stamina -= amount
	ps.StaminaSpentAt = now
	if ps.Stamina <= 0 then
		ps.Stamina = 0
		ps.WindedUntil = now + Config.Stamina.WindedTime
		Remotes.Effect:FireClient(run.Player, { Kind = "Winded" })
		PlayerStateService.ApplySpeed(run)
	end
	PlayerStateService.PushVitals(run)
	return true
end

function PlayerStateService.AddFuel(run, amount: number)
	run.PS.Fuel = math.min(L.MaxFuel, run.PS.Fuel + amount)
	PlayerStateService.UpdateLantern(run)
	PlayerStateService.Push(run.Player)
end

function PlayerStateService.AddGold(run, amount: number)
	if amount <= 0 then
		return
	end
	amount = math.floor(amount * (1 + mod(run, "GoldMult")) + 0.5)
	run.PS.Gold += amount
	Remotes.Effect:FireClient(run.Player, { Kind = "Gold" })
	PlayerStateService.Push(run.Player)
	return amount
end

function PlayerStateService.AddExp(run, amount: number)
	local ps = run.PS
	if amount <= 0 then
		return
	end
	ps.Exp += math.max(1, math.floor(amount * (1 + mod(run, "ExpMult")) + 0.5))
	local need = nextLevelExp(ps.Level)
	while need and ps.Exp >= need do
		ps.Level += 1
		S.ProgressionService.OnLevelUp(run)
		ps.HP = math.min(ps.MaxHP, ps.HP + Config.Player.HealthPerLevel)
		ps.Mana = ps.MaxMana
		local slotNote = if table.find(Config.Spells.SlotLevels, ps.Level) then " You gained a spell slot." else ""
		Remotes.Notice:FireClient(run.Player, {
			Kind = "LevelUp",
			Title = "Level " .. ps.Level .. "!",
			Text = string.format("+%d max health, +%d max mana.%s Choose a perk (press L).", Config.Player.HealthPerLevel, Config.Mana.PerLevel, slotNote),
		})
		Remotes.Effect:FireClient(run.Player, { Kind = "LevelUp" })
		S.RunDirector.RecordEvent(run, "Level" .. ps.Level, "Reached experience level " .. ps.Level .. ".")
		need = nextLevelExp(ps.Level)
		PlayerStateService.DressGear(run)
	end
	PlayerStateService.Push(run.Player)
end

-- `cause` is a short id used for the death screen. Armor and shields reduce
-- damage; `attacker` (a creature) takes Thorns damage.
function PlayerStateService.Damage(run, amount: number, cause: string, fromPos: Vector3?, attacker: any?)
	if run.State ~= "Active" then
		return
	end
	local ps = run.PS
	local now = os.clock()
	if now < ps.InvulnUntil then
		Remotes.Effect:FireClient(run.Player, { Kind = "Dodged" })
		return
	end
	ps.InvulnUntil = now + Config.Player.InvulnerableAfterHit
	local block = math.min(Config.ArmorCap, PlayerStateService.ArmorValue(run) * Config.ArmorPerPoint)
	local raw = amount * (1 + mod(run, "DamageTaken"))
	local dealt = if cause == "Fire" or cause == "Fell" then math.floor(raw + 0.5) else math.max(1, math.floor(raw * (1 - block) + 0.5))
	-- Stoneskin soaks damage first.
	if ps.ShieldHP > 0 and now < ps.ShieldUntil then
		local soak = math.min(ps.ShieldHP, dealt)
		ps.ShieldHP -= soak
		dealt -= soak
		Remotes.Effect:FireClient(run.Player, { Kind = "ShieldHit", Broken = ps.ShieldHP <= 0 })
	end
	ps.HP = math.max(0, ps.HP - dealt)
	run.Stats.LastHitBy = cause
	Remotes.Effect:FireClient(run.Player, { Kind = "Hurt", Amount = dealt, From = fromPos, Heavy = dealt >= ps.MaxHP * 0.2 })
	-- A shove away from the source keeps hits readable.
	local root = run.Player.Character and run.Player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and fromPos then
		local away = root.Position - fromPos
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude > 0.1 then
			root.AssemblyLinearVelocity = away.Unit * (22 + amount * 1.5) + Vector3.new(0, 4, 0)
		end
	end
	if attacker and mod(run, "Thorns") > 0 then
		S.CreatureService.Hurt(run, attacker, mod(run, "Thorns"), root and root.Position or fromPos or Vector3.zero, { Source = "Thorns" })
	end
	-- Second Wind: once per level, a near-death heal.
	if ps.HP > 0 and ps.HP < ps.MaxHP * 0.25 and mod(run, "SecondWind") > 0 and not ps.SecondWindUsed then
		ps.SecondWindUsed = true
		ps.HP = math.floor(ps.MaxHP * 0.5)
		PlayerStateService.Message(run, "Second Wind! You catch your breath.")
		Remotes.Effect:FireClient(run.Player, { Kind = "Heal" })
	end
	PlayerStateService.Push(run.Player)
	if ps.HP <= 0 then
		S.RunDirector.Fail(run, cause)
	end
end

function PlayerStateService.SetCreep(run, creep: boolean)
	run.PS.Creep = creep
	PlayerStateService.ApplySpeed(run)
	PlayerStateService.Push(run.Player)
end

function PlayerStateService.Tick(run, dt: number)
	local ps = run.PS
	local now = os.clock()
	if ps.Fuel > 0 then
		local drain = L.DrainPerSecond * dt * (if ps.Dim then L.DimDrainMultiplier else 1) * math.max(0.2, 1 + mod(run, "LanternDrain"))
		local before = ps.Fuel
		ps.Fuel = math.max(0, ps.Fuel - drain)
		if ps.Fuel <= 0 then
			PlayerStateService.UpdateLantern(run)
			PlayerStateService.Message(run, "Your lantern is out of oil. Press R to refill it with an oil flask.")
		end
		if math.floor(before / 5) ~= math.floor(ps.Fuel / 5) then
			PlayerStateService.Push(run.Player)
		end
	end
	-- Stamina refills after a short pause; mana trickles back.
	local changed = false
	if ps.Stamina < ps.MaxStamina and now - ps.StaminaSpentAt > Config.Stamina.RegenDelay and now >= ps.WindedUntil then
		ps.Stamina = math.min(ps.MaxStamina, ps.Stamina + Config.Stamina.Regen * (1 + mod(run, "StaminaRegen")) * dt)
		changed = true
	end
	if ps.Mana < ps.MaxMana then
		ps.Mana = math.min(ps.MaxMana, ps.Mana + Config.Mana.Regen * (1 + mod(run, "ManaRegen")) * dt)
		changed = true
	end
	if ps.ShieldHP > 0 and now >= ps.ShieldUntil then
		ps.ShieldHP = 0
		changed = true
	end
	if changed and now - ps.LastVitals > 0.1 then
		ps.LastVitals = now
		PlayerStateService.PushVitals(run)
	end
end

function PlayerStateService.Init(registry)
	S = registry
	Remotes.RequestLantern.OnServerEvent:Connect(function(player)
		local run = S.RunDirector.GetRun(player)
		if not run or run.State ~= "Active" then
			return
		end
		run.PS.Dim = not run.PS.Dim
		PlayerStateService.UpdateLantern(run)
		PlayerStateService.Push(player)
	end)
	Remotes.RequestCreep.OnServerEvent:Connect(function(player, creep)
		if type(creep) ~= "boolean" then
			return
		end
		local run = S.RunDirector.GetRun(player)
		if not run or run.State ~= "Active" then
			return
		end
		PlayerStateService.SetCreep(run, creep)
	end)
end

return PlayerStateService
