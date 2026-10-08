--!strict
-- The player's staff strike: short windup, narrow arc, loud. Hits creatures
-- and cracked walls. The server decides every outcome (TECH_ARCHITECTURE §17).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CombatService = {}

local S: any
local C = Config.Combat

local lastStrike: { [Player]: number } = {}

local WALL_HITS = 3

local function strikeWalls(run, origin: Vector3, look: Vector3): boolean
	local hitAny = false
	for _, k in run.Built.Cracked do
		if not k.Broken then
			local to = k.Pos - origin
			local flatTo = Vector3.new(to.X, 0, to.Z)
			if flatTo.Magnitude <= C.StrikeRange + 2 and (flatTo.Magnitude < 2 or look:Dot(flatTo.Unit) > 0.35) then
				hitAny = true
				k.Hits += 1
				Remotes.Effect:FireClient(run.Player, { Kind = "WallHit", Pos = k.Pos, Hits = k.Hits })
				if k.Hits >= WALL_HITS then
					k.Broken = true
					k.Shatter()
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

function CombatService.Strike(run)
	local character = run.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local now = os.clock()
	if now - (lastStrike[run.Player] or 0) < C.StrikeCooldown then
		return
	end
	lastStrike[run.Player] = now
	Remotes.Effect:FireClient(run.Player, { Kind = "Swing" })
	task.delay(C.StrikeWindup, function()
		if run.State ~= "Active" or not root.Parent then
			return
		end
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if look.Magnitude < 0.01 then
			return
		end
		look = look.Unit
		local hits = S.CreatureService.Strike(run, root.Position, look, C.StrikeRange, C.StrikeArcDegrees, 1)
		local wall = strikeWalls(run, root.Position, look)
		S.NoiseService.Emit(run, root.Position, C.StrikeNoise, "Strike", true)
		if hits > 0 then
			Remotes.Effect:FireClient(run.Player, { Kind = "StrikeHit" })
		elseif not wall then
			Remotes.Effect:FireClient(run.Player, { Kind = "StrikeMiss" })
		end
	end)
end

function CombatService.Init(registry)
	S = registry
	Remotes.RequestStrike.OnServerEvent:Connect(function(player)
		local run = S.RunDirector.GetRun(player)
		if run and run.State == "Active" then
			CombatService.Strike(run)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastStrike[player] = nil
	end)
end

return CombatService
