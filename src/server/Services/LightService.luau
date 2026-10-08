--!strict
-- Answers questions about light, which several systems care about:
--   Watchers freeze when observed in light or standing in firelight.
--   Under the Hungry Dark, Listeners are drawn to flame.
-- Fires themselves are owned by ItemService; this service only reads them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local LightService = {}

local S: any

function LightService.Init(registry)
	S = registry
end

export type Source = { Pos: Vector3, Radius: number, Kind: string, Ref: any }

-- Static and temporary flames in the run (not the lantern).
function LightService.Flames(run): { Source }
	local out = {}
	if run.Built then
		for id, b in run.Built.Braziers do
			if b.IsLit() then
				table.insert(out, { Pos = b.Pos, Radius = Config.Brazier.LightRadius * 0.75, Kind = "Brazier", Ref = id })
			end
		end
	end
	for _, f in run.Fires do
		table.insert(out, { Pos = f.Pos, Radius = Config.OilFire.LightRange * 0.6, Kind = "Fire", Ref = f })
	end
	-- The Light spell counts as firelight.
	for _, l in run.Lights or {} do
		table.insert(out, { Pos = l.Pos, Radius = S.SpellService.LightRadius, Kind = "Spell", Ref = l })
	end
	return out
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function lineOfSight(run, from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { run.CreatureFolder }
	if run.Player.Character then
		table.insert(exclude, run.Player.Character)
	end
	if run.Built then
		local items = run.Built.Folder:FindFirstChild("Items")
		if items then
			table.insert(exclude, items)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(from, to - from, params)
	return hit == nil
end
LightService.LineOfSight = lineOfSight

-- Is `pos` inside a flame's light?
function LightService.InFlameLight(run, pos: Vector3): (boolean, Source?)
	for _, src in LightService.Flames(run) do
		if (flat(src.Pos) - flat(pos)).Magnitude <= src.Radius then
			return true, src
		end
	end
	return false, nil
end

-- Is `pos` currently seen by the player: inside the lantern's reach, within
-- the facing cone, and not hidden behind walls or pillars.
function LightService.SeenByPlayer(run, pos: Vector3): boolean
	local character = run.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local toTarget = flat(pos) - flat(root.Position)
	local dist = toTarget.Magnitude
	local reach = S.PlayerStateService.LanternRange(run)
	local litByFlame = LightService.InFlameLight(run, pos)
	-- In firelight a thing can be seen from farther than the lantern reaches.
	local maxDist = if litByFlame then math.max(reach, 60) else reach
	if dist > maxDist then
		return false
	end
	if dist > 2.5 then
		local facing = flat(root.CFrame.LookVector)
		if facing.Magnitude < 0.01 then
			return false
		end
		local cos = facing.Unit:Dot(toTarget.Unit)
		if cos < math.cos(math.rad(Config.Watcher.SightHalfAngle)) then
			return false
		end
	end
	return lineOfSight(run, root.Position + Vector3.new(0, 1.5, 0), pos + Vector3.new(0, 3, 0))
end

-- Things a Listener under the Hungry Dark can be drawn toward.
function LightService.LureSources(run): { Source }
	local out = LightService.Flames(run)
	local ps = run.PS
	local character = run.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and ps.Fuel > 0 and not ps.Dim then
		table.insert(out, { Pos = root.Position, Radius = 0, Kind = "Lantern", Ref = run.Player })
	end
	return out
end

return LightService
