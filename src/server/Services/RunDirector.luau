--!strict
-- Owns the run lifecycle (TECH_ARCHITECTURE §3):
--   Idle -> Starting -> Active -> Transition -> Active -> Failed -> Summary -> Restart
-- One run per player; each run occupies its own world slot so several
-- solo players can share a server without seeing each other's dungeon.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local FloorRules = require(Shared.Definitions.FloorRules)
local Discoveries = require(Shared.Definitions.Discoveries)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RunDirector = {}

local S: any

local TICK = 1 / 15
local MACHINE_INTERVAL = 6
local MACHINE_NOISE = 42

local runs: { [Player]: any } = {}

local CAUSE_TEXT = {
	Listener = "A Listener heard you.",
	Watcher = "A Watcher reached you in the dark.",
	Fire = "You stood in your own fire.",
	Abyss = "You fell into the abyss.",
}

local CAUSE_HINT = {
	Listener = "Listeners are blind. Hold Shift to creep without a sound, or throw something noisy elsewhere.",
	Watcher = "A Watcher cannot move while your lantern is on it - keep it in front of you, or hold it in firelight.",
	Fire = "Burning oil hurts everything that stands in it, you included.",
	Abyss = "The dark beyond the walls has no floor.",
}

function RunDirector.GetRun(player: Player)
	return runs[player]
end

function RunDirector.RecordEvent(run, id: string, text: string)
	if id ~= "Curio" and run.Stats.EventSeen[id] then
		return
	end
	run.Stats.EventSeen[id] = true
	table.insert(run.Stats.Events, string.format("Depth %d - %s", run.Depth, text))
	if Config.Debug then
		print(string.format("[Run] %s: %s", run.Player.Name, text))
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function placeCharacter(run)
	local character = run.Player.Character
	local root = rootOf(run.Player)
	if not character or not root or not run.Built then
		return
	end
	character:PivotTo(run.Built.Spawn)
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = false
	S.PlayerStateService.AttachLantern(run)
	S.PlayerStateService.SetCreep(run, false)
end

-- Remembers what the player left behind, for the failure hints.
local function noteMissed(run)
	local floor, built = run.Floor, run.Built
	if not floor or not built then
		return
	end
	for _, k in built.Cracked do
		if not k.Broken then
			table.insert(run.Stats.Missed, string.format("On depth %d, dust drifted into a wall.", floor.Depth))
		end
	end
	for _, v in built.VaultDoors do
		if not v.Opened then
			table.insert(run.Stats.Missed, string.format("An iron door on depth %d stayed shut.", floor.Depth))
		end
	end
end

local function teardownFloor(run)
	if run.Built then
		S.RulesService.End(run)
		S.CreatureService.Cleanup(run)
		S.ItemService.ClearRun(run)
		S.DungeonService.Unload(run.Built)
		run.Built = nil
	end
end

function RunDirector.EnterFloor(run, depth: number)
	run.State = "Transition"
	noteMissed(run)
	teardownFloor(run)
	run.Depth = depth
	local ok, floorOrErr, built = pcall(S.DungeonService.CreateFloor, run.Seed, depth, run.Slot, run.Player)
	if not ok then
		-- A seed that cannot produce a floor is logged and replaced.
		warn(string.format("[RunDirector] seed %d depth %d failed: %s - reseeding", run.Seed, depth, tostring(floorOrErr)))
		run.Seed = Random.new():NextInteger(1, 2 ^ 30)
		ok, floorOrErr, built = pcall(S.DungeonService.CreateFloor, run.Seed, depth, run.Slot, run.Player)
		if not ok then
			error(floorOrErr)
		end
	end
	run.Floor = floorOrErr
	run.Built = built
	run.Fires = {}
	run.MachineTimer = MACHINE_INTERVAL
	run.LurchUntil = 0
	S.RulesService.Begin(run)
	S.CreatureService.Spawn(run)

	-- The key never survives the descent.
	if depth > 1 then
		for i, it in run.PS.Inventory do
			if it == "RustedKey" then
				run.PS.Inventory[i] = false
			end
		end
	end

	placeCharacter(run)
	run.State = "Active"
	run.FloorStart = os.clock()

	local data = S.PersistenceService.Get(run.Player)
	if depth > data.Stats.BestDepth then
		data.Stats.BestDepth = depth
		S.PersistenceService.MarkDirty(run.Player)
	end

	local rule = FloorRules[run.Floor.RuleId]
	local known = S.DiscoveryService.Knows(run.Player, "Rule" .. rule.Id)
	Remotes.FloorEntered:FireClient(run.Player, {
		Depth = depth,
		RuleId = rule.Id,
		RuleName = if known then rule.Name else nil,
		Seed = run.Seed,
		FirstRun = data.Stats.Runs <= 1 and depth == 1,
	})
	S.PlayerStateService.Push(run.Player)
end

function RunDirector.StartRun(player: Player, seed: number?)
	local old = runs[player]
	if old then
		teardownFloor(old)
		S.DungeonService.ReleaseSlot(old.Slot)
		runs[player] = nil
	end
	local run = {
		Player = player,
		Seed = seed or Random.new():NextInteger(1, 2 ^ 30),
		Slot = S.DungeonService.AcquireSlot(),
		Depth = 0,
		State = "Starting",
		PS = S.PlayerStateService.NewState(),
		Fires = {},
		Creatures = {},
		RuleFlags = {},
		Phase = 0,
		Stats = {
			StartTime = os.clock(),
			Discovered = {},
			DiscoveryOrder = {},
			Events = {},
			EventSeen = {},
			Curios = {},
			Missed = {},
			ItemsUsed = 0,
			SecretsFound = 0,
			FloorsCleared = 0,
			LastHitBy = nil,
		},
	}
	runs[player] = run
	local data = S.PersistenceService.Get(player)
	data.Stats.Runs += 1
	S.PersistenceService.MarkDirty(player)
	RunDirector.EnterFloor(run, 1)
	return run
end

function RunDirector.Descend(run)
	if run.State ~= "Active" then
		return
	end
	run.State = "Transition"
	run.Stats.FloorsCleared += 1
	S.DiscoveryService.Discover(run.Player, "Rule" .. run.Floor.RuleId)
	if run.Depth == 1 then
		-- Looking back, the dust always drifted this way.
		S.DiscoveryService.Discover(run.Player, "LawDraft")
	end
	local data = S.PersistenceService.Get(run.Player)
	data.Stats.FloorsCleared += 1
	S.PersistenceService.MarkDirty(run.Player)
	Remotes.Effect:FireClient(run.Player, { Kind = "Descend" })
	task.delay(0.9, function()
		if runs[run.Player] ~= run then
			return
		end
		local ok, err = pcall(RunDirector.EnterFloor, run, run.Depth + 1)
		if not ok then
			warn("[RunDirector] descent failed: " .. tostring(err))
			run.State = "Active"
		end
	end)
end

function RunDirector.Fail(run, cause: string)
	if run.State ~= "Active" then
		return
	end
	run.State = "Failed"
	local root = rootOf(run.Player)
	if root then
		root.Anchored = true
	end
	noteMissed(run)
	local data = S.PersistenceService.Get(run.Player)
	data.Stats.Deaths += 1
	data.Stats.Curios += #run.Stats.Curios
	S.PersistenceService.MarkDirty(run.Player)
	Remotes.Effect:FireClient(run.Player, { Kind = "Collapse" })

	local found = {}
	for _, id in run.Stats.DiscoveryOrder do
		local def = Discoveries.ById[id]
		if def then
			table.insert(found, def.Title)
		end
	end
	local hint = CAUSE_HINT[cause]
	if #run.Stats.Missed > 0 then
		hint = (hint and (hint .. "\n") or "") .. run.Stats.Missed[1]
	end
	local summary = {
		Depth = run.Depth,
		Duration = math.floor(os.clock() - run.Stats.StartTime),
		Cause = cause,
		CauseText = CAUSE_TEXT[cause] or "The dark took you.",
		Hint = hint,
		Discoveries = found,
		Events = run.Stats.Events,
		Curios = run.Stats.Curios,
		BestDepth = data.Stats.BestDepth,
		Seed = run.Seed,
	}
	print(string.format("[Run] %s failed at depth %d (%s) after %ds", run.Player.Name, run.Depth, cause, summary.Duration))
	task.delay(1.4, function()
		if runs[run.Player] == run and run.State == "Failed" then
			run.State = "Summary"
			Remotes.RunEnded:FireClient(run.Player, summary)
		end
	end)
end

local function tickRun(run, dt: number)
	S.PlayerStateService.Tick(run, dt)
	S.NoiseService.Tick(run, dt)
	S.RulesService.Tick(run, dt)
	S.CreatureService.Tick(run, dt)
	S.ItemService.Tick(run, dt)

	-- The buried machine clanks on a rhythm while it runs.
	local machine = run.Built and run.Built.Machine
	if machine and machine.Running then
		run.MachineTimer -= dt
		if run.MachineTimer <= 0 then
			run.MachineTimer = MACHINE_INTERVAL
			S.NoiseService.Emit(run, machine.Pos, MACHINE_NOISE, "Machine", false)
			Remotes.Effect:FireClient(run.Player, { Kind = "Clank", Pos = machine.Pos })
		end
	end

	-- Water slows; creeping slows more.
	local character = run.Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(run.Player)
	if humanoid and root then
		local base = if run.PS.Creep then Config.Player.CreepSpeed else Config.Player.WalkSpeed
		local wading = S.NoiseService.InWater(run, root.Position)
		humanoid.WalkSpeed = if wading then base * 0.7 else base
		if root.Position.Y < run.Built.Origin.Y - 30 then
			RunDirector.Fail(run, "Abyss")
		end
	end
end

local function onCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if root then
		root.Anchored = true -- hold still until the dungeon is ready
	end
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	S.PlayerStateService.DressCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			local run = runs[player]
			if run and run.State == "Active" then
				RunDirector.Fail(run, "Abyss")
			end
		end)
	end
	local run = runs[player]
	if not run or run.PendingRestart then
		local ok, err = pcall(RunDirector.StartRun, player)
		if not ok then
			warn("[RunDirector] could not start run: " .. tostring(err))
		end
	elseif run.State == "Active" then
		placeCharacter(run)
	elseif run.State == "Summary" or run.State == "Failed" then
		-- Respawned during a summary: keep them still behind the summary.
		if root then
			root.CFrame = run.Built and run.Built.Spawn or root.CFrame
		end
	end
end

function RunDirector.Init(registry)
	S = registry
	Players.RespawnTime = 2
	Players.PlayerAdded:Connect(function(player)
		task.spawn(S.PersistenceService.Load, player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(S.PersistenceService.Load, player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		if run then
			teardownFloor(run)
			S.DungeonService.ReleaseSlot(run.Slot)
			runs[player] = nil
		end
	end)
	Remotes.RequestRestart.OnServerEvent:Connect(function(player)
		local run = runs[player]
		if run and run.State == "Transition" then
			return
		end
		if run and run.RestartAt and os.clock() - run.RestartAt < 2 then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			-- Start once the respawn arrives (see onCharacter).
			if run then
				run.PendingRestart = true
			end
			return
		end
		local ok, err = pcall(function()
			local newRun = RunDirector.StartRun(player)
			newRun.RestartAt = os.clock()
		end)
		if not ok then
			warn("[RunDirector] restart failed: " .. tostring(err))
		end
	end)
end

function RunDirector.Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		local step = math.min(acc, 0.25)
		acc = 0
		for _, run in runs do
			if run.State == "Active" and run.Built then
				local ok, err = pcall(tickRun, run, step)
				if not ok then
					warn("[RunDirector] tick error: " .. tostring(err))
				end
			end
		end
	end)
end

return RunDirector
