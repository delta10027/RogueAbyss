--!strict
-- Spawns, ticks and cleans up creatures for each run. Behaviour lives in
-- ServerScriptService.Server.Creatures.*; this service provides the shared
-- context (movement, senses, damage), status effects, projectiles, depth
-- scaling and elites, and a relevance-based update budget.
--
-- Creature models are tagged "RA_Creature" with attributes the client uses
-- for health bars and status visuals: Kind, DisplayName, HP, MaxHP, Elite,
-- Status ("Stun,Burn"...), State, Lit (wraiths), Exposed.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Monsters = require(Shared.Definitions.Monsters)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Server = script.Parent.Parent
local Nav = require(Server.Creatures.Nav)
local Listener = require(Server.Creatures.Listener)
local Watcher = require(Server.Creatures.Watcher)
local Beast = require(Server.Creatures.Beast)
local Body = require(Server.Creatures.Body)

local CreatureService = {}

local S: any

local KINDS: { [string]: any } = {
	Listener = Listener,
	Watcher = Watcher,
	Rat = Beast,
	Kobold = Beast,
	Bat = Beast,
	Slime = Beast,
	Zombie = Beast,
	Skeleton = Beast,
	Orc = Beast,
	Wraith = Beast,
}

-- Relevance budget (TECH_ARCHITECTURE §14): far creatures update rarely.
local NEAR = 70
local FAR_INTERVAL = 0.6
local ROUTE_REFRESH = 0.8

local DISABLING = { Stun = true, Freeze = true, Hold = true }

local function flatDist(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function fx(run, e)
	Remotes.Effect:FireClient(run.Player, e)
end

local ctx: any = {}

function ctx.PlayerRoot(run): BasePart?
	local character = run.Player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function ctx.Discover(run, id: string)
	S.DiscoveryService.Discover(run.Player, id)
end

function ctx.Message(run, text: string)
	S.PlayerStateService.Message(run, text)
end

-- Name for messages; takes a creature or a kind id.
function ctx.MonsterName(x): string
	if type(x) == "table" then
		return x.DisplayName or ctx.MonsterName(x.Kind)
	end
	local m = Monsters[x]
	return if m then m.Name else string.lower(tostring(x))
end

function ctx.Mod(run, key: string): number
	return (run.Mods and run.Mods[key]) or 0
end

function ctx.LanternRange(run): number
	return S.PlayerStateService.LanternRange(run)
end

function ctx.LineOfSight(run, a: Vector3, b: Vector3): boolean
	return S.LightService.LineOfSight(run, a, b)
end

-- Is this spot lit for the player: inside the lantern light or a flame?
function ctx.Lit(run, pos: Vector3): boolean
	local root = ctx.PlayerRoot(run)
	if root and flatDist(root.Position, pos) <= S.PlayerStateService.LanternRange(run) then
		return true
	end
	return (S.LightService.InFlameLight(run, pos))
end

function ctx.Event(run, id: string, text: string)
	S.RunDirector.RecordEvent(run, id, text)
end

function ctx.DamagePlayer(run, amount: number, cause: string, fromPos: Vector3, attacker: any?)
	S.PlayerStateService.Damage(run, amount, cause, fromPos, attacker)
	if attacker and attacker.Kind == "Wraith" then
		-- A wraith's touch chills the lantern.
		run.PS.Fuel = math.max(0, run.PS.Fuel - 8)
		S.PlayerStateService.UpdateLantern(run)
	end
end

function ctx.LureSources(run)
	return S.LightService.LureSources(run)
end

function ctx.SeenByPlayer(run, pos: Vector3): boolean
	return S.LightService.SeenByPlayer(run, pos)
end

function ctx.InFlameLight(run, pos: Vector3): boolean
	return (S.LightService.InFlameLight(run, pos))
end

function ctx.RoomDistance(run, a: Vector3, b: Vector3): number?
	return Nav.RoomDistance(run.Built, a, b)
end

function ctx.Disabled(cr): boolean
	local now = os.clock()
	return now < (cr.StunUntil or 0) or now < (cr.FreezeUntil or 0) or now < (cr.HoldUntil or 0)
end

function ctx.Blocked(run, cr)
	fx(run, { Kind = "Blocked", Pos = cr.Root.Position, Model = cr.Model })
	-- A shield block jars your arms.
	run.PS.Stamina = math.max(0, run.PS.Stamina - 10)
	S.PlayerStateService.PushVitals(run)
	if not run.Stats.BlockHint then
		run.Stats.BlockHint = true
		ctx.Message(run, "The skeleton blocks with its shield! Hit it from behind, use a charged attack (hold click), a mace or magic.")
	end
end

function ctx.Status(run, cr, kind: string, seconds: number, power: number?)
	CreatureService.Status(run, cr, kind, seconds, power)
end

function ctx.Projectile(run, cr, from: Vector3, dir: Vector3, speed: number, damage: number, visual: string)
	CreatureService.Projectile(run, cr, from, dir, speed, damage, visual)
end

-- Safe rooms: the shrine.
function ctx.InSafeRoom(run, pos: Vector3): boolean
	local built = run.Built
	if not built then
		return false
	end
	local room = S.DungeonService.RoomAt(built, pos, 0)
	return room ~= nil and room == run.Floor.ShrineId
end

function ctx.RandomPointNear(run, center: Vector3, radius: number): Vector3
	local built = run.Built
	local room = S.DungeonService.RoomAt(built, center, 0.5)
	if room then
		local r = built.RoomRects[room]
		local x = math.clamp(center.X + (math.random() * 2 - 1) * radius, r.Min.X + 3, r.Max.X - 3)
		local z = math.clamp(center.Z + (math.random() * 2 - 1) * radius, r.Min.Z + 3, r.Max.Z - 3)
		return Vector3.new(x, center.Y, z)
	end
	return center
end

function ctx.Stop(cr)
	cr.Route = nil
	cr.RouteGoal = nil
	if not cr.Root.Anchored then
		cr.Humanoid:MoveTo(cr.Root.Position)
	end
end

-- Moves toward `goal` along a navigation route. Returns true on arrival.
function ctx.MoveTo(cr, goal: Vector3?, speed: number): boolean
	if not goal then
		return true
	end
	local run = cr.Run
	if flatDist(cr.Root.Position, goal) < 2.5 then
		ctx.Stop(cr)
		return true
	end
	local now = os.clock()
	local goalMoved = not cr.RouteGoal or flatDist(cr.RouteGoal, goal) > 4
	if not cr.Route or (goalMoved and now - (cr.RouteAt or 0) > ROUTE_REFRESH) then
		local forbid = if run.Floor.ShrineId then { [run.Floor.ShrineId] = true } else nil
		cr.Route = Nav.Route(run.Built, cr.Root.Position, goal, forbid)
		cr.RouteGoal = goal
		cr.RouteAt = now
		if not cr.Route then
			return true -- unreachable: give up so the state machine moves on
		end
	end
	if now < (cr.SlowUntil or 0) then
		speed *= 0.5
	end
	cr.Humanoid.WalkSpeed = speed
	local route = cr.Route
	while route and #route > 0 and flatDist(cr.Root.Position, route[1]) < 2.2 do
		table.remove(route, 1)
	end
	if not route or #route == 0 then
		cr.Route = nil
		return flatDist(cr.Root.Position, goal) < 4
	end
	local wp = route[1]
	cr.Humanoid:MoveTo(Vector3.new(wp.X, cr.Root.Position.Y, wp.Z))
	local moved = cr.LastPosNav and flatDist(cr.LastPosNav, cr.Root.Position) or 1
	cr.LastPosNav = cr.Root.Position
	if moved < 0.05 * speed then
		cr.Stuck = (cr.Stuck or 0) + 1
		if cr.Stuck > 12 then
			cr.Stuck = 0
			table.remove(route, 1)
			cr.Root.AssemblyLinearVelocity = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 20
		end
	else
		cr.Stuck = 0
	end
	return false
end

local function updateStatusAttr(cr)
	local now = os.clock()
	local list = {}
	for _, k in { "Stun", "Freeze", "Hold", "Burn", "Bleed", "Slow", "Fear" } do
		if now < (cr[k .. "Until"] or 0) then
			table.insert(list, k)
		end
	end
	local s = table.concat(list, ",")
	if cr.Model:GetAttribute("Status") ~= s then
		cr.Model:SetAttribute("Status", s)
	end
end

-- A monster dies: experience, healing perks, gold, and a message.
function ctx.Kill(run, cr)
	local pos = cr.Root.Position
	Body.Dissolve(cr.Model)
	local idx = table.find(run.Creatures, cr)
	if idx then
		table.remove(run.Creatures, idx)
	end
	local info = Monsters[cr.Kind]
	if not info then
		return
	end
	run.PS.Kills += 1
	run.Stats.Kills = (run.Stats.Kills or 0) + 1
	local exp = math.floor(info.Exp * (if cr.Elite then Config.Scaling.EliteExp else 1) * (1 + (run.Depth - 1) * 0.1) + 0.5)
	if cr.Small then
		exp = math.max(1, math.floor(exp / 2))
	end
	ctx.Message(run, "You defeated the " .. ctx.MonsterName(cr) .. ". (+" .. exp .. " exp)")
	fx(run, { Kind = "Kill", Pos = pos, Creature = cr.Kind, Elite = cr.Elite })
	if (info.GoldChance > 0 and math.random() < info.GoldChance) or cr.Elite then
		local ground = Vector3.new(pos.X, run.Built.Origin.Y, pos.Z)
		local amount = (math.random(info.Gold[1], info.Gold[2]) + run.Depth * 2) * (if cr.Elite then 3 else 1)
		S.ItemService.DropGold(run, ground, amount)
	end
	if cr.Elite and math.random() < 0.6 then
		S.ItemService.DropLoot(run, Vector3.new(pos.X, run.Built.Origin.Y, pos.Z), 2)
	end
	local heal = ctx.Mod(run, "Lifesteal")
	if heal > 0 then
		S.PlayerStateService.Heal(run, heal)
	end
	-- Slimes split.
	if cr.Kind == "Slime" and not cr.Small then
		for i = -1, 1, 2 do
			local spot = pos + Vector3.new(i * 2, 0, 0)
			CreatureService.SpawnOne(run, "Slime", Vector3.new(spot.X, run.Built.Origin.Y, spot.Z), { Small = true })
		end
	end
	if cr.Elite then
		ctx.Event(run, "Elite" .. cr.Kind, "Defeated a " .. ctx.MonsterName(cr) .. ".")
	end
	S.PlayerStateService.AddExp(run, exp)
end

---------------------------------------------------------------------------

function CreatureService.Init(registry)
	S = registry
end

local function eliteChance(depth: number): number
	local t = Config.Scaling.EliteChance
	return t[math.min(depth, #t)]
end

-- Builds one creature (used for floor spawns and slime splits).
function CreatureService.SpawnOne(run, kindId: string, pos: Vector3, opts: any?)
	local kind = KINDS[kindId]
	if not kind or not run.CreatureFolder then
		return nil
	end
	opts = opts or {}
	local depth = run.Depth
	local elite = opts.Elite
	local scale = if elite then 1.3 elseif opts.Small then 0.6 else 1
	local ok, cr = pcall(kind.Build, run.CreatureFolder, pos, kindId, { Scale = scale, Small = opts.Small })
	if not ok then
		warn("[CreatureService] failed to build " .. kindId .. ": " .. tostring(cr))
		return nil
	end
	cr.Id = (run.NextCreatureId or 0) + 1
	run.NextCreatureId = cr.Id
	cr.Run = run
	cr.Home = pos
	cr.Behaviour = kind
	cr.NextTick = 0
	cr.Elite = elite
	cr.Small = opts.Small
	-- Deeper levels breed tougher monsters.
	local hpMult = (1 + Config.Scaling.HealthPerDepth * (depth - 1)) * (if elite then Config.Scaling.EliteHealth else 1) * (if opts.Small then 0.4 else 1)
	cr.DamageMult = (1 + Config.Scaling.DamagePerDepth * (depth - 1)) * (if elite then Config.Scaling.EliteDamage else 1) * (if opts.Small then 0.6 else 1)
	if cr.Health then
		cr.Health = math.floor(cr.Health * hpMult + 0.5)
		cr.MaxHealth = cr.Health
	end
	local info = Monsters[kindId]
	if elite and info then
		local prefixes = Monsters.ElitePrefixes
		cr.DisplayName = prefixes[math.random(1, #prefixes)] .. " " .. info.Name
	elseif opts.Small and info then
		cr.DisplayName = "small " .. info.Name
	end
	local m = cr.Model
	m:SetAttribute("Kind", kindId)
	m:SetAttribute("DisplayName", cr.DisplayName or (info and info.Name) or kindId)
	m:SetAttribute("HP", cr.Health or 0)
	m:SetAttribute("MaxHP", cr.MaxHealth or 0)
	m:SetAttribute("Elite", elite == true)
	CollectionService:AddTag(m, "RA_Creature")
	if elite then
		-- Elites carry a faint aura so they read as dangerous at a glance.
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 70)
		light.Range = 9
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = cr.Root
	end
	table.insert(run.Creatures, cr)
	return cr
end

function CreatureService.Spawn(run)
	run.Creatures = {}
	run.Projectiles = {}
	local folder = Instance.new("Folder")
	folder.Name = "Creatures"
	folder.Parent = run.Built.Holder
	run.CreatureFolder = folder
	local rng = Random.new(run.Seed + run.Depth * 7919)
	for _, e in run.Floor.Encounters do
		local pos = run.Built.Origin + Vector3.new(e.Pos.X, 0, e.Pos.Y)
		local elite = e.Kind ~= "Listener" and e.Kind ~= "Watcher" and rng:NextNumber() < eliteChance(run.Depth)
		CreatureService.SpawnOne(run, e.Kind, pos, { Elite = elite })
	end
end

-- Applies a status effect. Kinds: Stun, Freeze, Hold, Slow, Burn, Bleed, Fear.
function CreatureService.Status(run, cr, kind: string, seconds: number, power: number?)
	if not cr.Model.Parent or cr.State == "Dead" then
		return
	end
	if cr.Kind == "Watcher" and (kind == "Burn" or kind == "Bleed" or kind == "Fear") then
		return
	end
	local now = os.clock()
	local untilT = now + seconds
	cr[kind .. "Until"] = math.max(cr[kind .. "Until"] or 0, untilT)
	if kind == "Burn" then
		cr.BurnPower = math.max(cr.BurnPower or 0, (power or 2) * (1 + ctx.Mod(run, "FireMult")))
	elseif kind == "Bleed" then
		cr.BleedPower = math.max(cr.BleedPower or 0, power or 2)
	end
	if DISABLING[kind] then
		ctx.Stop(cr)
		if kind == "Stun" and cr.State ~= "Dead" and cr.Behaviour == Beast then
			cr.State = "Stagger"
			cr.StateTime = -seconds
		end
	end
	updateStatusAttr(cr)
end

-- Damages one creature. `hit` carries context (Source, Heavy, Crit,
-- Backstabbed, Weapon, Knockback...). Returns the damage dealt.
function CreatureService.Hurt(run, cr, damage: number, fromPos: Vector3, hit): number
	if not cr.Model.Parent or cr.State == "Dead" then
		return 0
	end
	hit = hit or {}
	local now = os.clock()
	if now < (cr.HoldUntil or 0) then
		damage *= 2
	end
	if hit.Fire then
		damage *= 1 + ctx.Mod(run, "FireMult")
	end
	damage = math.max(1, math.floor(damage + 0.5))
	local ok, dealt = pcall(cr.Behaviour.OnStruck, cr, run, damage, fromPos, ctx, hit)
	if not ok then
		warn("[CreatureService] OnStruck error (" .. cr.Kind .. "): " .. tostring(dealt))
		dealt = 0
	end
	if type(dealt) ~= "number" then
		dealt = damage
	end
	if cr.Kind == "Watcher" then
		dealt = 0
	end
	if cr.Model.Parent then
		cr.Model:SetAttribute("HP", math.max(0, cr.Health or 0))
	end
	fx(run, {
		Kind = "Hit",
		Pos = cr.Root.Position,
		Model = cr.Model,
		Amount = dealt,
		Crit = hit.Crit,
		Backstab = hit.Backstabbed,
		Heavy = hit.Heavy or hit.Finisher or hit.Big,
		Blocked = hit.Blocked,
		Immune = hit.Immune or cr.Kind == "Watcher",
		Source = hit.Source,
		Element = if hit.Fire then "Fire" elseif hit.Shock then "Shock" else nil,
		Dir = (cr.Root.Position - fromPos),
	})
	if hit.Backstabbed and dealt > 0 then
		ctx.Message(run, "Backstab! " .. math.floor(dealt) .. " damage.")
	end
	return dealt
end

function CreatureService.InRadius(run, pos: Vector3, radius: number): { any }
	local out = {}
	for _, cr in run.Creatures do
		if cr.Model.Parent and flatDist(cr.Root.Position, pos) <= radius + (cr.Radius or 1) then
			table.insert(out, cr)
		end
	end
	return out
end

-- Monster projectiles (kobold spears). The server simulates the hit; the
-- client draws its own copy from the start point, direction and speed.
function CreatureService.Projectile(run, cr, from: Vector3, dir: Vector3, speed: number, damage: number, visual: string)
	run.NextProjectile = (run.NextProjectile or 0) + 1
	local p = { Id = run.NextProjectile, Pos = from, Dir = dir.Unit, Speed = speed, Damage = damage, Life = 1.2, Owner = cr, Kind = cr.Kind }
	table.insert(run.Projectiles, p)
	fx(run, { Kind = "Projectile", Id = p.Id, From = from, Dir = p.Dir, Speed = speed, Visual = visual, Life = p.Life })
end

local function tickProjectiles(run, dt: number)
	local root = ctx.PlayerRoot(run)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { run.CreatureFolder }
	if run.Player.Character then
		table.insert(exclude, run.Player.Character)
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	for i = #run.Projectiles, 1, -1 do
		local p = run.Projectiles[i]
		local step = p.Dir * p.Speed * dt
		local hitWall = Workspace:Raycast(p.Pos, step, params)
		local nextPos = p.Pos + step
		local done = false
		if root then
			-- Closest approach to the player during this step.
			local rel = root.Position - p.Pos
			local t = math.clamp(rel:Dot(step) / math.max(step:Dot(step), 1e-4), 0, 1)
			local closest = p.Pos + step * t
			if flatDist(closest, root.Position) < 2.2 then
				S.PlayerStateService.Damage(run, p.Damage, p.Kind, closest, p.Owner)
				done = true
			end
		end
		p.Life -= dt
		if hitWall or p.Life <= 0 then
			done = true
		end
		p.Pos = nextPos
		if done then
			table.remove(run.Projectiles, i)
			fx(run, { Kind = "ProjectileEnd", Id = p.Id, Pos = if hitWall then hitWall.Position else p.Pos })
		end
	end
end

local function fleeTick(cr, run, root: BasePart?)
	if not root then
		return
	end
	local away = Vector3.new(cr.Root.Position.X - root.Position.X, 0, cr.Root.Position.Z - root.Position.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
	ctx.MoveTo(cr, ctx.RandomPointNear(run, cr.Root.Position + away * 10, 2), (cr.Cfg and cr.Cfg.Speed or 10))
end

function CreatureService.Tick(run, dt: number)
	local root = ctx.PlayerRoot(run)
	local now = os.clock()
	if run.Projectiles and #run.Projectiles > 0 then
		tickProjectiles(run, dt)
	end
	for _, cr in table.clone(run.Creatures) do
		if cr.Model.Parent then
			-- Damage over time.
			if (now < (cr.BurnUntil or 0) or now < (cr.BleedUntil or 0)) and now >= (cr.NextDot or 0) then
				cr.NextDot = now + 1
				local dot = (if now < (cr.BurnUntil or 0) then cr.BurnPower or 2 else 0) + (if now < (cr.BleedUntil or 0) then cr.BleedPower or 2 else 0)
				CreatureService.Hurt(run, cr, dot, cr.Root.Position, { Source = "Dot", NoKnockback = true, Fire = false, Dot = true })
			end
			if not cr.Model.Parent then
				continue
			end
			if cr.StatusCheck == nil or now >= cr.StatusCheck then
				cr.StatusCheck = now + 0.25
				updateStatusAttr(cr)
			end
			if ctx.Disabled(cr) then
				ctx.Stop(cr)
				continue
			end
			if now < (cr.FearUntil or 0) then
				fleeTick(cr, run, root)
				continue
			end
			local far = root == nil or (cr.Root.Position - root.Position).Magnitude > NEAR
			if not far or now >= cr.NextTick then
				local step = if far then FAR_INTERVAL else dt
				cr.NextTick = now + FAR_INTERVAL
				local ok, err = pcall(cr.Behaviour.Tick, cr, run, step, ctx)
				if not ok then
					warn("[CreatureService] tick error (" .. cr.Kind .. "): " .. tostring(err))
				end
				-- Fell out of the world somehow: put it home.
				if cr.Root.Position.Y < run.Built.Origin.Y - 20 then
					cr.Root.CFrame = CFrame.new(cr.Home + Vector3.new(0, 4, 0))
				end
				-- Seeing a Listener in light teaches what it is.
				if cr.Kind == "Listener" and root and (cr.Root.Position - root.Position).Magnitude < 26 and not cr.Known then
					if S.LightService.SeenByPlayer(run, cr.Root.Position) then
						cr.Known = true
						ctx.Discover(run, "CreatureListener")
					end
				end
			end
		end
	end
end

function CreatureService.OnNoise(run, noise)
	for _, cr in run.Creatures do
		if not ctx.Disabled(cr) then
			local ok, err = pcall(cr.Behaviour.OnNoise, cr, run, noise, ctx)
			if not ok then
				warn("[CreatureService] noise error: " .. tostring(err))
			end
		end
	end
end

-- Burning oil hurts every living monster standing in it.
function CreatureService.BurnAt(run, pos: Vector3, radius: number)
	for _, cr in table.clone(run.Creatures) do
		if cr.Kind ~= "Watcher" and flatDist(cr.Root.Position, pos) <= radius then
			CreatureService.Hurt(run, cr, Config.OilFire.Damage, pos, { Source = "Fire", Fire = true, NoKnockback = true })
			CreatureService.Status(run, cr, "Burn", 2)
		end
	end
end

function CreatureService.Lurch(run, seconds: number)
	run.LurchUntil = os.clock() + seconds
end

function CreatureService.Cleanup(run)
	if run.CreatureFolder then
		run.CreatureFolder:Destroy()
		run.CreatureFolder = nil
	end
	run.Creatures = {}
	run.Projectiles = {}
end

return CreatureService
