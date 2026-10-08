--!strict
-- THE LISTENER
-- Blind. Hunts by sound alone. Tall robed body, featureless head, two great
-- ear-fans that read as a "T" from the top-down camera.
--
-- State machine (TECH_ARCHITECTURE §12):
--   Idle -> Investigate -> Pursue -> Attack -> Search -> Return -> Idle
--   (+ Lured under the Hungry Dark, + Stagger when struck)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Body = require(script.Parent.Body)
local Meshes = require(script.Parent.Meshes)

local C = Config.Listener

local Listener = {}

local ROBE = Color3.fromRGB(62, 57, 58)
local SKIN = Color3.fromRGB(170, 160, 146)
-- Desaturated membrane: warm light must not turn it into "danger red".
local FAN = Color3.fromRGB(88, 78, 74)

local MESH_LOOKS = {
	Body = { Material = Enum.Material.Fabric, Color = ROBE },
	EarL = { Material = Enum.Material.Fabric, Color = FAN },
	EarR = { Material = Enum.Material.Fabric, Color = FAN },
	ArmL = { Material = Enum.Material.SmoothPlastic, Color = SKIN },
	ArmR = { Material = Enum.Material.SmoothPlastic, Color = SKIN },
}

-- Part-built body, used until the Blender mesh is imported.
local function partBody(parts)
	Body.Piece(parts, { Name = "Robe", Size = Vector3.new(2.8, 5.6, 2.2), Color = ROBE, Material = Enum.Material.Fabric }, CFrame.new(0, -0.5, 0))
	Body.Piece(parts, { Name = "Hem", Size = Vector3.new(3.4, 0.6, 2.8), Color = ROBE, Material = Enum.Material.Fabric }, CFrame.new(0, -3.1, 0))
	Body.Piece(parts, { Name = "Neck", Size = Vector3.new(0.8, 1.6, 0.8), Color = SKIN, Material = Enum.Material.SmoothPlastic }, CFrame.new(0, 2.8, -0.2) * CFrame.Angles(math.rad(-18), 0, 0))
	Body.Piece(parts, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.7, 2.1, 1.7),
		Color = SKIN,
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(0, 3.9, -0.6))
	local _, fanL = Body.Piece(parts, { Name = "EarL", Size = Vector3.new(3.2, 2.4, 0.18), Color = FAN, Material = Enum.Material.Fabric }, CFrame.new(-1.9, 4.1, -0.4) * CFrame.Angles(0, math.rad(-20), math.rad(14)))
	local _, fanR = Body.Piece(parts, { Name = "EarR", Size = Vector3.new(3.2, 2.4, 0.18), Color = FAN, Material = Enum.Material.Fabric }, CFrame.new(1.9, 4.1, -0.4) * CFrame.Angles(0, math.rad(20), math.rad(-14)))
	-- Long thin arms hang inside the robe and show only when it attacks.
	local _, armL = Body.Piece(parts, { Name = "ArmL", Size = Vector3.new(0.35, 3.6, 0.35), Color = SKIN, Material = Enum.Material.SmoothPlastic }, CFrame.new(-1.1, 0.2, -0.6))
	local _, armR = Body.Piece(parts, { Name = "ArmR", Size = Vector3.new(0.35, 3.6, 0.35), Color = SKIN, Material = Enum.Material.SmoothPlastic }, CFrame.new(1.1, 0.2, -0.6))
	return fanL, fanR, armL, armR
end

function Listener.Build(parent: Instance, pos: Vector3)
	local parts = Body.Root("Listener", parent, pos, Vector3.new(2.2, 4, 1.6), 1.2)
	local fanL, fanR, armL, armR
	local mesh = Meshes.Attach("Listener", parts.Root, pos.Y, 10, MESH_LOOKS)
	if mesh and mesh.EarL and mesh.EarR and mesh.ArmL and mesh.ArmR then
		fanL, fanR, armL, armR = mesh.EarL.Weld, mesh.EarR.Weld, mesh.ArmL.Weld, mesh.ArmR.Weld
	else
		fanL, fanR, armL, armR = partBody(parts)
	end
	parts.Humanoid.WalkSpeed = C.WanderSpeed
	Body.ServerOwn(parts.Root)
	return {
		Kind = "Listener",
		Model = parts.Model,
		Root = parts.Root,
		Humanoid = parts.Humanoid,
		Welds = {
			FanL = fanL,
			FanR = fanR,
			ArmL = armL,
			ArmR = armR,
			FanL0 = fanL.C0,
			FanR0 = fanR.C0,
			ArmL0 = armL.C0,
			ArmR0 = armR.C0,
		},
		Health = C.Health,
		State = "Idle",
		StateTime = 0,
		Target = nil :: Vector3?,
		NextWander = 2,
		LureRef = nil :: any,
	}
end

local function setState(cr, state: string, target: Vector3?)
	cr.State = state
	cr.StateTime = 0
	if target then
		cr.Target = target
	end
end

-- Fans spread and arms rise: the attack is telegraphed (GAME_DESIGN §13).
local function pose(cr, alert: number)
	local w = cr.Welds
	local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
	TweenService:Create(w.FanL, info, { C0 = w.FanL0 * CFrame.Angles(0, math.rad(-25 * alert), math.rad(20 * alert)) }):Play()
	TweenService:Create(w.FanR, info, { C0 = w.FanR0 * CFrame.Angles(0, math.rad(25 * alert), math.rad(-20 * alert)) }):Play()
	TweenService:Create(w.ArmL, info, { C0 = w.ArmL0 * CFrame.new(0, alert * 1.2, -alert * 0.8) * CFrame.Angles(math.rad(70 * alert), 0, 0) }):Play()
	TweenService:Create(w.ArmR, info, { C0 = w.ArmR0 * CFrame.new(0, alert * 1.2, -alert * 0.8) * CFrame.Angles(math.rad(70 * alert), 0, 0) }):Play()
end

local function playerCanBeHeardHere(cr, run, ctx, root: BasePart): boolean
	local d = (root.Position - cr.Root.Position).Magnitude
	if d <= 3.5 then
		return true
	end
	return d <= C.AttackRange and os.clock() - run.PS.LastNoiseAt < 1.4 and not ctx.InSafeRoom(run, root.Position)
end

function Listener.OnNoise(cr, run, noise, ctx)
	if cr.State == "Attack" or cr.State == "Stagger" or cr.State == "Dead" then
		return
	end
	local dist = (noise.Pos - cr.Root.Position).Magnitude
	if dist > noise.Radius then
		return
	end
	if noise.FromPlayer and dist > noise.BaseRadius then
		-- Only the floor's rule could have carried that sound this far.
		ctx.Discover(run, "RuleEchoes")
	end
	if noise.Kind == "Bell" then
		local root = ctx.PlayerRoot(run)
		if root and (root.Position - noise.Pos).Magnitude > 14 then
			ctx.Discover(run, "ListenerLured")
			ctx.Event(run, "LuredListener", "Sent a Listener after a bell.")
		end
	end
	local loud = noise.Kind == "Bell" or noise.Kind == "Shatter" or noise.Kind == "Wall" or noise.Kind == "Strike"
	if dist <= C.AlertRadius or loud or cr.State == "Pursue" then
		setState(cr, "Pursue", noise.Pos)
	else
		setState(cr, "Investigate", noise.Pos)
	end
	pose(cr, 0.5)
end

function Listener.OnStruck(cr, run, damage: number, fromPos: Vector3, ctx)
	if cr.State == "Dead" then
		return
	end
	cr.Health -= damage
	if cr.Health <= 0 then
		cr.State = "Dead"
		ctx.Event(run, "FelledListener", "Felled a Listener.")
		ctx.Kill(run, cr)
		return
	end
	-- Recoil away from the blow.
	local away = cr.Root.Position - fromPos
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude > 0.1 then
		cr.Root.AssemblyLinearVelocity = away.Unit * 22
	end
	pose(cr, 0)
	setState(cr, "Stagger", fromPos)
end

function Listener.Tick(cr, run, dt: number, ctx)
	cr.StateTime += dt
	local root = ctx.PlayerRoot(run)
	local state = cr.State

	if state == "Dead" then
		return
	end

	-- Under the Hungry Dark, flame pulls a calm or searching Listener.
	if run.RuleFlags.LightLure and (state == "Idle" or state == "Search" or state == "Return" or state == "Investigate") then
		local best, bestD = nil, math.huge
		for _, src in ctx.LureSources(run) do
			local d = (src.Pos - cr.Root.Position).Magnitude
			-- A lantern is a small flame; it only carries a short way.
			local limit = if src.Kind == "Lantern" then C.LightLureRadius * 0.6 else C.LightLureRadius
			if d < limit and d < bestD then
				best, bestD = src, d
			end
		end
		if best then
			cr.LureRef = best
			setState(cr, "Lured", best.Pos)
			ctx.Discover(run, "RuleHungryDark")
			if best.Kind ~= "Lantern" then
				ctx.Event(run, "FlameLure", "Drew a Listener to a flame.")
			end
		end
	end

	if state == "Idle" then
		ctx.Stop(cr)
		cr.NextWander -= dt
		if cr.NextWander <= 0 then
			cr.NextWander = 4 + math.random() * 4
			cr.Target = ctx.RandomPointNear(run, cr.Home, 7)
			setState(cr, "Wander", cr.Target)
		end
	elseif state == "Wander" then
		if ctx.MoveTo(cr, cr.Target, C.WanderSpeed) or cr.StateTime > 8 then
			setState(cr, "Idle")
		end
	elseif state == "Investigate" then
		if ctx.MoveTo(cr, cr.Target, C.InvestigateSpeed) or cr.StateTime > 20 then
			setState(cr, "Search")
		end
	elseif state == "Pursue" then
		if root and playerCanBeHeardHere(cr, run, ctx, root) then
			setState(cr, "Attack")
			ctx.Stop(cr)
			pose(cr, 1)
			Remotes.Effect:FireClient(run.Player, { Kind = "Telegraph", Pos = cr.Root.Position, Creature = "Listener" })
		elseif ctx.MoveTo(cr, cr.Target, C.PursueSpeed) or cr.StateTime > 15 then
			setState(cr, "Search")
		end
	elseif state == "Lured" then
		local src = cr.LureRef
		if src and src.Kind == "Lantern" then
			if run.PS.Dim or run.PS.Fuel <= 0 or not root then
				setState(cr, "Search", cr.Target)
				return
			end
			cr.Target = root.Position
			if playerCanBeHeardHere(cr, run, ctx, root) or (root.Position - cr.Root.Position).Magnitude < C.AttackRange then
				setState(cr, "Attack")
				ctx.Stop(cr)
				pose(cr, 1)
				Remotes.Effect:FireClient(run.Player, { Kind = "Telegraph", Pos = cr.Root.Position, Creature = "Listener" })
				return
			end
		elseif src then
			local stillLit = false
			for _, s in ctx.LureSources(run) do
				if s.Ref == src.Ref then
					stillLit = true
				end
			end
			if not stillLit then
				setState(cr, "Search", src.Pos)
				return
			end
		end
		local d = (cr.Target - cr.Root.Position).Magnitude
		if d > 5 then
			ctx.MoveTo(cr, cr.Target, C.InvestigateSpeed)
		else
			ctx.Stop(cr)
		end
	elseif state == "Attack" then
		if cr.StateTime >= C.AttackWindup then
			if root then
				local to = root.Position - cr.Root.Position
				local flatTo = Vector3.new(to.X, 0, to.Z)
				if flatTo.Magnitude <= C.AttackReach and not ctx.InSafeRoom(run, root.Position) then
					ctx.DamagePlayer(run, C.Damage, "Listener", cr.Root.Position)
				end
			end
			pose(cr, 0.3)
			setState(cr, "Recover")
		else
			-- Turn toward the last sound while rearing.
			if root then
				local look = Vector3.new(root.Position.X, cr.Root.Position.Y, root.Position.Z)
				if (look - cr.Root.Position).Magnitude > 0.5 then
					cr.Root.CFrame = CFrame.lookAt(cr.Root.Position, look)
				end
			end
		end
	elseif state == "Recover" then
		ctx.Stop(cr)
		if cr.StateTime > 0.9 then
			pose(cr, 0)
			setState(cr, "Search", if root then root.Position else cr.Target)
		end
	elseif state == "Stagger" then
		if cr.StateTime > 0.6 then
			setState(cr, "Pursue", if root then root.Position else cr.Target)
		end
	elseif state == "Search" then
		if cr.StateTime > C.SearchDuration then
			pose(cr, 0)
			setState(cr, "Return", cr.Home)
		else
			if not cr.SearchPoint or ctx.MoveTo(cr, cr.SearchPoint, 6) then
				cr.SearchPoint = ctx.RandomPointNear(run, cr.Target or cr.Root.Position, 8)
			end
		end
	elseif state == "Return" then
		if ctx.MoveTo(cr, cr.Home, C.WanderSpeed + 2) or cr.StateTime > 30 then
			setState(cr, "Idle")
		end
	end
end

return Listener
