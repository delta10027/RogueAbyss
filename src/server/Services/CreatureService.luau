--!strict
-- Spawns, ticks and cleans up creatures for each run. Behaviour lives in
-- ServerScriptService.Server.Creatures.*; this service provides the shared
-- context (movement, senses, damage) and a relevance-based update budget.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	Zombie = Beast,
}

-- Relevance budget (TECH_ARCHITECTURE §14): far creatures update rarely.
local NEAR = 70
local FAR_INTERVAL = 0.6
local ROUTE_REFRESH = 0.8

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

function ctx.MonsterName(kind: string): string
	local m = Monsters[kind]
	return if m then m.Name else string.lower(kind)
end

function ctx.LanternRange(run): number
	return S.PlayerStateService.LanternRange(run)
end

function ctx.LineOfSight(run, a: Vector3, b: Vector3): boolean
	return S.LightService.LineOfSight(run, a, b)
end

function ctx.Event(run, id: string, text: string)
	S.RunDirector.RecordEvent(run, id, text)
end

function ctx.DamagePlayer(run, amount: number, cause: string, fromPos: Vector3)
	S.PlayerStateService.Damage(run, amount, cause, fromPos)
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

-- Safe rooms: the shrine, and the antechamber while its doors are shut.
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

local function flatDist(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
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
	-- Re-plan when there is no route, or the goal moved (throttled).
	if not cr.Route or (goalMoved and now - (cr.RouteAt or 0) > ROUTE_REFRESH) then
		local forbid = if run.Floor.ShrineId then { [run.Floor.ShrineId] = true } else nil
		cr.Route = Nav.Route(run.Built, cr.Root.Position, goal, forbid)
		cr.RouteGoal = goal
		cr.RouteAt = now
		if not cr.Route then
			return true -- unreachable: give up so the state machine moves on
		end
	end
	if os.clock() < (cr.SlowUntil or 0) then
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
	-- Stuck detection: if no progress, skip the waypoint.
	local moved = cr.LastPos and flatDist(cr.LastPos, cr.Root.Position) or 1
	cr.LastPos = cr.Root.Position
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

-- A monster dies: experience, a possible gold drop, and a message.
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
	S.PlayerStateService.Message(run, "You defeated the " .. info.Name .. ". (+" .. info.Exp .. " exp)")
	Remotes.Effect:FireClient(run.Player, { Kind = "Kill", Pos = pos })
	if info.GoldChance > 0 and math.random() < info.GoldChance then
		local ground = Vector3.new(pos.X, run.Built.Origin.Y, pos.Z)
		S.ItemService.DropGold(run, ground, math.random(info.Gold[1], info.Gold[2]) + run.Depth)
	end
	S.PlayerStateService.AddExp(run, info.Exp)
end

function CreatureService.Init(registry)
	S = registry
end

function CreatureService.Spawn(run)
	run.Creatures = {}
	local folder = Instance.new("Folder")
	folder.Name = "Creatures"
	folder.Parent = run.Built.Holder
	run.CreatureFolder = folder
	for i, e in run.Floor.Encounters do
		local kind = KINDS[e.Kind]
		if kind then
			local pos = run.Built.Origin + Vector3.new(e.Pos.X, 0, e.Pos.Y)
			local ok, cr = pcall(kind.Build, folder, pos, e.Kind)
			if ok then
				cr.Id = i
				cr.Run = run
				cr.Home = pos
				cr.Behaviour = kind
				cr.NextTick = 0
				cr.Model:SetAttribute("Kind", e.Kind)
				table.insert(run.Creatures, cr)
			else
				warn("[CreatureService] failed to build " .. e.Kind .. ": " .. tostring(cr))
			end
		end
	end
end

function CreatureService.Tick(run, dt: number)
	local root = ctx.PlayerRoot(run)
	local now = os.clock()
	for _, cr in table.clone(run.Creatures) do
		if cr.Model.Parent then
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
				-- (Other monsters announce themselves when they spot you.)
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
		local ok, err = pcall(cr.Behaviour.OnNoise, cr, run, noise, ctx)
		if not ok then
			warn("[CreatureService] noise error: " .. tostring(err))
		end
	end
end

-- Melee from the player. Returns the creatures hit.
function CreatureService.Strike(run, origin: Vector3, look: Vector3, range: number, arcDegrees: number, damage: number): { any }
	local hits = {}
	local cosArc = math.cos(math.rad(arcDegrees / 2))
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then
		return hits
	end
	flatLook = flatLook.Unit
	for _, cr in table.clone(run.Creatures) do
		local to = cr.Root.Position - origin
		local flatTo = Vector3.new(to.X, 0, to.Z)
		local d = flatTo.Magnitude
		if d <= range + 1.2 and (d < 1.5 or flatLook:Dot(flatTo.Unit) >= cosArc) then
			table.insert(hits, cr)
			cr.Behaviour.OnStruck(cr, run, damage, origin, ctx)
		end
	end
	return hits
end

-- Burning oil hurts every living monster standing in it.
function CreatureService.BurnAt(run, pos: Vector3, radius: number)
	for _, cr in table.clone(run.Creatures) do
		if cr.Kind ~= "Watcher" and flatDist(cr.Root.Position, pos) <= radius then
			cr.Behaviour.OnStruck(cr, run, Config.OilFire.Damage, pos, ctx)
		end
	end
end

-- Damages a single creature from a spell. Returns true if it was hurt.
function CreatureService.Hurt(run, cr, damage: number, fromPos: Vector3)
	if cr.Kind == "Watcher" then
		cr.Behaviour.OnStruck(cr, run, damage, fromPos, ctx)
		return false
	end
	cr.Behaviour.OnStruck(cr, run, damage, fromPos, ctx)
	return true
end

function CreatureService.Slow(run, center: Vector3, radius: number, seconds: number): number
	local n = 0
	for _, cr in run.Creatures do
		if flatDist(cr.Root.Position, center) <= radius then
			cr.SlowUntil = os.clock() + seconds
			n += 1
		end
	end
	return n
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
end

return CreatureService
