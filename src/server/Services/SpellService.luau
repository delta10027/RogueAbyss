--!strict
-- Spells (Definitions/Spells) and the dash. Spells live in a limited number
-- of slots, are learned from spellbooks, cost mana and have cooldowns.
-- The client asks with a slot index and an aim point; the server checks
-- everything and decides every outcome.
--
-- RequestAbility(kind, arg, aim):
--   "Dash"                 dodge (stamina)
--   "Spell", slotIndex     cast the spell in that slot
--   "Special"              the wielded weapon's own move (CombatService)
--   "Forget", slotIndex    forget a spell to free its slot

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Spells = require(Shared.Definitions.Spells)
local Monsters = require(Shared.Definitions.Monsters)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Parent.Builder.Kit)

local SpellService = {}

local S: any

local LIGHT_SECONDS = 25
local LIGHT_RADIUS = 18
SpellService.LightRadius = LIGHT_RADIUS

local function rootOf(run): BasePart?
	local character = run.Player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function msg(run, text: string)
	S.PlayerStateService.Message(run, text)
end

local function mod(run, key: string): number
	return (run.Mods and run.Mods[key]) or 0
end

-- Spell damage after spell power (and fire bonus for fire spells).
local function power(run, base: number, fire: boolean?): number
	local m = 1 + mod(run, "SpellPower")
	if fire then
		m += mod(run, "FireMult")
	end
	return base * m
end

local function name(cr): string
	return cr.DisplayName or (Monsters[cr.Kind] and Monsters[cr.Kind].Name) or cr.Kind
end

local function fx(run, e)
	Remotes.Effect:FireClient(run.Player, e)
end

-- The monster nearest the aim line (within `width` of it), up to `range` away.
local function targetAlong(run, from: Vector3, aim: Vector3, range: number, width: number)
	local dir = flat(aim - from)
	if dir.Magnitude < 0.1 then
		return nil
	end
	dir = dir.Unit
	local best, bestScore = nil, math.huge
	for _, cr in run.Creatures do
		local rel = flat(cr.Root.Position - from)
		local t = rel:Dot(dir)
		if t > 0 and t <= range then
			local side = (rel - dir * t).Magnitude
			if side <= width + t * 0.15 then
				local score = t + side * 2
				if score < bestScore and S.LightService.LineOfSight(run, from + Vector3.new(0, 2, 0), cr.Root.Position + Vector3.new(0, 1, 0)) then
					best, bestScore = cr, score
				end
			end
		end
	end
	return best
end

local handlers: { [string]: (any, Vector3?) -> boolean } = {}

handlers.MagicMissile = function(run, aim)
	local root = rootOf(run)
	if not root or not aim then
		return false
	end
	local from = root.Position
	local dir = flat(aim - from)
	dir = if dir.Magnitude > 0.1 then dir.Unit else flat(root.CFrame.LookVector).Unit
	local targets = {}
	for _, cr in run.Creatures do
		local rel = flat(cr.Root.Position - from)
		if rel.Magnitude <= 32 and (rel.Magnitude < 3 or rel.Unit:Dot(dir) > 0.45) and S.LightService.LineOfSight(run, from + Vector3.new(0, 2, 0), cr.Root.Position + Vector3.new(0, 1, 0)) then
			table.insert(targets, cr)
		end
	end
	table.sort(targets, function(a, b)
		return (a.Root.Position - from).Magnitude < (b.Root.Position - from).Magnitude
	end)
	local dmg = power(run, 4)
	for i = 1, 3 do
		local cr = targets[((i - 1) % math.max(1, #targets)) + 1]
		local to = if cr then cr.Root.Position else (from + dir * 24 + Vector3.new((i - 2) * 3, 2, 0))
		fx(run, { Kind = "Missile", From = from + Vector3.new(0, 2, 0), To = to, Index = i, Color = Spells.ById.MagicMissile.Color })
		if cr then
			task.delay(0.22 + i * 0.07, function()
				if cr.Model.Parent and run.State == "Active" then
					S.CreatureService.Hurt(run, cr, dmg, from, { Source = "Spell" })
				end
			end)
		end
	end
	S.NoiseService.Emit(run, from, 10, "Strike", true)
	return true
end

handlers.Firebolt = function(run, aim)
	local root = rootOf(run)
	if not root or not aim then
		return false
	end
	local from = root.Position
	local to = S.ItemService.LandingPoint(run, aim, 40) or from
	local hit = targetAlong(run, from, to, (to - from).Magnitude + 1, 2.5)
	local at = if hit then hit.Root.Position else to
	local travel = math.clamp((at - from).Magnitude / 70, 0.1, 0.6)
	fx(run, { Kind = "Fireball", From = from + Vector3.new(0, 2, 0), To = at, Time = travel })
	task.delay(travel, function()
		if run.State ~= "Active" or not run.Built then
			return
		end
		S.CombatService.Explode(run, at, 7, power(run, 10, true), { Source = "Spell", Fire = true, Burn = 3 })
	end)
	return true
end

handlers.FrostNova = function(run, _aim)
	local root = rootOf(run)
	if not root then
		return false
	end
	local n = 0
	for _, cr in S.CreatureService.InRadius(run, root.Position, 11) do
		S.CreatureService.Hurt(run, cr, power(run, 4), root.Position, { Source = "Spell", NoKnockback = true })
		S.CreatureService.Status(run, cr, "Freeze", 2.5)
		n += 1
	end
	fx(run, { Kind = "FrostNova", Pos = root.Position, Radius = 11 })
	S.NoiseService.Emit(run, root.Position, 14, "Strike", true)
	if n == 0 then
		msg(run, "The air around you freezes, but nothing is caught in it.")
	end
	return true
end

handlers.Blink = function(run, aim)
	local root = rootOf(run)
	local character = run.Player.Character
	if not root or not character or not aim then
		return false
	end
	local to = S.ItemService.LandingPoint(run, aim, 20)
	if not to then
		return false
	end
	local look = flat(to - root.Position)
	local up = to + Vector3.new(0, 3, 0)
	local cf = if look.Magnitude > 0.1 then CFrame.lookAt(up, up + look) else CFrame.new(up)
	fx(run, { Kind = "Blink", From = root.Position, To = to })
	character:PivotTo(cf)
	run.PS.InvulnUntil = math.max(run.PS.InvulnUntil, os.clock() + 0.3)
	return true
end

handlers.ChainLightning = function(run, aim)
	local root = rootOf(run)
	if not root or not aim then
		return false
	end
	local from = root.Position
	local first = targetAlong(run, from, aim, 30, 6)
	if not first then
		msg(run, "There is nothing there for the lightning to strike.")
		return false
	end
	local points = { from + Vector3.new(0, 2, 0) }
	local hitSet = {}
	local cur = first
	local dmg = power(run, 8)
	for _ = 1, 4 do
		hitSet[cur] = true
		table.insert(points, cur.Root.Position)
		S.CreatureService.Hurt(run, cur, dmg, from, { Source = "Spell", Shock = true })
		local nextCr, nextD = nil, 13
		for _, cr in run.Creatures do
			if not hitSet[cr] and cr.Model.Parent then
				local d = (cr.Root.Position - cur.Root.Position).Magnitude
				if d < nextD then
					nextCr, nextD = cr, d
				end
			end
		end
		if not nextCr then
			break
		end
		cur = nextCr
	end
	fx(run, { Kind = "Lightning", Points = points })
	S.NoiseService.Emit(run, from, 18, "Strike", true)
	return true
end

handlers.DrainLife = function(run, aim)
	local root = rootOf(run)
	if not root or not aim then
		return false
	end
	local cr = targetAlong(run, root.Position, aim, 26, 6)
	if not cr then
		msg(run, "There is nothing there to drain.")
		return false
	end
	local amount = power(run, 7)
	fx(run, { Kind = "Drain", From = cr.Root.Position, To = root.Position })
	if S.CreatureService.Hurt(run, cr, amount, root.Position, { Source = "Spell", NoKnockback = true }) then
		S.PlayerStateService.Heal(run, math.floor(amount + 0.5))
	end
	return true
end

handlers.Stoneskin = function(run, _aim)
	local ps = run.PS
	ps.ShieldHP = math.floor(15 * (1 + mod(run, "SpellPower") * 0.5))
	ps.ShieldUntil = os.clock() + 12
	fx(run, { Kind = "Stoneskin" })
	msg(run, string.format("Your skin hardens like stone. (absorbs %d damage)", ps.ShieldHP))
	return true
end

handlers.Haste = function(run, _aim)
	local ps = run.PS
	ps.HasteUntil = os.clock() + 8
	ps.Stamina = ps.MaxStamina
	ps.WindedUntil = 0
	S.PlayerStateService.ApplySpeed(run)
	task.delay(8.1, function()
		if run.State == "Active" then
			S.PlayerStateService.ApplySpeed(run)
		end
	end)
	fx(run, { Kind = "Haste", Seconds = 8 })
	msg(run, "You feel yourself moving faster.")
	return true
end

handlers.ScareMonster = function(run, _aim)
	local root = rootOf(run)
	if not root then
		return false
	end
	local n = 0
	for _, cr in S.CreatureService.InRadius(run, root.Position, 14) do
		if cr.Kind ~= "Watcher" then
			S.CreatureService.Status(run, cr, "Fear", 5)
			n += 1
		end
	end
	fx(run, { Kind = "Scare", Pos = root.Position, Radius = 14 })
	msg(run, if n > 0 then "You hear maniacal laughter. The monsters flee!" else "You hear maniacal laughter in the distance.")
	return true
end

handlers.HoldMonster = function(run, aim)
	local root = rootOf(run)
	if not root or not aim then
		return false
	end
	local cr = targetAlong(run, root.Position, aim, 26, 6)
	if not cr then
		msg(run, "There is nothing there to hold.")
		return false
	end
	S.CreatureService.Status(run, cr, "Hold", 5)
	fx(run, { Kind = "Hold", Pos = cr.Root.Position, From = root.Position })
	msg(run, "The " .. name(cr) .. " freezes in place.")
	return true
end

handlers.Light = function(run, aim)
	if not aim then
		return false
	end
	local pos = S.ItemService.LandingPoint(run, aim, 34)
	if not pos then
		return false
	end
	local orb = Kit.Part(run.Built.Folder, {
		Name = "LightSpell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.4, 1.4, 1.4),
		CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)),
		Color = Color3.fromRGB(255, 226, 170),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		CanQuery = false,
	})
	orb.Transparency = 0.2
	Kit.PointLight(orb, Color3.fromRGB(255, 220, 160), LIGHT_RADIUS + 6, 2, true)
	table.insert(run.Lights, { Pos = pos, Part = orb, Until = os.clock() + LIGHT_SECONDS })
	fx(run, { Kind = "LightSpell", Pos = pos })
	return true
end

handlers.SlowMonster = function(run, _aim)
	local root = rootOf(run)
	if not root then
		return false
	end
	local n = 0
	for _, cr in S.CreatureService.InRadius(run, root.Position, 16) do
		S.CreatureService.Status(run, cr, "Slow", 7)
		n += 1
	end
	fx(run, { Kind = "SlowWave", Pos = root.Position, Radius = 16 })
	msg(run, if n > 0 then string.format("%d monster%s slow down.", n, if n == 1 then "" else "s") else "Nothing nearby is affected.")
	return true
end

handlers.Meteor = function(run, aim)
	if not aim then
		return false
	end
	local at = S.ItemService.LandingPoint(run, aim, 40)
	if not at then
		return false
	end
	fx(run, { Kind = "MeteorWarn", Pos = at, Radius = 9, Time = 1.1 })
	task.delay(1.1, function()
		if run.State ~= "Active" or not run.Built then
			return
		end
		S.CombatService.Explode(run, at, 9, power(run, 22, true), { Source = "Spell", Fire = true, Burn = 4, Big = true })
		S.ItemService.StartFire(run, at)
	end)
	return true
end

---------------------------------------------------------------------------

function SpellService.Cast(run, slot: number, aim: Vector3?)
	local id = run.PS.Spells[slot]
	local def = id and Spells.ById[id]
	if not def then
		return
	end
	local ps = run.PS
	local now = os.clock()
	if now < (ps.Cooldowns[id] or 0) - 0.15 then
		return
	end
	if ps.Mana < def.Mana then
		msg(run, string.format("Not enough mana for %s (%d needed).", def.Name, def.Mana))
		fx(run, { Kind = "NoMana" })
		return
	end
	local ok, result = pcall(handlers[id], run, aim)
	if not ok then
		warn("[Spell] " .. id .. " failed: " .. tostring(result))
		return
	end
	if result then
		ps.Mana -= def.Mana
		ps.Cooldowns[id] = now + def.Cooldown
		run.Stats.SpellsCast = (run.Stats.SpellsCast or 0) + 1
		fx(run, { Kind = "Cast", Spell = id })
		S.PlayerStateService.Push(run.Player)
	end
end

function SpellService.Dash(run)
	local ps = run.PS
	local now = os.clock()
	if now < (ps.Cooldowns.Dash or 0) - 0.1 then
		return false
	end
	local cost = Config.Stamina.Dash * math.max(0.2, 1 + mod(run, "DashCost"))
	if not S.PlayerStateService.SpendStamina(run, cost) then
		return false
	end
	ps.Cooldowns.Dash = now + 0.6
	ps.InvulnUntil = math.max(ps.InvulnUntil, now + 0.35)
	if mod(run, "Riposte") > 0 then
		ps.RiposteUntil = now + 1.5
	end
	local root = rootOf(run)
	if root then
		S.NoiseService.Emit(run, root.Position, 12, "Step", true)
	end
	return true
end

-- Learns the spell in a spellbook. Returns true if the book is used up.
function SpellService.Learn(run, spellId: string): boolean
	local def = Spells.ById[spellId]
	local ps = run.PS
	if not def then
		return false
	end
	if table.find(ps.Spells, spellId) then
		-- Re-reading a known spell restores mana instead of wasting the book.
		ps.Mana = ps.MaxMana
		msg(run, "You already know " .. def.Name .. ". The pages crumble and your mana is restored.")
		return true
	end
	if #ps.Spells >= ps.SpellSlots then
		msg(run, "All your spell slots are full. Forget a spell in your inventory (I) first.")
		return false
	end
	table.insert(ps.Spells, spellId)
	local key = Config.Spells.Keys[#ps.Spells] or "?"
	msg(run, string.format("You learn %s! Cast it with %s.", def.Name, key))
	fx(run, { Kind = "Learn", Spell = spellId })
	S.RunDirector.RecordEvent(run, "Learn" .. spellId, "Learned the spell " .. def.Name .. ".")
	return true
end

function SpellService.Forget(run, slot: number)
	local ps = run.PS
	local id = ps.Spells[slot]
	if not id or #ps.Spells <= 1 then
		msg(run, "You can't forget your last spell.")
		return
	end
	table.remove(ps.Spells, slot)
	msg(run, "You forget " .. Spells.ById[id].Name .. ".")
	S.PlayerStateService.Push(run.Player)
end

-- Spell lights burn out.
function SpellService.Tick(run, _dt: number)
	local now = os.clock()
	for i = #run.Lights, 1, -1 do
		local l = run.Lights[i]
		if now >= l.Until then
			if l.Part then
				l.Part:Destroy()
			end
			table.remove(run.Lights, i)
		end
	end
end

function SpellService.ClearRun(run)
	for _, l in run.Lights or {} do
		if l.Part then
			l.Part:Destroy()
		end
	end
	run.Lights = {}
end

function SpellService.Init(registry)
	S = registry
	Remotes.RequestAbility.OnServerEvent:Connect(function(player, kind, arg, aim)
		if type(kind) ~= "string" then
			return
		end
		if aim ~= nil and (typeof(aim) ~= "Vector3" or aim.X ~= aim.X or aim.Z ~= aim.Z) then
			return
		end
		local run = S.RunDirector.GetRun(player)
		if not run or run.State ~= "Active" or not run.Built then
			return
		end
		local slotOk = type(arg) == "number" and arg == arg and arg % 1 == 0 and arg >= 1 and arg <= Config.Spells.MaxSlots
		if kind == "Dash" then
			if SpellService.Dash(run) then
				S.PlayerStateService.PushVitals(run)
			end
		elseif kind == "Spell" and slotOk then
			SpellService.Cast(run, arg, aim)
		elseif kind == "Special" then
			S.CombatService.Special(run, aim)
		elseif kind == "Forget" and slotOk then
			SpellService.Forget(run, arg)
		end
	end)
end

return SpellService
