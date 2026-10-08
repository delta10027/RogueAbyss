--!strict
-- THE TOLLING FLOOR: a great bell tolls on a fixed rhythm. On each toll the
-- marked gates swap state and every Watcher lurches. A thrown bell that
-- rings near a marked gate makes that gate answer early.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Tolling = { Id = "Tolling" }

local S: any

function Tolling.Bind(registry)
	S = registry
end

local function applyPhase(run)
	for _, g in run.Built.Gates do
		g.SetOpen(g.OpenInPhase == run.Phase)
	end
end

function Tolling.Toll(run)
	run.Phase = 1 - (run.Phase or 0)
	applyPhase(run)
	S.CreatureService.Lurch(run, 0.7)
	Remotes.Effect:FireClient(run.Player, { Kind = "Toll" })
	if run.TollsHeard == nil then
		run.TollsHeard = 0
	end
	run.TollsHeard += 1
	-- After two tolls the rhythm (and the gates) are hard to miss.
	if run.TollsHeard >= 2 then
		S.DiscoveryService.Discover(run.Player, "RuleTolling")
	end
end

function Tolling.Configure(run)
	run.RuleFlags.Tolling = true
	run.Phase = 0
	run.TollTimer = Config.Tolling.Interval
	run.TollsHeard = 0
end

function Tolling.OnTick(run, dt: number)
	run.TollTimer -= dt
	if run.TollTimer <= 3 and not run.TollWarned then
		-- A faint mechanical wind-up before each toll: the rhythm is learnable.
		run.TollWarned = true
		Remotes.Effect:FireClient(run.Player, { Kind = "TollWarn" })
	end
	if run.TollTimer <= 0 then
		run.TollTimer = Config.Tolling.Interval
		run.TollWarned = false
		Tolling.Toll(run)
	end
end

-- A ringing bell near a marked gate flips that gate alone.
function Tolling.OnBell(run, pos: Vector3)
	for _, g in run.Built.Gates do
		if (g.Pos - pos).Magnitude <= Config.Tolling.BellGateRadius then
			g.SetOpen(not g.IsOpen())
			S.DiscoveryService.Discover(run.Player, "BellGate")
			S.RunDirector.RecordEvent(run, "BellGate", "Answered a gate with a bell.")
		end
	end
end

function Tolling.Cleanup(run)
	run.RuleFlags.Tolling = nil
	run.TollTimer = nil
end

return Tolling
