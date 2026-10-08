--!strict
-- Developer tools (TECH_ARCHITECTURE §22). Gated: only active in Studio or
-- for the experience creator. Chat: /ra <command> [args]
--   seed <n>      restart the run with a fixed seed
--   floor <n>     jump to depth n
--   give <item> [n] add an item (any id in Definitions/Items)
--   exp <n>       gain experience
--   heal          restore health and oil
--   reveal        a huge lantern for inspecting a floor
--   info          print seed, depth, rule and layout
--   validate      re-run validation on the current floor

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)
local Validator = require(script.Parent.Parent.Generation.Validator)

local DebugService = {}

local S: any

local function allowed(player: Player): boolean
	return RunService:IsStudio() or player.UserId == game.CreatorId
end

local function reply(player: Player, text: string)
	game:GetService("ReplicatedStorage").Remotes.Notice:FireClient(player, { Kind = "Info", Text = "[debug] " .. text })
	print("[debug] " .. player.Name .. ": " .. text)
end

function DebugService.Run(player: Player, args: { string })
	if not allowed(player) then
		return
	end
	local cmd = string.lower(args[1] or "")
	local run = S.RunDirector.GetRun(player)
	if cmd == "seed" then
		local seed = tonumber(args[2])
		if seed then
			S.RunDirector.StartRun(player, math.floor(seed))
			reply(player, "seed " .. seed)
		end
	elseif not run then
		reply(player, "no run")
	elseif cmd == "floor" then
		local depth = tonumber(args[2])
		if depth and depth >= 1 then
			S.RunDirector.EnterFloor(run, math.floor(depth))
			reply(player, "depth " .. depth)
		end
	elseif cmd == "give" then
		reply(player, if S.PlayerStateService.AddItem(run, args[2] or "", tonumber(args[3]) or 1) then "given" else "failed")
	elseif cmd == "exp" then
		S.PlayerStateService.AddExp(run, tonumber(args[2]) or 10)
	elseif cmd == "heal" then
		run.PS.HP = run.PS.MaxHP
		run.PS.Fuel = Config.Lantern.MaxFuel
		S.PlayerStateService.UpdateLantern(run)
		S.PlayerStateService.Push(player)
	elseif cmd == "reveal" then
		if run.PS.Light then
			run.PS.Light.Range = 60
			run.PS.Light.Brightness = 3
		end
	elseif cmd == "info" then
		local f = run.Floor
		reply(player, string.format("seed=%d depth=%d rule=%s start=%s descent=%s secret=%s vault=%s key=%s",
			run.Seed, run.Depth, f.RuleId, f.StartId, f.DescentId, tostring(f.SecretId), tostring(f.VaultId), tostring(f.KeyRoomId)))
	elseif cmd == "validate" then
		local ok, reason = Validator.Validate(run.Floor)
		reply(player, if ok then "valid" else ("INVALID: " .. tostring(reason)))
	end
end

-- Tooling commands; results are plain strings so they cross any boundary.
function DebugService.Hook(cmd: string, ...): string
	local args = { ... }
	local player = Players:GetPlayers()[1]
	if not player then
		return "no player"
	end
	local run = S.RunDirector.GetRun(player)
	if cmd == "run" then
		DebugService.Run(player, args :: { string })
		return "ok"
	elseif cmd == "start" then
		S.RunDirector.StartRun(player, tonumber(args[1]))
		return "started"
	elseif not run then
		return "no run"
	elseif cmd == "creatures" then
		local out = {}
		for _, cr in run.Creatures do
			local meshes = 0
			for _, d in cr.Model:GetChildren() do
				if d:IsA("MeshPart") then
					meshes += 1
				end
			end
			table.insert(out, string.format("%s state=%s meshes=%d pos=%s", cr.Kind, tostring(cr.State), meshes, tostring(cr.Root.Position)))
		end
		return string.format("depth=%d rule=%s state=%s hp=%d/%d lvl=%d exp=%d gold=%d\n", run.Depth, run.Floor.RuleId, run.State, run.PS.HP, run.PS.MaxHP, run.PS.Level, run.PS.Exp, run.PS.Gold) .. table.concat(out, "\n")
	elseif cmd == "use" then
		-- Use the first pack item with this id: hook:Invoke("use", "Teleportation")
		local slot = S.PlayerStateService.FindItem(run, args[1])
		if not slot then
			return "not carried"
		end
		S.ItemService.Use(run, slot, nil)
		return "used"
	elseif cmd == "cast" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		S.AbilityService.Use(run, args[1], root and (root.Position + root.CFrame.LookVector * 15))
		return "cast"
	elseif cmd == "goto" then
		-- Stand the player a few studs in front of the first creature of a kind.
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for _, cr in run.Creatures do
			if cr.Kind == args[1] and root then
				local look = cr.Root.CFrame.LookVector
				local at = cr.Root.Position + Vector3.new(look.X, 0, look.Z) * (tonumber(args[2]) or 10)
				root.CFrame = CFrame.lookAt(at, Vector3.new(cr.Root.Position.X, at.Y, cr.Root.Position.Z))
				return "moved to " .. cr.Kind
			end
		end
		return "none"
	end
	return "unknown command"
end

function DebugService.Init(registry)
	S = registry
	if RunService:IsStudio() then
		-- Studio-only hook so tooling can drive and inspect a run:
		--   ServerScriptService.DebugHook:Invoke("creatures")
		local hook = Instance.new("BindableFunction")
		hook.Name = "DebugHook"
		hook.OnInvoke = function(cmd: string, ...)
			return DebugService.Hook(cmd, ...)
		end
		hook.Parent = game:GetService("ServerScriptService")
	end
	local ok = pcall(function()
		local command = Instance.new("TextChatCommand")
		command.Name = "RogueAbyssDebug"
		command.PrimaryAlias = "/ra"
		command.Parent = TextChatService
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if not player then
				return
			end
			local args = string.split(text, " ")
			table.remove(args, 1)
			DebugService.Run(player, args)
		end)
	end)
	if not ok then
		warn("[Debug] chat command unavailable")
	end
end

return DebugService
