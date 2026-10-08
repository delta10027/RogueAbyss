--!strict
-- Sound as a gameplay system. Every meaningful noise is emitted here, scaled
-- by the floor rule, shown to the player as a faint ring (so the rule is
-- learnable), and delivered to creatures.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local NoiseService = {}

local S: any

export type Noise = {
	Pos: Vector3,
	Radius: number,
	BaseRadius: number,
	Kind: string, -- "Step" | "Strike" | "Bell" | "Shatter" | "Door" | "Machine" | "Wall" | "Splash"
	FromPlayer: boolean,
	Time: number,
}

function NoiseService.Init(registry)
	S = registry
end

function NoiseService.Emit(run, pos: Vector3, baseRadius: number, kind: string, fromPlayer: boolean?)
	if run.State ~= "Active" or baseRadius <= 0 then
		return
	end
	local mult = run.RuleFlags.NoiseMultiplier or 1
	local noise: Noise = {
		Pos = pos,
		Radius = baseRadius * mult,
		BaseRadius = baseRadius,
		Kind = kind,
		FromPlayer = fromPlayer == true,
		Time = os.clock(),
	}
	if noise.FromPlayer then
		run.PS.LastNoiseAt = noise.Time
	end
	Remotes.Effect:FireClient(run.Player, { Kind = "Noise", Pos = pos, Radius = noise.Radius, Source = kind })
	S.CreatureService.OnNoise(run, noise)
end

function NoiseService.InWater(run, pos: Vector3): boolean
	if not run.Built then
		return false
	end
	for _, w in run.Built.Water do
		local d = pos - w.Center
		if math.abs(d.X) <= w.Half.X and math.abs(d.Z) <= w.Half.Y and pos.Y < w.Center.Y + 4.2 then
			return true
		end
	end
	return false
end

-- Footsteps: the server decides from actual movement, never from the client.
function NoiseService.Tick(run, _dt: number)
	local character = run.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if speed < 1.5 then
		return
	end
	local now = os.clock()
	if now - run.PS.LastStepAt < Config.Noise.FootstepInterval then
		return
	end
	run.PS.LastStepAt = now
	local wading = NoiseService.InWater(run, root.Position)
	-- Creeping is silent unless the body moves faster than a creep allows.
	local creeping = run.PS.Creep and speed <= Config.Player.CreepSpeed + 2
	if creeping and not wading then
		return
	end
	local radius = Config.Noise.WalkRadius
	if wading then
		radius *= if creeping then 0.8 else 1.6
	end
	NoiseService.Emit(run, root.Position, radius, if wading then "Splash" else "Step", true)
end

return NoiseService
