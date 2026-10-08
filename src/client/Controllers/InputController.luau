--!strict
-- Maps keyboard/mouse, gamepad and touch to semantic requests
-- (TECH_ARCHITECTURE §18). The client asks; the server decides.
--
--   Attack     LMB / R2 / touch           Use item   RMB / R1 / touch
--   Sneak      hold Shift / hold L2       Lantern    F / Y
--   Refill     R / DPad up                Slots      1-4 / DPad left-right
--   Dash       Space / A                  Spells     Z X C V / B (DPad down cycles)
--   Inventory  I, Tab / Select            Journal    J
--   Controls   H                          Pause      M / Start
--   Camera     Left/Right arrow / L3, R3  (E is reserved for interaction)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Abilities = require(Shared.Definitions.Abilities)
local ClientState = require(script.Parent.ClientState)

local InputController = {}

local deps: any
local selectedSpell = 2 -- index into Abilities.List for the gamepad cast button

local BEGIN = Enum.UserInputState.Begin
local END = Enum.UserInputState.End
local PASS = Enum.ContextActionResult.Pass
local SINK = Enum.ContextActionResult.Sink

local SPELL_KEYS: { [Enum.KeyCode]: string } = {}
for _, a in Abilities.List do
	local ok, key = pcall(function()
		return (Enum.KeyCode :: any)[a.Key]
	end)
	if ok and key then
		SPELL_KEYS[key] = a.Id
	end
end

local function blocked(): boolean
	return ClientState.UIBlocking or not ClientState.InRun
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

-- Asks for an ability; gives immediate feedback when it can't be used yet.
function InputController.Cast(id: string)
	local def = Abilities.ById[id]
	local snap = ClientState.Snapshot
	if not def or not snap then
		return
	end
	if snap.Level < def.Level then
		deps.Hud.Message(string.format("%s unlocks at experience level %d.", def.Name, def.Level))
		return
	end
	local left = ClientState.CooldownLeft(id)
	if left > 0.1 then
		deps.Hud.Message(string.format("%s is not ready (%.0fs).", def.Name, math.ceil(left)))
		return
	end
	-- Predict the cooldown locally so the bar reacts at once.
	ClientState.CooldownEnds[id] = os.clock() + def.Cooldown
	if id == "Dash" then
		deps.Character.Dash()
	end
	Remotes.RequestAbility:FireServer(id, ClientState.AimPoint)
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

	ContextActionService:BindAction("RA_Strike", function(_, state)
		if state == BEGIN and not blocked() then
			Remotes.RequestStrike:FireServer()
			deps.Effects.LocalSwing()
			return SINK
		end
		return PASS
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	styleTouch("RA_Strike", "Attack", UDim2.new(1, -170, 1, -170))

	ContextActionService:BindAction("RA_Use", function(_, state)
		if state == BEGIN and not blocked() then
			InputController.UseSelected()
			return SINK
		end
		return PASS
	end, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonR1)
	styleTouch("RA_Use", "Use", UDim2.new(1, -240, 1, -110))

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
		elseif k == Enum.KeyCode.DPadRight or k == Enum.KeyCode.ButtonL1 then
			InputController.SelectSlot(ClientState.SelectedSlot + 1)
		elseif k == Enum.KeyCode.DPadLeft then
			InputController.SelectSlot(ClientState.SelectedSlot - 1)
		end
		return SINK
	end, false, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
		Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonL1)

	ContextActionService:BindAction("RA_Dash", function(_, state)
		if state == BEGIN and not blocked() then
			InputController.Cast("Dash")
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
		local id = SPELL_KEYS[input.KeyCode]
		if not id then
			-- Gamepad B / touch: cast the selected spell.
			id = Abilities.List[selectedSpell].Id
		end
		InputController.Cast(id)
		return SINK
	end, true, Enum.KeyCode.ButtonB, table.unpack(spellKeys))
	styleTouch("RA_Spell", "Spell", UDim2.new(1, -320, 1, -130))

	ContextActionService:BindAction("RA_SpellCycle", function(_, state)
		if state ~= BEGIN or blocked() then
			return PASS
		end
		selectedSpell += 1
		if selectedSpell > #Abilities.List then
			selectedSpell = 2
		end
		local a = Abilities.List[selectedSpell]
		deps.Hud.Message("Selected spell: " .. a.Name)
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

	-- Releasing Shift while a panel was open must not leave us sneaking.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		ClientState.Creeping = false
	end)
end

return InputController
