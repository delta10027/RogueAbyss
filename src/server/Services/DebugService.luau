--!strict
-- Developer tools (TECH_ARCHITECTURE §22). Gated: only active in Studio or
-- for the experience creator. Chat: /ra <command> [args]
--   seed <n>      restart the run with a fixed seed
--   floor <n>     jump to depth n
--   give <item>   add an item (OilFlask, TinBell, Tincture, RustedKey)
--   heal          restore vigor and oil
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
		reply(player, if S.PlayerStateService.AddItem(run, args[2] or "") then "given" else "failed")
	elseif cmd == "heal" then
		run.PS.Vigor = Config.Player.MaxVigor
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

function DebugService.Init(registry)
	S = registry
	if RunService:IsStudio() then
		-- Lets automated tests and the command bar reach the services.
		(_G :: any).RogueAbyss = registry
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
