--!strict
-- Maps keyboard/mouse, gamepad and touch to semantic requests
-- (TECH_ARCHITECTURE §18). The client asks; the server decides. Swing and
-- cast animations play immediately for responsiveness.
--
--   Attack     tap LMB / R2 (hold to charge a heavy attack)
--   Special    Q / L1           Use item  RMB / R1
--   Dash       Space / A        Spells    Z X C V B / B (DPad down cycles)
--   Sneak      hold Shift / L2  Lantern   F / Y      Refill  R / DPad up
--   Slots      1-4 / DPad left-right
--   Inventory  I, Tab / Select  Journal   J          Perks   L
--   Controls   H                Pause     M / Start
--   Camera     Left/Right arrow / L3, R3  (E is reserved for interaction)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local Spells = require(Shared.Definitions.Spells)
local ClientState = require(script.Parent.ClientState)

local InputController = {}

local deps: any
local selectedSpell = 1

local BEGIN = Enum.UserInputState.Begin
local END = Enum.UserInputState.End
local PASS = Enum.ContextActionResult.Pass
local SINK = Enum.ContextActionResult.Sink

local SPELL_KEYS: { [Enum.KeyCode]: number } = {}
for i, k in Config.Spells.Keys do
	SPELL_KEYS[(Enum.KeyCode :: any)[k]] = i
end

local function blocked(): boolean
	return ClientState.UIBlocking or not ClientState.InRun
end

local function weapon()
	local snap = ClientState.Snapshot
	local def = snap and snap.Weapon and Items[snap.Weapon.Id]
	return def or Items.Quarterstaff
end

local function winded(): boolean
	local snap = ClientState.Snapshot
	return snap ~= nil and (snap.Winded == true or (snap.Stamina or 1) <= 0)
end

function InputController.SelectSlot(i: number)
	local n = Config.Player.HotbarSlots
	ClientState.SelectedSlot = ((i - 1) % n) + 1
	ClientState.Changed:Fire()
end

function InputController.UseSelected()
	Remotes.RequestUseItem:FireServer(ClientState.SelectedSlot, ClientState.AimPoint)
end

function InputController.SetCreep(on: boolean)
	if ClientState.Creeping == on then
		return
	end
	ClientState.Creeping = on
	Remotes.RequestCreep:FireServer(on)
end

---------------------------------------------------------------------------
-- Attacks
---------------------------------------------------------------------------

local combo = { Step = 0, Last = 0, ReadyAt = 0 }
local pressAt: number? = nil
local charging = false

local function outOfBreath()
	deps.Hud.Message("You're out of breath!")
	deps.Hud.FlashBar("Stamina")
end

function InputController.Attack(heavy: boolean)
	local def = weapon()
	local w = def.Weapon :: any
	local now = os.clock()
	if now < combo.ReadyAt - 0.08 then
		return
	end
	if winded() then
		outOfBreath()
		return
	end
	local step
	if heavy then
		step = 0
		combo.Step = 0
	elseif now - combo.Last <= w.Cooldown + Config.Combo.Window and combo.Step < 3 then
		combo.Step += 1
		step = combo.Step
	else
		combo.Step = 1
		step = 1
	end
	local duration = w.Cooldown * (if heavy then 1.35 elseif step == 3 then 1.25 else 1)
	combo.ReadyAt = now + duration
	combo.Last = now
	if step == 3 then
		combo.Step = 0
	end
	if heavy then
		deps.Animator.Play("Heavy", math.max(0.35, duration * 0.8))
		deps.Effects.LocalSwing(true)
	else
		deps.Animator.Swing(w.Style, step, math.max(0.22, duration * 0.85))
		deps.Effects.LocalSwing(false)
	end
	Remotes.RequestStrike:FireServer(if heavy then "Heavy" else "Light")
end

local SPECIAL_ANIM = {
	Sweep = "Spin", Whirlwind = "Spin", GroundSlam = "Smash3", Cleave = "Smash3", Rend = "Slash3",
	Lunge = "Thrust3", Shadowstep = "Thrust1", StaffFire = "CastBoth", StaffFrost = "Cast",
	StaffStorm = "CastBoth", StaffShadow = "CastBoth",
}

function InputController.Special()
	local def = weapon()
	local sp = def.Special
	if not sp then
		return
	end
	local left = ClientState.CooldownLeft("Special")
	if left > 0.1 then
		deps.Hud.Message(string.format("%s is not ready (%ds).", sp.Name, math.ceil(left)))
		return
	end
	if winded() then
		outOfBreath()
		return
	end
	ClientState.CooldownEnds.Special = os.clock() + sp.Cooldown
	deps.Animator.Play(SPECIAL_ANIM[sp.Id] or "Slash3", if sp.Id == "Whirlwind" then 0.85 else 0.5)
	Remotes.RequestAbility:FireServer("Special", nil, ClientState.AimPoint)
end

function InputController.Cast(slot: number)
	local snap = ClientState.Snapshot
	if not snap then
		return
	end
	local id = snap.Spells and snap.Spells[slot]
	local def = id and Spells.ById[id]
	if not def then
		if slot <= (snap.SpellSlots or 0) then
			deps.Hud.Message("No spell in that slot. Find spellbooks to learn more spells.")
		else
			deps.Hud.Message("You don't have that many spell slots yet.")
		end
		return
	end
	local left = ClientState.CooldownLeft(id)
	if left > 0.1 then
		deps.Hud.Message(string.format("%s is not ready (%ds).", def.Name, math.ceil(left)))
		return
	end
	if (snap.Mana or 0) < def.Mana then
		deps.Hud.Message(string.format("Not enough mana for %s.", def.Name))
		deps.Hud.FlashBar("Mana")
		return
	end
	ClientState.CooldownEnds[id] = os.clock() + def.Cooldown
	deps.Animator.Play(if def.Id == "FrostNova" or def.Id == "Meteor" or def.Id == "ScareMonster" then "CastBoth" else "Cast", 0.45)
	Remotes.RequestAbility:FireServer("Spell", slot, ClientState.AimPoint)
end

function InputController.Dash()
	if ClientState.CooldownLeft("Dash") > 0.05 then
		return
	end
	if winded() then
		outOfBreath()
		return
	end
	ClientState.CooldownEnds.Dash = os.clock() + 0.6
	deps.Character.Dash()
	deps.Effects.LocalDash()
	Remotes.RequestAbility:FireServer("Dash", nil, ClientState.AimPoint)
end

local function styleTouch(name: string, title: string, pos: UDim2)
	ContextActionService:SetTitle(name, title)
	ContextActionService:SetPosition(name, pos)
	local button = ContextActionService:GetButton(name)
	if button then
		button.ImageTransparency = 0.6
	end
end

function InputController.Start(dependencies)
	deps = dependencies

	ContextActionService:BindAction("RA_Strike", function(_, state, input)
		if blocked() then
			pressAt = nil
			if charging then
				charging = false
				deps.Animator.Stop()
			end
			return PASS
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			if state == BEGIN then
				InputController.Attack(false)
			end
			return SINK
		end
		if state == BEGIN then
			pressAt = os.clock()
		elseif state == END and pressAt then
			local held = os.clock() - pressAt
			pressAt = nil
			if charging then
				charging = false
				InputController.Attack(true)
			elseif held < Config.Combo.HeavyHold then
				InputController.Attack(false)
			else
				InputController.Attack(true)
			end
		end
		return SINK
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	styleTouch("RA_Strike", "Attack", UDim2.new(1, -170, 1, -170))

	-- Holding the attack button shows the weapon being drawn back.
	RunService.RenderStepped:Connect(function()
		if pressAt and not charging and os.clock() - pressAt >= Config.Combo.HeavyHold and os.clock() >= combo.ReadyAt - 0.1 then
			charging = true
			deps.Animator.Play("Charge", 0.3, true)
			deps.Effects.ChargeGlow()
		end
	end)

	ContextActionService:BindAction("RA_Use", function(_, state)
		if state == BEGIN and not blocked() then
			InputController.UseSelected()
			return SINK
		end
		return PASS
	end, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonR1)
	styleTouch("RA_Use", "Use", UDim2.new(1, -240, 1, -110))

	ContextActionService:BindAction("RA_Special", function(_, state)
		if state == BEGIN and not blocked() then
			InputController.Special()
			return SINK
		end
		return PASS
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
	styleTouch("RA_Special", "Skill", UDim2.new(1, -100, 1, -110))

	ContextActionService:BindAction("RA_Creep", function(_, state, input)
		if blocked() then
			if state == END then
				InputController.SetCreep(false)
			end
			return PASS
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			if state == BEGIN then
				InputController.SetCreep(not ClientState.Creeping)
			end
		elseif state == BEGIN then
			InputController.SetCreep(true)
		elseif state == END then
			InputController.SetCreep(false)
		end
		return SINK
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL2)
	styleTouch("RA_Creep", "Sneak", UDim2.new(1, -110, 1, -230))

	ContextActionService:BindAction("RA_Lantern", function(_, state)
		if state == BEGIN and not blocked() then
			Remotes.RequestLantern:FireServer()
			return SINK
		end
		return PASS
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	styleTouch("RA_Lantern", "Lamp", UDim2.new(1, -180, 1, -250))

	ContextActionService:BindAction("RA_Refill", function(_, state)
		if state == BEGIN and not blocked() then
			Remotes.RequestUseItem:FireServer(nil, nil, "Refill")
			return SINK
		end
		return PASS
	end, false, Enum.KeyCode.R, Enum.KeyCode.DPadUp)

	ContextActionService:BindAction("RA_Slot", function(_, state, input)
		if state ~= BEGIN or blocked() then
			return PASS
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.One then
			InputController.SelectSlot(1)
		elseif k == Enum.KeyCode.Two then
			InputController.SelectSlot(2)
		elseif k == Enum.KeyCode.Three then
			InputController.SelectSlot(3)
		elseif k == Enum.KeyCode.Four then
			InputController.SelectSlot(4)
		elseif k == Enum.KeyCode.DPadRight then
			InputController.SelectSlot(ClientState.SelectedSlot + 1)
		elseif k == Enum.KeyCode.DPadLeft then
			InputController.SelectSlot(ClientState.SelectedSlot - 1)
		end
		return SINK
	end, false, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
		Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight)

	ContextActionService:BindAction("RA_Dash", function(_, state)
		if state == BEGIN and not blocked() then
			InputController.Dash()
			return SINK
		end
		return PASS
	end, true, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	styleTouch("RA_Dash", "Dash", UDim2.new(1, -250, 1, -190))

	local spellKeys = {}
	for key in SPELL_KEYS do
		table.insert(spellKeys, key)
	end
	ContextActionService:BindAction("RA_Spell", function(_, state, input)
		if state ~= BEGIN or blocked() then
			return PASS
		end
		InputController.Cast(SPELL_KEYS[input.KeyCode] or selectedSpell)
		return SINK
	end, true, Enum.KeyCode.ButtonB, table.unpack(spellKeys))
	styleTouch("RA_Spell", "Spell", UDim2.new(1, -320, 1, -130))

	ContextActionService:BindAction("RA_SpellCycle", function(_, state)
		if state ~= BEGIN or blocked() then
			return PASS
		end
		local snap = ClientState.Snapshot
		local n = math.max(1, snap and snap.Spells and #snap.Spells or 1)
		selectedSpell = (selectedSpell % n) + 1
		local id = snap and snap.Spells and snap.Spells[selectedSpell]
		if id and Spells.ById[id] then
			deps.Hud.Message("Selected spell: " .. Spells.ById[id].Name)
		end
		return SINK
	end, false, Enum.KeyCode.DPadDown)

	ContextActionService:BindAction("RA_Inventory", function(_, state)
		if state == BEGIN and ClientState.InRun then
			deps.Panels.ToggleInventory()
			return SINK
		end
		return PASS
	end, true, Enum.KeyCode.I, Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect)
	styleTouch("RA_Inventory", "Bag", UDim2.new(1, -90, 0, 90))

	ContextActionService:BindAction("RA_Journal", function(_, state)
		if state == BEGIN and ClientState.InRun then
			deps.Panels.ToggleJournal()
			return SINK
		end
		return PASS
	end, false, Enum.KeyCode.J)

	ContextActionService:BindAction("RA_Perks", function(_, state)
		if state == BEGIN and ClientState.InRun then
			deps.Panels.TogglePerks()
			return SINK
		end
		return PASS
	end, false, Enum.KeyCode.L)

	ContextActionService:BindAction("RA_Controls", function(_, state)
		if state == BEGIN then
			deps.Hud.ToggleControls()
			return SINK
		end
		return PASS
	end, false, Enum.KeyCode.H)

	ContextActionService:BindAction("RA_Pause", function(_, state)
		if state == BEGIN and ClientState.InRun then
			deps.Panels.TogglePause()
			return SINK
		end
		return PASS
	end, true, Enum.KeyCode.M, Enum.KeyCode.ButtonStart)
	styleTouch("RA_Pause", "Menu", UDim2.new(1, -90, 0, 30))

	ContextActionService:BindAction("RA_Rotate", function(_, state, input)
		if state ~= BEGIN or blocked() then
			return PASS
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Left or k == Enum.KeyCode.ButtonL3 then
			deps.Camera.Rotate(-1)
		else
			deps.Camera.Rotate(1)
		end
		return SINK
	end, false, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.ButtonL3, Enum.KeyCode.ButtonR3)

	Players.LocalPlayer.CharacterAdded:Connect(function()
		ClientState.Creeping = false
	end)
end

return InputController
