--!strict
-- Melee combat. Every swing costs stamina, so mashing runs dry and leaves
-- you winded. Light attacks chain into a 3-hit combo whose last hit is a
-- finisher; holding the button charges a heavy attack. Hits can crit, and
-- hitting a monster from behind (or before it notices you) is a backstab.
-- Each weapon has a passive quirk and its own special move on Q.
-- The server decides every outcome (TECH_ARCHITECTURE §17).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CombatService = {}

local S: any

local WALL_HITS = 3

local function mod(run, key: string): number
	return (run.Mods and run.Mods[key]) or 0
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(run): BasePart?
	local character = run.Player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function fx(run, e)
	Remotes.Effect:FireClient(run.Player, e)
end

-- Monsters inside an arc in front of `origin`.
local function inArc(run, origin: Vector3, look: Vector3, range: number, arcDegrees: number): { any }
	local out = {}
	local cosArc = math.cos(math.rad(math.min(arcDegrees, 359) / 2))
	for _, cr in run.Creatures do
		local to = flat(cr.Root.Position - origin)
		local d = to.Magnitude
		local reach = range + (cr.Radius or 1.2)
		if d <= reach and (d < 1.8 or arcDegrees >= 359 or look:Dot(to.Unit) >= cosArc) then
			table.insert(out, cr)
		end
	end
	table.sort(out, function(a, b)
		return (a.Root.Position - origin).Magnitude < (b.Root.Position - origin).Magnitude
	end)
	return out
end
CombatService.InArc = inArc

-- Is the attacker behind the monster, or has it not noticed anyone yet?
local function isBackstab(cr, origin: Vector3): boolean
	if cr.Kind == "Watcher" then
		return false
	end
	local unaware = cr.State == "Idle" or cr.State == "Wander" or cr.State == "Dormant" or cr.State == "Return"
	if unaware then
		return true
	end
	local facing = flat(cr.Root.CFrame.LookVector)
	local fromMe = flat(cr.Root.Position - origin)
	if facing.Magnitude < 0.01 or fromMe.Magnitude < 0.01 then
		return false
	end
	return facing.Unit:Dot(fromMe.Unit) > 0.4
end

-- Rolls damage for one target and applies it. Returns damage dealt.
local function strikeOne(run, cr, base: number, origin: Vector3, hit)
	local w = hit.Weapon
	local dmg = base
	local crit = hit.ForceCrit or math.random() < Config.Crit.Chance + mod(run, "CritChance") + (if hit.Heavy then 0.1 else 0)
	if crit then
		dmg *= Config.Crit.Multiplier + mod(run, "CritMult")
	end
	local backstab = hit.Backstab or (hit.Source == "Melee" and isBackstab(cr, origin))
	if backstab then
		local mult = Config.Combo.BackstabMultiplier + mod(run, "BackstabMult")
		if w == "Dagger" then
			mult += 0.5
		end
		dmg *= mult
	end
	hit.Crit = crit
	hit.Backstabbed = backstab
	local dealt = S.CreatureService.Hurt(run, cr, dmg, origin, hit)
	if dealt and dealt > 0 then
		-- Weapon quirks on hit.
		if w == "Mace" then
			S.CreatureService.Status(run, cr, "Stun", if hit.Heavy then 1.4 else 0.5)
		elseif w == "BattleAxe" then
			S.CreatureService.Status(run, cr, "Bleed", 3, 2)
		elseif w == "StaffOfFire" then
			S.CreatureService.Status(run, cr, "Burn", 2.5)
		elseif w == "StaffOfFrost" then
			S.CreatureService.Status(run, cr, "Slow", 2.5)
		elseif w == "StaffOfShadows" then
			S.PlayerStateService.Heal(run, 1)
		elseif w == "StaffOfStorms" then
			for _, other in run.Creatures do
				if other ~= cr and (other.Root.Position - cr.Root.Position).Magnitude < 10 then
					S.CreatureService.Hurt(run, other, math.max(1, dmg * 0.5), cr.Root.Position, { Source = "Spell", Shock = true })
					fx(run, { Kind = "Lightning", Points = { cr.Root.Position, other.Root.Position } })
					break
				end
			end
		end
		if hit.Heavy and w ~= "Mace" then
			S.CreatureService.Status(run, cr, "Stun", 0.6 * (1 + mod(run, "HeavyMult")))
		end
		if mod(run, "SpellbladeMana") > 0 then
			S.PlayerStateService.AddMana(run, mod(run, "SpellbladeMana"))
		end
	end
	return dealt or 0
end

local function strikeWalls(run, origin: Vector3, look: Vector3, range: number, weaponId: string, heavy: boolean): boolean
	local hitAny = false
	for _, k in run.Built.Cracked do
		if not k.Broken then
			local to = k.Pos - origin
			local flatTo = Vector3.new(to.X, 0, to.Z)
			if flatTo.Magnitude <= range + 2 and (flatTo.Magnitude < 2 or look:Dot(flatTo.Unit) > 0.35) then
				hitAny = true
				k.Hits += if weaponId == "Mace" or weaponId == "TwoHandedSword" then WALL_HITS elseif heavy then 2 else 1
				fx(run, { Kind = "WallHit", Pos = k.Pos, Hits = math.min(k.Hits, WALL_HITS), Max = WALL_HITS })
				if k.Hits >= WALL_HITS then
					k.Broken = true
					k.Shatter()
					fx(run, { Kind = "WallBreak", Pos = k.Pos, From = origin })
					S.NoiseService.Emit(run, k.Pos, Config.Noise.WallBreakRadius, "Wall", true)
					S.DiscoveryService.Discover(run.Player, "SecretCracks")
					S.RunDirector.RecordEvent(run, "Secret", "Broke into a hidden chamber.")
					run.Stats.SecretsFound += 1
				end
			end
		end
	end
	return hitAny
end

-- Pots, crates and barrels.
function CombatService.HitBreakables(run, origin: Vector3, look: Vector3?, range: number, arcDegrees: number, force: number, fire: boolean?): boolean
	local any = false
	local cosArc = math.cos(math.rad(math.min(arcDegrees, 359) / 2))
	for _, b in run.Built.Breakables or {} do
		if not b.Broken then
			local to = flat(b.Pos - origin)
			local d = to.Magnitude
			if d <= range + b.Radius and (not look or d < 1.5 or arcDegrees >= 359 or look:Dot(to.Unit) >= cosArc) then
				any = true
				S.ItemService.DamageBreakable(run, b, force, origin, fire)
			end
		end
	end
	return any
end

-- A blast: damages monsters (falling off with distance), breaks things,
-- lights braziers and oil barrels. `opts.HurtPlayer` for barrels.
function CombatService.Explode(run, pos: Vector3, radius: number, damage: number, opts)
	opts = opts or {}
	for _, cr in S.CreatureService.InRadius(run, pos, radius) do
		local d = (flat(cr.Root.Position - pos)).Magnitude
		local falloff = 1 - 0.4 * math.clamp(d / radius, 0, 1)
		S.CreatureService.Hurt(run, cr, damage * falloff, pos, { Source = opts.Source or "Spell", Fire = opts.Fire, Big = true })
		if opts.Burn then
			S.CreatureService.Status(run, cr, "Burn", opts.Burn)
		end
	end
	CombatService.HitBreakables(run, pos, nil, radius, 360, 5, opts.Fire)
	if opts.Fire then
		for _, b in run.Built.Braziers do
			if not b.IsLit() and (b.Pos - pos).Magnitude <= radius + 2 then
				S.ItemService.Kindle(run, b, "Oil")
			end
		end
	end
	if opts.HurtPlayer then
		local root = rootOf(run)
		if root and (flat(root.Position - pos)).Magnitude <= radius then
			S.PlayerStateService.Damage(run, math.floor(damage * 0.6), "Explosion", pos)
		end
	end
	fx(run, { Kind = "Explosion", Pos = pos, Radius = radius, Fire = opts.Fire, Big = opts.Big })
	S.NoiseService.Emit(run, pos, radius * 4, "Shatter", false)
end

---------------------------------------------------------------------------
-- Light and heavy attacks
---------------------------------------------------------------------------

function CombatService.Strike(run, heavy: boolean)
	local root = rootOf(run)
	if not root then
		return
	end
	local w = S.PlayerStateService.WeaponStats(run)
	local now = os.clock()
	run.Combat = run.Combat or { Step = 0, ReadyAt = 0, LastSwing = 0 }
	local c = run.Combat
	if now < c.ReadyAt - 0.08 then
		return
	end
	local cost = w.Stamina * (if heavy then Config.Stamina.HeavyMultiplier else 1)
	if not S.PlayerStateService.SpendStamina(run, cost) then
		S.PlayerStateService.Message(run, "You're out of breath!")
		fx(run, { Kind = "Winded" })
		return
	end
	-- Combo: swings close together chain up to a finisher.
	if heavy then
		c.Step = 0
	elseif now - c.LastSwing <= w.Cooldown + Config.Combo.Window and c.Step < 3 then
		c.Step += 1
	else
		c.Step = 1
	end
	local step = c.Step
	local finisher = step == 3
	local duration = w.Cooldown * (if heavy then 1.35 elseif finisher then 1.25 else 1)
	c.ReadyAt = now + duration
	c.LastSwing = now
	if finisher then
		c.Step = 0
	end
	local riposte = now < run.PS.RiposteUntil
	if riposte then
		run.PS.RiposteUntil = 0
	end
	local windup = w.Windup * (if heavy then 0.6 else 1)
	task.delay(windup, function()
		if run.State ~= "Active" or not root.Parent then
			return
		end
		local look = flat(root.CFrame.LookVector)
		if look.Magnitude < 0.01 then
			return
		end
		look = look.Unit
		local arc = w.Arc * (if heavy then 1.15 else 1)
		local range = w.Range * (if heavy then 1.1 else 1)
		if finisher and w.Id == "LongSword" then
			arc = 360
		elseif finisher then
			arc *= 1.2
		end
		local mult = 1
		if heavy then
			mult = Config.Combo.HeavyMultiplier * (1 + mod(run, "HeavyMult")) * (if w.Id == "TwoHandedSword" then 1.3 else 1)
		elseif finisher then
			mult = Config.Combo.FinisherMultiplier
		end
		local targets = inArc(run, root.Position, look, range, arc)
		local maxTargets = if w.Id == "Spear" then 99 elseif w.Style == "Thrust" then 1 else 3
		local knock = w.Knockback * (if heavy then 2 elseif finisher then 1.5 else 1) * (if heavy and w.Id == "TwoHandedSword" then 2 else 1)
		local landed = 0
		for i, cr in targets do
			if i > maxTargets then
				break
			end
			local dealt = strikeOne(run, cr, w.Damage * mult, root.Position, {
				Source = "Melee",
				Weapon = w.Id,
				Heavy = heavy,
				Finisher = finisher,
				Knockback = knock,
				ForceCrit = riposte,
			})
			if dealt > 0 then
				landed += 1
			end
		end
		local wall = strikeWalls(run, root.Position, look, range, w.Id, heavy)
		local broke = CombatService.HitBreakables(run, root.Position, look, range, arc, if heavy then 3 else 1)
		S.NoiseService.Emit(run, root.Position, w.Noise * (if heavy then 1.3 else 1), "Strike", true)
		if landed == 0 and not wall and not broke then
			fx(run, { Kind = "StrikeMiss", Heavy = heavy })
		end
	end)
end

---------------------------------------------------------------------------
-- Weapon specials (Q)
---------------------------------------------------------------------------

local specials: { [string]: (any, BasePart, Vector3, Vector3?, any) -> boolean } = {}

specials.Sweep = function(run, root, _look, _aim, w)
	for _, cr in inArc(run, root.Position, Vector3.zAxis, 8.5, 360) do
		strikeOne(run, cr, w.Damage, root.Position, { Source = "Melee", Weapon = w.Id, Knockback = 30 })
		S.CreatureService.Status(run, cr, "Stun", 1.5)
	end
	CombatService.HitBreakables(run, root.Position, nil, 8.5, 360, 2)
	fx(run, { Kind = "SpecialFx", Id = "Sweep", Pos = root.Position, Radius = 8.5 })
	return true
end

specials.Shadowstep = function(run, root, look, _aim, w)
	local best, bestD = nil, 15
	for _, cr in run.Creatures do
		local to = flat(cr.Root.Position - root.Position)
		if to.Magnitude < bestD and (to.Magnitude < 3 or look:Dot(to.Unit) > 0.3) and cr.Kind ~= "Watcher" then
			best, bestD = cr, to.Magnitude
		end
	end
	if not best then
		S.PlayerStateService.Message(run, "There is no one in front of you to step behind.")
		return false
	end
	local back = flat(best.Root.CFrame.LookVector)
	back = if back.Magnitude > 0.01 then back.Unit else -look
	local behind = best.Root.Position - back * 3.2
	local landing = S.ItemService.LandingPoint(run, behind, 18) or behind
	local character = run.Player.Character
	fx(run, { Kind = "Blink", From = root.Position, To = landing })
	if character then
		local up = Vector3.new(landing.X, root.Position.Y, landing.Z)
		character:PivotTo(CFrame.lookAt(up, Vector3.new(best.Root.Position.X, up.Y, best.Root.Position.Z)))
	end
	run.PS.InvulnUntil = math.max(run.PS.InvulnUntil, os.clock() + 0.4)
	task.delay(0.12, function()
		if best.Model.Parent and run.State == "Active" then
			strikeOne(run, best, w.Damage * 1.5, landing, { Source = "Melee", Weapon = w.Id, Backstab = true, Knockback = 10 })
		end
	end)
	return true
end

specials.GroundSlam = function(run, root, _look, _aim, w)
	for _, cr in S.CreatureService.InRadius(run, root.Position, 10) do
		strikeOne(run, cr, w.Damage * 1.5, root.Position, { Source = "Melee", Weapon = w.Id, Heavy = true, Knockback = 26 })
		S.CreatureService.Status(run, cr, "Stun", 2)
	end
	CombatService.HitBreakables(run, root.Position, nil, 10, 360, 3)
	fx(run, { Kind = "SpecialFx", Id = "GroundSlam", Pos = root.Position, Radius = 10 })
	S.NoiseService.Emit(run, root.Position, 40, "Wall", true)
	return true
end

specials.Lunge = function(run, root, look, _aim, w)
	local from = root.Position
	local to = S.ItemService.LandingPoint(run, from + look * 16, 16) or from
	local seg = flat(to - from)
	local len = seg.Magnitude
	local dir = if len > 0.1 then seg.Unit else look
	for _, cr in run.Creatures do
		local rel = flat(cr.Root.Position - from)
		local t = rel:Dot(dir)
		if t > -1 and t <= len + 2 and (rel - dir * t).Magnitude <= 3.2 then
			strikeOne(run, cr, w.Damage * 2, from, { Source = "Melee", Weapon = w.Id, Knockback = 18 })
		end
	end
	CombatService.HitBreakables(run, (from + to) / 2, nil, len / 2 + 1, 360, 2)
	fx(run, { Kind = "SpecialFx", Id = "Lunge", From = from, To = to })
	local character = run.Player.Character
	if character then
		local up = Vector3.new(to.X, from.Y, to.Z)
		character:PivotTo(CFrame.lookAt(up, up + dir))
	end
	run.PS.InvulnUntil = math.max(run.PS.InvulnUntil, os.clock() + 0.35)
	return true
end

specials.Whirlwind = function(run, root, _look, _aim, w)
	fx(run, { Kind = "SpecialFx", Id = "Whirlwind", Pos = root.Position, Radius = 9 })
	for i = 0, 2 do
		task.delay(i * 0.28, function()
			if run.State ~= "Active" or not root.Parent then
				return
			end
			for _, cr in inArc(run, root.Position, Vector3.zAxis, 9, 360) do
				strikeOne(run, cr, w.Damage * 0.8, root.Position, { Source = "Melee", Weapon = w.Id, Knockback = 8 })
			end
			CombatService.HitBreakables(run, root.Position, nil, 9, 360, 1)
		end)
	end
	return true
end

specials.Cleave = function(run, root, look, _aim, w)
	fx(run, { Kind = "SpecialFx", Id = "Cleave", Pos = root.Position, Dir = look })
	task.delay(0.25, function()
		if run.State ~= "Active" or not root.Parent then
			return
		end
		for _, cr in inArc(run, root.Position, look, 11, 140) do
			strikeOne(run, cr, w.Damage * 3, root.Position, { Source = "Melee", Weapon = w.Id, Heavy = true, Knockback = 45 })
		end
		CombatService.HitBreakables(run, root.Position, look, 11, 140, 4)
		strikeWalls(run, root.Position, look, 11, "TwoHandedSword", true)
	end)
	return true
end

specials.Rend = function(run, root, look, _aim, w)
	for _, cr in inArc(run, root.Position, look, 8.5, 130) do
		strikeOne(run, cr, w.Damage * 1.2, root.Position, { Source = "Melee", Weapon = w.Id, Knockback = 10 })
		S.CreatureService.Status(run, cr, "Bleed", 5, 4)
	end
	fx(run, { Kind = "SpecialFx", Id = "Rend", Pos = root.Position, Dir = look })
	return true
end

local function spellPower(run, base: number, fire: boolean?): number
	return base * (1 + mod(run, "SpellPower") + (if fire then mod(run, "FireMult") else 0))
end

specials.StaffFire = function(run, root, look, _aim, _w)
	for _, cr in inArc(run, root.Position, look, 14, 60) do
		S.CreatureService.Hurt(run, cr, spellPower(run, 5, true), root.Position, { Source = "Spell", Fire = true })
		S.CreatureService.Status(run, cr, "Burn", 4)
	end
	CombatService.HitBreakables(run, root.Position, look, 14, 60, 5, true)
	fx(run, { Kind = "SpecialFx", Id = "FireSpray", Pos = root.Position, Dir = look })
	return true
end

specials.StaffFrost = function(run, root, look, aim, _w)
	local from = root.Position
	local to = S.ItemService.LandingPoint(run, aim or (from + look * 30), 30) or (from + look * 30)
	local seg = flat(to - from)
	local len = seg.Magnitude
	local dir = if len > 0.1 then seg.Unit else look
	for _, cr in run.Creatures do
		local rel = flat(cr.Root.Position - from)
		local t = rel:Dot(dir)
		if t > 0 and t <= len + 2 and (rel - dir * t).Magnitude <= 2.6 then
			S.CreatureService.Hurt(run, cr, spellPower(run, 6), from, { Source = "Spell", NoKnockback = true })
			S.CreatureService.Status(run, cr, "Freeze", 1.5)
		end
	end
	fx(run, { Kind = "SpecialFx", Id = "IceShard", From = from + Vector3.new(0, 2, 0), To = to + Vector3.new(0, 2, 0) })
	return true
end

specials.StaffStorm = function(run, root, look, aim, _w)
	local center = aim or (root.Position + look * 15)
	local n = 0
	for _, cr in S.CreatureService.InRadius(run, center, 10) do
		if n >= 4 then
			break
		end
		n += 1
		S.CreatureService.Hurt(run, cr, spellPower(run, 7), center, { Source = "Spell", Shock = true })
		fx(run, { Kind = "Bolt", Pos = cr.Root.Position })
	end
	if n == 0 then
		fx(run, { Kind = "Bolt", Pos = center })
	end
	S.NoiseService.Emit(run, center, 30, "Strike", true)
	return true
end

specials.StaffShadow = function(run, root, _look, _aim, _w)
	local total = 0
	for _, cr in S.CreatureService.InRadius(run, root.Position, 12) do
		local dealt = S.CreatureService.Hurt(run, cr, spellPower(run, 6), root.Position, { Source = "Spell", NoKnockback = true })
		total += dealt or 0
		fx(run, { Kind = "Drain", From = cr.Root.Position, To = root.Position })
	end
	if total > 0 then
		S.PlayerStateService.Heal(run, math.floor(total / 2 + 0.5))
	end
	fx(run, { Kind = "SpecialFx", Id = "SoulHarvest", Pos = root.Position, Radius = 12 })
	return true
end

function CombatService.Special(run, aim: Vector3?)
	local root = rootOf(run)
	if not root then
		return
	end
	local ps = run.PS
	local def = Items[ps.Weapon.Id]
	local sp = def and def.Special
	if not sp then
		return
	end
	local now = os.clock()
	if now < (ps.Cooldowns.Special or 0) - 0.15 then
		return
	end
	if not S.PlayerStateService.SpendStamina(run, sp.Stamina) then
		S.PlayerStateService.Message(run, "You're too out of breath for " .. sp.Name .. ".")
		return
	end
	local look = flat(root.CFrame.LookVector)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
	local w = S.PlayerStateService.WeaponStats(run)
	local fn = specials[sp.Id]
	if not fn then
		return
	end
	local ok, result = pcall(fn, run, root, look, aim, w)
	if not ok then
		warn("[Combat] special " .. sp.Id .. " failed: " .. tostring(result))
		return
	end
	if result then
		ps.Cooldowns.Special = now + sp.Cooldown
		fx(run, { Kind = "Special", Id = sp.Id, Style = w.Style })
		S.PlayerStateService.Push(run.Player)
	end
end

function CombatService.Init(registry)
	S = registry
	Remotes.RequestStrike.OnServerEvent:Connect(function(player, kind)
		local run = S.RunDirector.GetRun(player)
		if run and run.State == "Active" then
			CombatService.Strike(run, kind == "Heavy")
		end
	end)
end

return CombatService
