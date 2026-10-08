--!strict
-- Ordinary dungeon monsters, in the spirit of Rogue's bestiary:
--   Rat     fast, weak, comes in packs
--   Kobold  small spear-carrier, sees far in lantern light
--   Bat     flies erratically, drawn to an undimmed lantern
--   Zombie  slow, tough, hits very hard
--
-- They see the player only within the lantern's reach (+6 studs) and with a
-- clear line of sight, so dimming the lantern and sneaking matter. They also
-- come to investigate noises.
--
-- States: Idle -> Wander -> Investigate -> Chase -> Windup -> Recover
--         -> Search -> Return    (+ Stagger when struck)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Body = require(script.Parent.Body)

local Beast = {}

local LOSE_TIME = 4
local SEARCH_TIME = 6

-- Part-built silhouettes, readable from the top-down camera.
local BUILDERS: { [string]: (any, number) -> { [string]: any } } = {}

BUILDERS.Rat = function(parts, s)
	local fur = Color3.fromRGB(78, 66, 58)
	Body.Piece(parts, { Name = "Body", Size = Vector3.new(1.4, 1, 2.6) * s, Color = fur, Material = Enum.Material.Fabric }, CFrame.new(0, -0.3 * s, 0.2 * s))
	Body.Piece(parts, { Name = "Head", Size = Vector3.new(0.9, 0.8, 1.2) * s, Color = fur, Material = Enum.Material.Fabric }, CFrame.new(0, -0.2 * s, -1.5 * s))
	Body.Piece(parts, { Name = "Snout", Size = Vector3.new(0.4, 0.4, 0.5) * s, Color = Color3.fromRGB(150, 110, 104), Material = Enum.Material.SmoothPlastic }, CFrame.new(0, -0.3 * s, -2.2 * s))
	Body.Piece(parts, { Name = "EarL", Size = Vector3.new(0.4, 0.5, 0.1) * s, Color = Color3.fromRGB(130, 96, 90), Material = Enum.Material.SmoothPlastic }, CFrame.new(-0.35 * s, 0.25 * s, -1.4 * s))
	Body.Piece(parts, { Name = "EarR", Size = Vector3.new(0.4, 0.5, 0.1) * s, Color = Color3.fromRGB(130, 96, 90), Material = Enum.Material.SmoothPlastic }, CFrame.new(0.35 * s, 0.25 * s, -1.4 * s))
	Body.Piece(parts, { Name = "Tail", Size = Vector3.new(0.15, 0.15, 2.4) * s, Color = Color3.fromRGB(150, 110, 104), Material = Enum.Material.SmoothPlastic }, CFrame.new(0, -0.5 * s, 2.6 * s) * CFrame.Angles(0, math.rad(15), 0))
	return {}
end

BUILDERS.Kobold = function(parts, s)
	local skin = Color3.fromRGB(96, 84, 60)
	local rag = Color3.fromRGB(70, 52, 40)
	Body.Piece(parts, { Name = "Body", Size = Vector3.new(1.6, 2, 1.2) * s, Color = rag, Material = Enum.Material.Fabric }, CFrame.new(0, -0.3 * s, 0))
	Body.Piece(parts, { Name = "Head", Size = Vector3.new(1.2, 1, 1.5) * s, Color = skin, Material = Enum.Material.Slate }, CFrame.new(0, 1.2 * s, -0.3 * s))
	Body.Piece(parts, { Name = "HornL", Size = Vector3.new(0.2, 0.7, 0.2) * s, Color = Color3.fromRGB(170, 160, 140), Material = Enum.Material.SmoothPlastic }, CFrame.new(-0.4 * s, 1.9 * s, 0) * CFrame.Angles(math.rad(-30), 0, math.rad(15)))
	Body.Piece(parts, { Name = "HornR", Size = Vector3.new(0.2, 0.7, 0.2) * s, Color = Color3.fromRGB(170, 160, 140), Material = Enum.Material.SmoothPlastic }, CFrame.new(0.4 * s, 1.9 * s, 0) * CFrame.Angles(math.rad(-30), 0, math.rad(-15)))
	Body.Piece(parts, { Name = "LegL", Size = Vector3.new(0.5, 1.2, 0.5) * s, Color = skin, Material = Enum.Material.Slate }, CFrame.new(-0.45 * s, -1.7 * s, 0))
	Body.Piece(parts, { Name = "LegR", Size = Vector3.new(0.5, 1.2, 0.5) * s, Color = skin, Material = Enum.Material.Slate }, CFrame.new(0.45 * s, -1.7 * s, 0))
	local _, spear = Body.Piece(parts, { Name = "Spear", Size = Vector3.new(0.2, 0.2, 4.5) * s, Color = Color3.fromRGB(110, 86, 60), Material = Enum.Material.Wood }, CFrame.new(1 * s, 0.2 * s, -0.8 * s))
	Body.Piece(parts, { Name = "Tip", Size = Vector3.new(0.3, 0.3, 0.6) * s, Color = Color3.fromRGB(140, 136, 128), Material = Enum.Material.Metal }, CFrame.new(1 * s, 0.2 * s, -3.3 * s))
	return { Weapon = spear }
end

BUILDERS.Bat = function(parts, s)
	local hide = Color3.fromRGB(52, 44, 44)
	Body.Piece(parts, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2) * s, Color = hide, Material = Enum.Material.Fabric }, CFrame.new())
	Body.Piece(parts, { Name = "EarL", Size = Vector3.new(0.25, 0.5, 0.1) * s, Color = hide, Material = Enum.Material.Fabric }, CFrame.new(-0.3 * s, 0.7 * s, -0.2 * s))
	Body.Piece(parts, { Name = "EarR", Size = Vector3.new(0.25, 0.5, 0.1) * s, Color = hide, Material = Enum.Material.Fabric }, CFrame.new(0.3 * s, 0.7 * s, -0.2 * s))
	local _, wl = Body.Piece(parts, { Name = "WingL", Size = Vector3.new(2.6, 0.1, 1.4) * s, Color = Color3.fromRGB(70, 58, 58), Material = Enum.Material.Fabric }, CFrame.new(-1.7 * s, 0, 0))
	local _, wr = Body.Piece(parts, { Name = "WingR", Size = Vector3.new(2.6, 0.1, 1.4) * s, Color = Color3.fromRGB(70, 58, 58), Material = Enum.Material.Fabric }, CFrame.new(1.7 * s, 0, 0))
	-- Wings flap continuously (hinged at the body).
	local info = TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(wl, info, { C0 = CFrame.new(-1.3 * s, 0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(-40)) }):Play()
	TweenService:Create(wr, info, { C0 = CFrame.new(1.3 * s, 0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(40)) }):Play()
	return {}
end

BUILDERS.Zombie = function(parts, s)
	local flesh = Color3.fromRGB(104, 112, 88)
	local cloth = Color3.fromRGB(56, 50, 46)
	Body.Piece(parts, { Name = "Torso", Size = Vector3.new(2.2, 2.4, 1.2) * s, Color = cloth, Material = Enum.Material.Fabric }, CFrame.new(0, 0.3 * s, 0) * CFrame.Angles(math.rad(-12), 0, 0))
	Body.Piece(parts, { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2) * s, Color = flesh, Material = Enum.Material.Slate }, CFrame.new(0.2 * s, 2 * s, -0.4 * s) * CFrame.Angles(0, 0, math.rad(14)))
	Body.Piece(parts, { Name = "LegL", Size = Vector3.new(0.8, 2.2, 0.8) * s, Color = cloth, Material = Enum.Material.Fabric }, CFrame.new(-0.55 * s, -2 * s, 0))
	Body.Piece(parts, { Name = "LegR", Size = Vector3.new(0.8, 2.2, 0.8) * s, Color = cloth, Material = Enum.Material.Fabric }, CFrame.new(0.55 * s, -2 * s, 0))
	-- Arms held out in front: the classic shambling silhouette.
	local _, al = Body.Piece(parts, { Name = "ArmL", Size = Vector3.new(0.6, 0.6, 2.4) * s, Color = flesh, Material = Enum.Material.Slate }, CFrame.new(-1.4 * s, 1 * s, -1.2 * s))
	local _, ar = Body.Piece(parts, { Name = "ArmR", Size = Vector3.new(0.6, 0.6, 2.4) * s, Color = flesh, Material = Enum.Material.Slate }, CFrame.new(1.4 * s, 1 * s, -1.2 * s))
	return { ArmL = al, ArmR = ar }
end

function Beast.Build(parent: Instance, pos: Vector3, kind: string)
	local cfg = Config.Beasts[kind]
	local s = cfg.Size
	local rootSize = if kind == "Rat" then Vector3.new(1.4, 1.4, 2.6) * s
		elseif kind == "Bat" then Vector3.new(1.4, 1.4, 1.4) * s
		elseif kind == "Zombie" then Vector3.new(2.2, 3.2, 1.4) * s
		else Vector3.new(1.6, 2.6, 1.2) * s
	local hip = if kind == "Bat" then 4.5 elseif kind == "Rat" then 0.2 elseif kind == "Zombie" then 1.6 * s else 1.2 * s
	local parts = Body.Root(kind, parent, pos, rootSize, hip)
	local welds = BUILDERS[kind](parts, s)
	parts.Humanoid.WalkSpeed = cfg.WanderSpeed
	Body.ServerOwn(parts.Root)
	local w = {}
	for k, v in welds do
		w[k] = v
		w[k .. "0"] = v.C0
	end
	return {
		Kind = kind,
		Model = parts.Model,
		Root = parts.Root,
		Humanoid = parts.Humanoid,
		Cfg = cfg,
		Welds = w,
		Health = cfg.Health,
		State = "Idle",
		StateTime = 0,
		Target = nil :: Vector3?,
		NextWander = math.random() * 3,
		LastSeen = 0,
		LastAttack = 0,
		Jitter = Vector3.zero,
		NextJitter = 0,
	}
end

local function setState(cr, state: string, target: Vector3?)
	cr.State = state
	cr.StateTime = 0
	if target then
		cr.Target = target
	end
end

-- Raised weapon / arms: every attack is telegraphed.
local function pose(cr, alert: number)
	local w = cr.Welds
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad)
	if w.Weapon then
		TweenService:Create(w.Weapon, info, { C0 = w.Weapon0 * CFrame.new(0, alert * 0.8, alert * 1.2) * CFrame.Angles(math.rad(25 * alert), 0, 0) }):Play()
	end
	if w.ArmL then
		TweenService:Create(w.ArmL, info, { C0 = w.ArmL0 * CFrame.new(0, alert * 1, alert * 0.4) * CFrame.Angles(math.rad(40 * alert), 0, 0) }):Play()
		TweenService:Create(w.ArmR, info, { C0 = w.ArmR0 * CFrame.new(0, alert * 1, alert * 0.4) * CFrame.Angles(math.rad(40 * alert), 0, 0) }):Play()
	end
end

-- (Slow Monster is applied centrally in CreatureService's MoveTo.)
local function speed(_cr, base: number): number
	return base
end

-- Can this monster see the player right now?
local function seesPlayer(cr, run, ctx, root: BasePart): boolean
	local d = (root.Position - cr.Root.Position).Magnitude
	if d < 3.5 then
		return true
	end
	local reach = ctx.LanternRange(run) + 6
	local sight = cr.Cfg.Sight
	if cr.Kind == "Bat" and not run.PS.Dim and run.PS.Fuel > 0 then
		sight *= 1.5 -- bats are drawn to a bright lantern
	end
	local limit = math.min(sight, reach)
	if run.PS.Creep then
		limit *= 0.6
	end
	if d > limit then
		return false
	end
	return ctx.LineOfSight(run, cr.Root.Position + Vector3.new(0, 1, 0), root.Position + Vector3.new(0, 1, 0))
end

function Beast.OnNoise(cr, run, noise, ctx)
	if cr.State == "Chase" or cr.State == "Windup" or cr.State == "Recover" or cr.State == "Dead" or cr.State == "Stagger" then
		return
	end
	local dist = (noise.Pos - cr.Root.Position).Magnitude
	if dist <= noise.Radius * cr.Cfg.Hearing then
		setState(cr, "Investigate", noise.Pos)
	end
end

function Beast.OnStruck(cr, run, damage: number, fromPos: Vector3, ctx)
	if cr.State == "Dead" then
		return
	end
	cr.Health -= damage
	if cr.Health <= 0 then
		cr.State = "Dead"
		ctx.Kill(run, cr)
		return
	end
	local away = cr.Root.Position - fromPos
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude > 0.1 then
		cr.Root.AssemblyLinearVelocity = away.Unit * (if cr.Kind == "Zombie" then 8 else 20)
	end
	pose(cr, 0)
	setState(cr, "Stagger", fromPos)
end

function Beast.Tick(cr, run, dt: number, ctx)
	cr.StateTime += dt
	local cfg = cr.Cfg
	local root = ctx.PlayerRoot(run)
	local state = cr.State
	if state == "Dead" then
		return
	end

	local sees = root ~= nil and seesPlayer(cr, run, ctx, root)
	if sees and root then
		cr.LastSeen = os.clock()
		cr.LastSeenPos = root.Position
		if state == "Idle" or state == "Wander" or state == "Investigate" or state == "Search" or state == "Return" then
			setState(cr, "Chase", root.Position)
			Remotes.Effect:FireClient(run.Player, { Kind = "Alert", Pos = cr.Root.Position, Creature = cr.Kind })
			ctx.Discover(run, "Creature" .. cr.Kind)
			state = "Chase"
		end
	end

	if state == "Idle" then
		ctx.Stop(cr)
		cr.NextWander -= dt
		if cr.NextWander <= 0 then
			cr.NextWander = 3 + math.random() * 4
			setState(cr, "Wander", ctx.RandomPointNear(run, cr.Home, 9))
		end
	elseif state == "Wander" then
		if ctx.MoveTo(cr, cr.Target, speed(cr, cfg.WanderSpeed)) or cr.StateTime > 8 then
			setState(cr, "Idle")
		end
	elseif state == "Investigate" then
		if ctx.MoveTo(cr, cr.Target, speed(cr, cfg.Speed * 0.7)) or cr.StateTime > 15 then
			setState(cr, "Search", cr.Target)
		end
	elseif state == "Chase" then
		if not root then
			setState(cr, "Search")
			return
		end
		if os.clock() - cr.LastSeen > LOSE_TIME then
			setState(cr, "Search", cr.LastSeenPos)
			return
		end
		local d = (root.Position - cr.Root.Position).Magnitude
		if d <= cfg.Reach * 0.85 and os.clock() - cr.LastAttack > cfg.Cooldown and not ctx.InSafeRoom(run, root.Position) then
			ctx.Stop(cr)
			setState(cr, "Windup")
			pose(cr, 1)
			Remotes.Effect:FireClient(run.Player, { Kind = "Telegraph", Pos = cr.Root.Position, Creature = cr.Kind })
			return
		end
		local goal = if sees then root.Position else (cr.LastSeenPos or root.Position)
		if cfg.Fly then
			-- Bats never fly straight.
			if os.clock() > cr.NextJitter then
				cr.NextJitter = os.clock() + 0.4
				local a = math.random() * math.pi * 2
				cr.Jitter = Vector3.new(math.cos(a), 0, math.sin(a)) * math.min(5, d * 0.5)
			end
			goal += cr.Jitter
		end
		if d > 2.5 then
			ctx.MoveTo(cr, goal, speed(cr, cfg.Speed))
		else
			ctx.Stop(cr)
		end
	elseif state == "Windup" then
		if root then
			local look = Vector3.new(root.Position.X, cr.Root.Position.Y, root.Position.Z)
			if (look - cr.Root.Position).Magnitude > 0.5 then
				cr.Root.CFrame = CFrame.lookAt(cr.Root.Position, look)
			end
		end
		if cr.StateTime >= cfg.Windup then
			cr.LastAttack = os.clock()
			if root then
				local to = root.Position - cr.Root.Position
				local flat = Vector3.new(to.X, 0, to.Z)
				if flat.Magnitude <= cfg.Reach and not ctx.InSafeRoom(run, root.Position) then
					ctx.DamagePlayer(run, cfg.Damage, cr.Kind, cr.Root.Position)
				else
					ctx.Message(run, "The " .. ctx.MonsterName(cr.Kind) .. " misses.")
				end
			end
			pose(cr, 0.2)
			setState(cr, "Recover")
		end
	elseif state == "Recover" then
		ctx.Stop(cr)
		if cr.StateTime > 0.45 then
			pose(cr, 0)
			setState(cr, "Chase")
		end
	elseif state == "Stagger" then
		if cr.StateTime > 0.35 then
			setState(cr, "Chase", if root then root.Position else cr.Target)
			cr.LastSeen = os.clock()
			cr.LastSeenPos = if root then root.Position else cr.Root.Position
		end
	elseif state == "Search" then
		if cr.StateTime > SEARCH_TIME then
			setState(cr, "Return", cr.Home)
		elseif not cr.SearchPoint or ctx.MoveTo(cr, cr.SearchPoint, speed(cr, cfg.WanderSpeed + 1)) then
			cr.SearchPoint = ctx.RandomPointNear(run, cr.Target or cr.Root.Position, 8)
		end
	elseif state == "Return" then
		if ctx.MoveTo(cr, cr.Home, speed(cr, cfg.WanderSpeed + 1)) or cr.StateTime > 30 then
			setState(cr, "Idle")
		end
	end
end

return Beast
