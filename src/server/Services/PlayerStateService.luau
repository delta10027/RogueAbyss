--!strict
-- Authoritative per-run player state: health, experience, gold, strength,
-- equipment, the pack, lantern fuel and sneaking. Also dresses the character
-- so it reads as a small cloaked explorer with a lantern (ART_BIBLE §13).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local FloorRules = require(Shared.Definitions.FloorRules)
local Abilities = require(Shared.Definitions.Abilities)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerStateService = {}

local S: any

local L = Config.Lantern

export type Entry = { Id: string, Count: number, Bonus: number }

export type State = {
	HP: number,
	MaxHP: number,
	Str: number,
	Gold: number,
	Exp: number,
	Level: number,
	Weapon: Entry,
	Armor: Entry?,
	Fuel: number,
	Dim: boolean,
	Creep: boolean,
	Pack: { Entry | false },
	Cooldowns: { [string]: number },
	Kills: number,
	InvulnUntil: number,
	LastNoiseAt: number,
	LastStepAt: number,
	Light: PointLight?,
	LanternPart: BasePart?,
}

local function entry(id: string, count: number?, bonus: number?): Entry
	return { Id = id, Count = count or 1, Bonus = bonus or 0 }
end
PlayerStateService.Entry = entry

function PlayerStateService.NewState(): State
	local pack = {}
	for i = 1, Config.Player.PackSlots do
		pack[i] = false
	end
	return {
		HP = Config.Player.MaxHealth,
		MaxHP = Config.Player.MaxHealth,
		Str = Config.Player.Strength,
		Gold = 0,
		Exp = 0,
		Level = 1,
		Weapon = entry(Config.Player.StartWeapon),
		Armor = entry(Config.Player.StartArmor),
		Fuel = L.MaxFuel,
		Dim = false,
		Creep = false,
		Pack = pack,
		Cooldowns = {},
		Kills = 0,
		InvulnUntil = 0,
		LastNoiseAt = 0,
		LastStepAt = 0,
		Light = nil,
		LanternPart = nil,
	}
end

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
	local hand = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if head then
		local hood = gear(character, "Hood", head.Size * Vector3.new(1.35, 1.25, 1.35), Color3.fromRGB(54, 40, 34), Enum.Material.Fabric)
		weldTo(hood, head, CFrame.new(0, 0.12, 0.08))
	end
	if torso then
		local cloak = gear(character, "Cloak", Vector3.new(torso.Size.X * 1.15, 3.6, 0.3), Color3.fromRGB(70, 36, 34), Enum.Material.Fabric)
		weldTo(cloak, torso, CFrame.new(0, -0.9, torso.Size.Z / 2 + 0.2) * CFrame.Angles(math.rad(-6), 0, 0))
		local pack = gear(character, "Satchel", Vector3.new(1.2, 1, 0.6), Color3.fromRGB(84, 62, 44), Enum.Material.Fabric)
		weldTo(pack, torso, CFrame.new(-0.9, -0.8, -0.3))
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

-- Shows the wielded weapon on the left hand and tints the torso to the armor,
-- so equipment changes are visible from the top-down camera.
function PlayerStateService.DressGear(run)
	local character = run.Player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("WeaponModel")
	if old then
		old:Destroy()
	end
	local hand = (character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")) :: BasePart?
	local def = Items[run.PS.Weapon.Id]
	if hand and def then
		local long = ({ Dagger = 1.6, Mace = 3, Spear = 6.5, LongSword = 4, TwoHandedSword = 5.5, Quarterstaff = 5.5 } :: any)[def.Id] or 4
		local w = gear(character, "WeaponModel", Vector3.new(0.25, long, 0.25), def.Color, if def.Id == "Quarterstaff" or def.Id == "Spear" then Enum.Material.Wood else Enum.Material.Metal)
		weldTo(w, hand, CFrame.new(0, -0.3, -long / 2 + 0.4) * CFrame.Angles(math.rad(90), 0, 0))
	end
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local armor = run.PS.Armor and Items[run.PS.Armor.Id]
	if torso then
		if armor and armor.Id ~= "LeatherArmor" then
			torso.Color = armor.Color
			torso.Material = Enum.Material.Metal
		else
			torso.Color = Color3.fromRGB(62, 50, 42)
			torso.Material = Enum.Material.Fabric
		end
	end
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
	local ps: State = run.PS
	if ps.Fuel <= 0 then
		return L.EmptyRange
	end
	return if ps.Dim then L.DimRange else L.LitRange
end

function PlayerStateService.UpdateLantern(run)
	local ps: State = run.PS
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

function PlayerStateService.ArmorValue(run): number
	local a = run.PS.Armor
	local def = a and Items[a.Id]
	if not a or not def or not def.Armor then
		return 0
	end
	return math.max(0, def.Armor + a.Bonus)
end

-- Effective stats of the wielded weapon, strength included.
function PlayerStateService.WeaponStats(run)
	local w = run.PS.Weapon
	local def = Items[w.Id]
	local ws = (def and def.Weapon) or (Items.Quarterstaff.Weapon :: any)
	local strBonus = math.max(0, run.PS.Str - Config.Player.Strength)
	return {
		Damage = math.max(1, ws.Damage + w.Bonus + strBonus),
		Range = ws.Range,
		Arc = ws.Arc,
		Cooldown = ws.Cooldown,
		Windup = ws.Windup,
		Noise = ws.Noise,
	}
end

local function nextLevelExp(level: number): number?
	return Config.Levels[level + 1]
end

function PlayerStateService.Unlocked(run, abilityId: string): boolean
	local def = Abilities.ById[abilityId]
	return def ~= nil and run.PS.Level >= def.Level
end

local function copyEntry(e: Entry?)
	return if e then { Id = e.Id, Count = e.Count, Bonus = e.Bonus } else nil
end

function PlayerStateService.Push(player: Player)
	local run = S.RunDirector.GetRun(player)
	if not run or not run.Floor then
		return
	end
	local ps: State = run.PS
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
	Remotes.StateUpdate:FireClient(player, {
		HP = ps.HP,
		MaxHP = ps.MaxHP,
		Str = ps.Str,
		Gold = ps.Gold,
		Exp = ps.Exp,
		Level = ps.Level,
		NextExp = nextLevelExp(ps.Level),
		LevelExp = Config.Levels[ps.Level] or 0,
		Armor = PlayerStateService.ArmorValue(run),
		Damage = PlayerStateService.WeaponStats(run).Damage,
		Weapon = copyEntry(ps.Weapon),
		ArmorItem = copyEntry(ps.Armor),
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

function PlayerStateService.FindItem(run, itemId: string): number?
	for i, it in run.PS.Pack do
		if it and it.Id == itemId then
			return i
		end
	end
	return nil
end

-- Adds an item to the pack, stacking where possible. Returns success.
function PlayerStateService.AddItem(run, itemId: string, count: number?, bonus: number?): boolean
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
			pack[i] = entry(itemId, n, bonus)
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
	local ps: State = run.PS
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
		PlayerStateService.Message(run, "You are now wielding the " .. name .. ".")
	elseif def.Category == "Armor" then
		local old = ps.Armor
		ps.Armor = it
		ps.Pack[slot] = old or false
		PlayerStateService.Message(run, "You are now wearing the " .. name .. ".")
	else
		return
	end
	PlayerStateService.DressGear(run)
	Remotes.Effect:FireClient(run.Player, { Kind = "Equip" })
	PlayerStateService.Push(run.Player)
end

function PlayerStateService.Heal(run, amount: number)
	local ps: State = run.PS
	ps.HP = math.min(ps.MaxHP, ps.HP + amount)
	PlayerStateService.Push(run.Player)
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
	run.PS.Gold += amount
	Remotes.Effect:FireClient(run.Player, { Kind = "Gold" })
	PlayerStateService.Push(run.Player)
end

function PlayerStateService.AddExp(run, amount: number)
	local ps: State = run.PS
	if amount <= 0 then
		return
	end
	ps.Exp += amount
	local need = nextLevelExp(ps.Level)
	while need and ps.Exp >= need do
		ps.Level += 1
		ps.MaxHP += Config.Player.HealthPerLevel
		ps.HP = math.min(ps.MaxHP, ps.HP + Config.Player.HealthPerLevel)
		Remotes.Notice:FireClient(run.Player, {
			Kind = "LevelUp",
			Title = "Level up!",
			Text = string.format("Welcome to experience level %d. Max health +%d.", ps.Level, Config.Player.HealthPerLevel),
		})
		for _, a in Abilities.List do
			if a.Level == ps.Level then
				Remotes.Notice:FireClient(run.Player, {
					Kind = "Unlock",
					Title = "New " .. string.lower(a.Kind) .. ": " .. a.Name .. "  [" .. a.Key .. "]",
					Text = a.Description,
				})
			end
		end
		Remotes.Effect:FireClient(run.Player, { Kind = "LevelUp" })
		S.RunDirector.RecordEvent(run, "Level" .. ps.Level, "Reached experience level " .. ps.Level .. ".")
		need = nextLevelExp(ps.Level)
	end
	PlayerStateService.Push(run.Player)
end

-- `cause` is a short id used for the death screen. Armor reduces damage.
function PlayerStateService.Damage(run, amount: number, cause: string, fromPos: Vector3?)
	if run.State ~= "Active" then
		return
	end
	local ps: State = run.PS
	local now = os.clock()
	if now < ps.InvulnUntil then
		return
	end
	ps.InvulnUntil = now + Config.Player.InvulnerableAfterHit
	local block = math.min(Config.ArmorCap, PlayerStateService.ArmorValue(run) * Config.ArmorPerPoint)
	local dealt = if cause == "Fire" then amount else math.max(1, math.floor(amount * (1 - block) + 0.5))
	ps.HP = math.max(0, ps.HP - dealt)
	run.Stats.LastHitBy = cause
	Remotes.Effect:FireClient(run.Player, { Kind = "Hurt", Amount = dealt, From = fromPos })
	-- A small shove away from the source keeps hits readable.
	local root = run.Player.Character and run.Player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and fromPos then
		local away = root.Position - fromPos
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude > 0.1 then
			root.AssemblyLinearVelocity = away.Unit * 28 + Vector3.new(0, 4, 0)
		end
	end
	PlayerStateService.Push(run.Player)
	if ps.HP <= 0 then
		S.RunDirector.Fail(run, cause)
	end
end

function PlayerStateService.SetCreep(run, creep: boolean)
	run.PS.Creep = creep
	local humanoid = run.Player.Character and run.Player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if creep then Config.Player.CreepSpeed else Config.Player.WalkSpeed
	end
	PlayerStateService.Push(run.Player)
end

function PlayerStateService.Tick(run, dt: number)
	local ps: State = run.PS
	if ps.Fuel > 0 then
		local drain = L.DrainPerSecond * dt * (if ps.Dim then L.DimDrainMultiplier else 1)
		local before = ps.Fuel
		ps.Fuel = math.max(0, ps.Fuel - drain)
		if ps.Fuel <= 0 then
			PlayerStateService.UpdateLantern(run)
			PlayerStateService.Message(run, "Your lantern is out of oil. Press R to refill it with an oil flask.")
		end
		-- Push in coarse steps; the client interpolates.
		if math.floor(before / 5) ~= math.floor(ps.Fuel / 5) then
			PlayerStateService.Push(run.Player)
		end
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
