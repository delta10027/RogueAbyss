--!strict
-- Maps keyboard/mouse, gamepad and touch to semantic requests
-- (TECH_ARCHITECTURE §18). The client asks; the server decides.
--
--   Strike    LMB / R2 / touch        Use item  RMB / R1 / touch
--   Creep     hold Shift / hold L2 / touch toggle
--   Lantern   F / Y / touch            Refill    R / DPad up
--   Slots     1-4 / DPad left-right    Journal   J / Tab / Select
--   Rotate    Z, C / L3, R3   (E is reserved for interaction)

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local ClientState = require(script.Parent.ClientState)

local InputController = {}

local deps: any

local BEGIN = Enum.UserInputState.Begin
local END = Enum.UserInputState.End
local PASS = Enum.ContextActionResult.Pass
local SINK = Enum.ContextActionResult.Sink

local function blocked(): boolean
	return ClientState.UIBlocking
end

function InputController.SelectSlot(i: number)
	local n = Config.Player.InventorySlots
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
	styleTouch("RA_Strike", "Strike", UDim2.new(1, -170, 1, -170))

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
	styleTouch("RA_Creep", "Creep", UDim2.new(1, -110, 1, -230))

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

	ContextActionService:BindAction("RA_Journal", function(_, state)
		if state == BEGIN then
			deps.Hud.ToggleJournal()
			return SINK
		end
		return PASS
	end, false, Enum.KeyCode.J, Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect)

	ContextActionService:BindAction("RA_Rotate", function(_, state, input)
		if state ~= BEGIN or blocked() then
			return PASS
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Z or k == Enum.KeyCode.ButtonL3 then
			deps.Camera.Rotate(-1)
		else
			deps.Camera.Rotate(1)
		end
		return SINK
	end, false, Enum.KeyCode.Z, Enum.KeyCode.C, Enum.KeyCode.ButtonL3, Enum.KeyCode.ButtonR3)
end

return InputController
