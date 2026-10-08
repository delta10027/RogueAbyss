--!strict
-- Every meaningful interaction goes through here (TECH_ARCHITECTURE §15).
-- ProximityPrompts give us keyboard, gamepad and touch input for free; the
-- server still validates ownership, distance, state and rate before acting.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local FloorRules = require(Shared.Definitions.FloorRules)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local InteractionService = {}

local S: any

local KINDLE_COST = 12

local recent: { [Player]: { number } } = {}

local function rateOk(player: Player): boolean
	local now = os.clock()
	local list = recent[player] or {}
	local kept = {}
	for _, t in list do
		if now - t < 1 then
			table.insert(kept, t)
		end
	end
	if #kept >= Config.Interaction.RateLimitPerSecond then
		recent[player] = kept
		return false
	end
	table.insert(kept, now)
	recent[player] = kept
	return true
end

local function promptPosition(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent and parent:IsA("BasePart") then
		return parent.Position
	elseif parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	end
	return nil
end

local function info(run, text: string)
	Remotes.Notice:FireClient(run.Player, { Kind = "Info", Text = text })
end

local handlers: { [string]: (any, ProximityPrompt, string?) -> () } = {}

handlers.Take = function(run, prompt, ref)
	local idx = tonumber(ref)
	if idx and S.ItemService.Pickup(run, idx) then
		prompt.Enabled = false
	end
end

handlers.Open = function(run, prompt, ref)
	local door = ref and run.Built.WoodDoors[ref]
	if not door or door.Opened then
		return
	end
	door.Opened = true
	prompt.Enabled = false
	door.Open()
	S.NoiseService.Emit(run, door.Pos, Config.Noise.DoorRadius, "Door", true)
	Remotes.Effect:FireClient(run.Player, { Kind = "Door", Pos = door.Pos })
	if run.Floor.Rooms[run.Floor.StartId].DraftConn == ref then
		run.Stats.FollowedDraft = true
	end
	if not run.Stats.FirstDoor then
		run.Stats.FirstDoor = true
		S.RunDirector.RecordEvent(run, "FirstDoor", "Chose a door.")
	end
end

handlers.Unlock = function(run, prompt, ref)
	local vault = ref and run.Built.VaultDoors[ref]
	if not vault or vault.Opened then
		return
	end
	local slot = S.PlayerStateService.FindItem(run, "RustedKey")
	if not slot then
		info(run, "Locked. The keyhole is crusted with rust.")
		return
	end
	S.PlayerStateService.RemoveSlot(run, slot)
	vault.Opened = true
	prompt.Enabled = false
	vault.Open()
	S.NoiseService.Emit(run, vault.Pos, 20, "Door", true)
	Remotes.Effect:FireClient(run.Player, { Kind = "Vault", Pos = vault.Pos })
	S.DiscoveryService.Discover(run.Player, "PlaceVault")
	S.RunDirector.RecordEvent(run, "Vault", "Opened an iron vault.")
end

handlers.Descend = function(run, _prompt, _ref)
	S.RunDirector.Descend(run)
end

handlers.Read = function(run, prompt, ref)
	local camp = run.Built.Camp
	if camp and prompt == camp.Prompt then
		Remotes.Notice:FireClient(run.Player, { Kind = "Note", Text = camp.Text })
		S.DiscoveryService.Discover(run.Player, "PlaceCamp")
		if not run.Stats.ReadNote then
			run.Stats.ReadNote = true
			S.RunDirector.RecordEvent(run, "Camp", "Found another explorer's camp.")
		end
		return
	end
	local rule = ref and FloorRules[ref]
	if rule then
		local known = S.DiscoveryService.Knows(run.Player, "Rule" .. rule.Id)
		Remotes.Notice:FireClient(run.Player, {
			Kind = "Stele",
			RuleId = rule.Id,
			Title = if known then rule.Name else nil,
			Text = if known then rule.Known else rule.Plaque,
		})
	end
end

handlers.Drink = function(run, prompt, _ref)
	local shrine = run.Built.Shrine
	if not shrine or prompt ~= shrine.Prompt then
		return
	end
	if shrine.Used then
		info(run, "The basin is dry.")
		return
	end
	shrine.Used = true
	prompt.Enabled = false
	shrine.Water.Transparency = 1
	S.PlayerStateService.Heal(run, 1)
	S.PlayerStateService.AddFuel(run, 15)
	Remotes.Effect:FireClient(run.Player, { Kind = "Drink" })
	S.DiscoveryService.Discover(run.Player, "PlaceShrine")
end

handlers.Pull = function(run, _prompt, _ref)
	local machine = run.Built.Machine
	if not machine then
		return
	end
	machine.Running = not machine.Running
	machine.Gear:SetAttribute("Running", machine.Running)
	machine.Handle.CFrame = machine.Handle.CFrame * CFrame.Angles(math.rad(if machine.Running then -60 else 60), 0, 0)
	S.NoiseService.Emit(run, machine.Pos, 24, "Machine", true)
	Remotes.Effect:FireClient(run.Player, { Kind = "Lever", Pos = machine.Pos, Running = machine.Running })
	S.DiscoveryService.Discover(run.Player, "PlaceMachine")
	if not machine.Running then
		S.RunDirector.RecordEvent(run, "Machine", "Stilled the buried machine.")
	end
end

handlers.Kindle = function(run, prompt, ref)
	local b = ref and run.Built.Braziers[ref]
	if not b or b.IsLit() then
		return
	end
	if run.PS.Fuel < KINDLE_COST then
		info(run, "Not enough oil in the lantern to spare a flame.")
		return
	end
	run.PS.Fuel -= KINDLE_COST
	S.PlayerStateService.UpdateLantern(run)
	S.PlayerStateService.Push(run.Player)
	prompt.Enabled = false
	S.ItemService.Kindle(run, b, "Lantern")
end

function InteractionService.Init(registry)
	S = registry
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local run = S.RunDirector.GetRun(player)
		if not run or run.State ~= "Active" or not run.Built then
			return
		end
		if not prompt:IsDescendantOf(run.Built.Holder) then
			return -- not this player's dungeon
		end
		if not rateOk(player) then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local pos = promptPosition(prompt)
		if not root or not pos then
			return
		end
		if (root.Position - pos).Magnitude > prompt.MaxActivationDistance + Config.Interaction.MaxDistance * 0.4 then
			return
		end
		local action = prompt:GetAttribute("Action")
		local handler = type(action) == "string" and handlers[action]
		if not handler then
			return
		end
		local ref = prompt:GetAttribute("Ref")
		local ok, err = pcall(handler, run, prompt, if type(ref) == "string" then ref else nil)
		if not ok then
			warn("[Interaction] " .. tostring(action) .. " failed: " .. tostring(err))
		end
		if not run.Stats.FirstInteraction then
			run.Stats.FirstInteraction = os.clock()
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		recent[player] = nil
	end)
end

return InteractionService
