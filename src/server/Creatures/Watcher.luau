--!strict
-- THE WATCHER
-- A hooded stone figure with a single carved eye. It cannot move while it
-- is seen in light or while it stands in firelight. Unseen, it is fast.
-- On the Tolling floor it lurches whenever the great bell sounds.
--
-- States: Dormant -> Held <-> Moving -> (Strike)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Body = require(script.Parent.Body)
local Meshes = require(script.Parent.Meshes)

local C = Config.Watcher

local Watcher = {}

local STONE = Color3.fromRGB(108, 104, 96)

local ACTIVATE_RANGE = 52
local DEACTIVATE_RANGE = 90

local MESH_LOOKS = {
	Body = { Material = Enum.Material.Slate, Color = STONE },
	Face = { Material = Enum.Material.Slate, Color = Color3.fromRGB(18, 16, 16) },
	Eye = { Material = Enum.Material.Slate, Color = Color3.fromRGB(150, 128, 92) },
}

-- Part-built body, used until the Blender mesh is imported.
local function partBody(parts)
	local function stone(name: string, size: Vector3, offset: CFrame, shape: Enum.PartType?)
		local props: { [string]: any } = { Name = name, Size = size, Color = STONE, Material = Enum.Material.Slate }
		if shape then
			props.Shape = shape
		end
		return Body.Piece(parts, props, offset)
	end
	stone("Base", Vector3.new(3.2, 1, 2.8), CFrame.new(0, -2.6, 0))
	stone("Body", Vector3.new(3, 4.6, 2.4), CFrame.new(0, -0.2, 0.1))
	stone("Shoulders", Vector3.new(4, 1.2, 2.6), CFrame.new(0, 1.9, 0.1))
	-- Hood: a peaked shape that gives a sharp, directional silhouette.
	stone("Hood", Vector3.new(2.4, 2.6, 2.6), CFrame.new(0, 3.2, -0.2) * CFrame.Angles(math.rad(-12), 0, 0))
	stone("HoodPeak", Vector3.new(1.2, 1.2, 1.6), CFrame.new(0, 4.5, 0.2) * CFrame.Angles(math.rad(35), 0, 0))
	Body.Piece(parts, {
		Name = "Eye",
		Size = Vector3.new(0.9, 0.22, 0.12),
		Color = Color3.fromRGB(150, 128, 92),
		Material = Enum.Material.Slate,
	}, CFrame.new(0, 3.1, -1.5))
	stone("ArmL", Vector3.new(0.8, 3.4, 0.9), CFrame.new(-1.8, 0.4, -0.5) * CFrame.Angles(math.rad(-25), 0, math.rad(6)))
	stone("ArmR", Vector3.new(0.8, 3.4, 0.9), CFrame.new(1.8, 0.4, -0.5) * CFrame.Angles(math.rad(-25), 0, math.rad(-6)))
end

function Watcher.Build(parent: Instance, pos: Vector3)
	local parts = Body.Root("Watcher", parent, pos, Vector3.new(2.6, 5, 2.2), 0.6)
	if not Meshes.Attach("Watcher", parts.Root, pos.Y, 7.8, MESH_LOOKS) then
		partBody(parts)
	end
	parts.Humanoid.WalkSpeed = C.MoveSpeed
	parts.Root.Anchored = true
	return {
		Kind = "Watcher",
		Model = parts.Model,
		Root = parts.Root,
		Humanoid = parts.Humanoid,
		State = "Dormant",
		StateTime = 0,
		Active = false,
		LastStrike = 0,
		LastGrind = 0,
		Seen = false,
	}
end

local function hold(cr)
	if not cr.Root.Anchored then
		cr.Humanoid:Move(Vector3.zero)
		cr.Root.AssemblyLinearVelocity = Vector3.zero
		cr.Root.Anchored = true
	end
end

local function release(cr)
	if cr.Root.Anchored then
		cr.Root.Anchored = false
		Body.ServerOwn(cr.Root)
	end
end

function Watcher.OnNoise(_cr, _run, _noise, _ctx)
	-- Stone does not listen.
end

function Watcher.OnStruck(cr, run, _damage: number, _fromPos: Vector3, ctx)
	-- Stone does not break. The blow only rings out.
	Remotes.Effect:FireClient(run.Player, { Kind = "Clang", Pos = cr.Root.Position })
	if os.clock() - (cr.LastClangMsg or 0) > 5 then
		cr.LastClangMsg = os.clock()
		ctx.Message(run, "Your weapon bounces off the Watcher. Stone can't be hurt - keep your light on it instead.")
	end
	ctx.Event(run, "StruckWatcher", "Hit a Watcher. It didn't even notice.")
end

function Watcher.Tick(cr, run, dt: number, ctx)
	cr.StateTime += dt
	local root = ctx.PlayerRoot(run)
	if not root then
		hold(cr)
		return
	end
	local myPos = cr.Root.Position
	local dist = (root.Position - myPos).Magnitude

	if not cr.Active then
		if dist <= ACTIVATE_RANGE then
			local rd = ctx.RoomDistance(run, myPos, root.Position)
			if rd and rd <= 2 then
				cr.Active = true
			end
		end
		if not cr.Active then
			hold(cr)
			return
		end
	elseif dist > DEACTIVATE_RANGE then
		cr.Active = false
		hold(cr)
		return
	end

	local seen = ctx.SeenByPlayer(run, myPos)
	local inFlame = ctx.InFlameLight(run, myPos)
	if seen and not cr.Seen then
		ctx.Discover(run, "CreatureWatcher")
	end
	cr.Seen = seen

	local lurching = os.clock() < (run.LurchUntil or 0)
	local safe = ctx.InSafeRoom(run, root.Position)
	if (seen or inFlame) and not lurching then
		if inFlame and not seen and dist < 40 then
			ctx.Discover(run, "WatcherLight")
		end
		cr.State = "Held"
		hold(cr)
		return
	end

	if safe and dist > C.StrikeRange + 2 then
		-- It waits at the threshold it cannot cross.
		cr.State = "Waiting"
		hold(cr)
		return
	end

	cr.State = "Moving"
	release(cr)
	local now = os.clock()
	if now - cr.LastGrind > 1.1 then
		cr.LastGrind = now
		Remotes.Effect:FireClient(run.Player, { Kind = "Grind", Pos = myPos })
	end
	if dist <= C.StrikeRange then
		ctx.Stop(cr)
		if now - cr.LastStrike >= C.StrikeCooldown then
			cr.LastStrike = now
			ctx.DamagePlayer(run, C.Damage * (cr.DamageMult or 1), "Watcher", myPos, cr)
		end
	else
		ctx.MoveTo(cr, root.Position, if lurching then C.MoveSpeed * 0.7 else C.MoveSpeed)
	end
end

return Watcher
