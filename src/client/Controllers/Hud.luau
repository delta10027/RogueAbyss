--!strict
-- In-game HUD (GAME_DESIGN §24):
--   top-left      dungeon level and its rule
--   top-centre    message log ("You defeated the kobold.")
--   bottom-left   character panel: health, mana, stamina, experience, stats
--   bottom-centre ability bar (dash, weapon special, spells) over the hotbar
--   right         controls panel (toggle with H)
-- Full-screen panels (inventory, journal, menus, perks) live in Panels.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local Spells = require(Shared.Definitions.Spells)
local FloorRules = require(Shared.Definitions.FloorRules)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClientState = require(script.Parent.ClientState)
local UiKit = require(script.Parent.UiKit)

local C = UiKit.Colors

local Hud = {}

local gui: ScreenGui
local deps: any
local hudRoot: Frame

local hpBar: UiKit.Bar
local manaBar: UiKit.Bar
local staminaBar: UiKit.Bar
local expBar: UiKit.Bar
local oilBar: UiKit.Bar
local nameLabel: TextLabel
local statsLine: TextLabel
local sneakLabel: TextLabel
local perkButton: TextButton
local slots: { { Frame: TextButton, Label: TextLabel, Count: TextLabel, Swatch: Frame, Stroke: UIStroke } } = {}
type Ability = { Frame: Frame, Shade: Frame, Icon: Frame, Key: TextLabel, Cost: TextLabel, Stroke: UIStroke, Id: string? }
local abilities: { Ability } = {} -- [1] dash, [2] special, [3..] spells
local depthLabel: TextLabel
local ruleLabel: TextLabel
local glyphBox: Frame
local logFrame: Frame
local logLines: { { Label: TextLabel, Time: number } } = {}
local noticeTitle: TextLabel
local noticeText: TextLabel
local noticeToken = 0
local readPanel: Frame
local readTitle: TextLabel
local readText: TextLabel
local readGlyph: Frame
local fade: Frame
local hurtEdge: Frame
local itemDetail: TextLabel
local controlsPanel: Frame
local controlsBody: TextLabel
local controlsTab: TextButton
local controlsShown = true

local LOG_LINES = 5
local LOG_SECONDS = 9

local function tween(obj: Instance, t: number, props: { [string]: any })
	local tw = TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Sine), props)
	tw:Play()
	return tw
end

---------------------------------------------------------------------------
-- Character panel
---------------------------------------------------------------------------

local function buildStatus()
	local box = UiKit.Ornate(hudRoot, {
		Name = "Status",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(300, 152),
	})
	nameLabel = UiKit.Text(box, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 22),
		FontFace = UiKit.Display,
		TextSize = 21,
		TextColor3 = C.Parchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	hpBar = UiKit.Bar(box, { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 18) }, C.Health)
	manaBar = UiKit.Bar(box, { Position = UDim2.fromOffset(12, 54), Size = UDim2.new(0.5, -15, 0, 13) }, C.Mana)
	staminaBar = UiKit.Bar(box, { Position = UDim2.new(0.5, 3, 0, 54), Size = UDim2.new(0.5, -15, 0, 13) }, C.Stamina)
	expBar = UiKit.Bar(box, { Position = UDim2.fromOffset(12, 71), Size = UDim2.new(1, -24, 0, 9) }, C.Exp)
	expBar.Label.TextSize = 10
	oilBar = UiKit.Bar(box, { Position = UDim2.fromOffset(12, 84), Size = UDim2.new(1, -24, 0, 9) }, C.Amber)
	oilBar.Label.TextSize = 10
	statsLine = UiKit.Text(box, {
		Position = UDim2.fromOffset(12, 99),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 15,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	sneakLabel = UiKit.Text(box, {
		Position = UDim2.fromOffset(12, 120),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 14,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	perkButton = UiKit.Button(hudRoot, "Level up! Choose a perk  [L]", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -176),
		Size = UDim2.fromOffset(300, 34),
		TextSize = 19,
		Visible = false,
	})
	perkButton.Activated:Connect(function()
		deps.Panels.TogglePerks()
	end)
end

function Hud.FlashBar(which: string)
	local bar = if which == "Mana" then manaBar elseif which == "Stamina" then staminaBar else hpBar
	local s = bar.Root:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = Color3.fromRGB(255, 90, 70)
		s.Thickness = 2
		tween(s, 0.6, { Color = C.LineDim, Thickness = 1 })
	end
end

---------------------------------------------------------------------------
-- Ability bar and hotbar
---------------------------------------------------------------------------

local function abilityBox(parent: Instance, order: number): Ability
	local f = UiKit.Frame(parent, {
		Size = UDim2.fromOffset(54, 54),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
	})
	UiKit.Gradient(f, Color3.fromRGB(40, 32, 28), Color3.fromRGB(12, 10, 10), 90)
	local stroke = UiKit.Stroke(f, C.LineDim, 1.2)
	local icon = UiKit.Frame(f, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30) })
	local key = UiKit.Text(f, {
		Position = UDim2.fromOffset(3, 1),
		Size = UDim2.new(1, -6, 0, 13),
		TextSize = 12,
		FontFace = UiKit.BodyBold,
		TextColor3 = C.Parchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.5,
		Text = "",
		ZIndex = 3,
	})
	local cost = UiKit.Text(f, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -3, 1, -1),
		Size = UDim2.fromOffset(30, 12),
		TextSize = 11,
		FontFace = UiKit.BodyBold,
		TextColor3 = Color3.fromRGB(140, 170, 255),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.5,
		Text = "",
		ZIndex = 3,
	})
	local shade = UiKit.Frame(f, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 2,
	})
	return { Frame = f, Shade = shade, Icon = icon, Key = key, Cost = cost, Stroke = stroke }
end

local DASH_GLYPH = { { 0.15, 0.5, 0.55, 0.5 }, { 0.45, 0.25, 0.75, 0.5 }, { 0.45, 0.75, 0.75, 0.5 }, { 0.65, 0.25, 0.9, 0.5 }, { 0.65, 0.75, 0.9, 0.5 } }
local SPECIAL_GLYPH = { { 0.2, 0.8, 0.8, 0.2 }, { 0.6, 0.2, 0.8, 0.2 }, { 0.8, 0.2, 0.8, 0.4 }, { 0.15, 0.6, 0.4, 0.85 } }

local function setIcon(a: Ability, glyph: { { number } }?, color: Color3)
	a.Icon:ClearAllChildren()
	if glyph then
		UiKit.Glyph(a.Icon, glyph, color, 2)
	end
end

local function buildSlots()
	local n = Config.Player.HotbarSlots
	local row = UiKit.Frame(hudRoot, {
		Name = "Hotbar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(n * 58 + (n - 1) * 6, 58),
	})
	UiKit.List(row, 6, true)
	for i = 1, n do
		local b = Instance.new("TextButton")
		b.Name = "Slot" .. i
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BorderSizePixel = 0
		b.Size = UDim2.fromOffset(58, 58)
		b.LayoutOrder = i
		b.Parent = row
		UiKit.Gradient(b, Color3.fromRGB(36, 29, 25), Color3.fromRGB(10, 8, 8), 90)
		local stroke = UiKit.Stroke(b, C.LineDim, 1)
		UiKit.Text(b, {
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.fromOffset(12, 14),
			TextSize = 13,
			TextColor3 = C.Dim,
			Text = tostring(i),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local count = UiKit.Text(b, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 2),
			Size = UDim2.fromOffset(26, 14),
			TextSize = 13,
			TextColor3 = C.Parchment,
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local swatch = UiKit.Frame(b, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(14, 14),
			Rotation = 45,
			Visible = false,
		})
		local label = UiKit.Text(b, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.new(1, -4, 0, 16),
			TextSize = 14,
			Text = "",
		})
		b.Activated:Connect(function()
			deps.Input.SelectSlot(i)
			if ClientState.InputMode == "Touch" then
				deps.Input.UseSelected()
			end
		end)
		slots[i] = { Frame = b, Label = label, Count = count, Swatch = swatch, Stroke = stroke }
	end

	local total = 2 + Config.Spells.MaxSlots
	local abilityRow = UiKit.Frame(hudRoot, {
		Name = "Abilities",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -82),
		Size = UDim2.fromOffset(total * 54 + (total - 1) * 6 + 10, 54),
	})
	UiKit.List(abilityRow, 6, true)
	for i = 1, total do
		local a = abilityBox(abilityRow, i)
		abilities[i] = a
		if i == 2 then
			-- A small gap after the weapon special separates it from spells.
			local pad = Instance.new("Frame")
			pad.BackgroundTransparency = 1
			pad.Size = UDim2.fromOffset(4, 54)
			pad.LayoutOrder = 2
			pad.Parent = abilityRow
			a.Frame.LayoutOrder = 2
		elseif i > 2 then
			a.Frame.LayoutOrder = i + 1
		end
	end
	abilities[1].Key.Text = "Space"
	setIcon(abilities[1], DASH_GLYPH, C.Parchment)
	abilities[2].Key.Text = "Q"
	setIcon(abilities[2], SPECIAL_GLYPH, C.Gold)

	itemDetail = UiKit.Text(hudRoot, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -142),
		Size = UDim2.fromOffset(620, 20),
		TextSize = 15,
		TextColor3 = C.Dim,
		TextStrokeTransparency = 0.6,
		Text = "",
	})
end

---------------------------------------------------------------------------
-- Top of the screen
---------------------------------------------------------------------------

local function buildDepth()
	local box = UiKit.Frame(hudRoot, {
		Name = "Depth",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.fromOffset(360, 48),
	})
	glyphBox = UiKit.Frame(box, { BackgroundTransparency = 1, Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(0, 4) })
	depthLabel = UiKit.Text(box, {
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.fromOffset(300, 26),
		FontFace = UiKit.Display,
		TextSize = 24,
		TextColor3 = C.Parchment,
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	ruleLabel = UiKit.Text(box, {
		Position = UDim2.fromOffset(46, 25),
		Size = UDim2.fromOffset(320, 20),
		TextSize = 15,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
end

local function buildLog()
	logFrame = UiKit.Frame(hudRoot, {
		Name = "Messages",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(660, LOG_LINES * 22),
	})
	UiKit.List(logFrame, 2)
end

function Hud.Message(text: string)
	local label = UiKit.Text(logFrame, {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 17,
		TextColor3 = C.Text,
		TextStrokeTransparency = 0.5,
		Text = text,
		LayoutOrder = math.floor(os.clock() * 100),
	})
	table.insert(logLines, { Label = label, Time = os.clock() })
	while #logLines > LOG_LINES do
		logLines[1].Label:Destroy()
		table.remove(logLines, 1)
	end
end

local function buildNotice()
	noticeTitle = UiKit.Text(hudRoot, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.17, 0),
		Size = UDim2.fromOffset(700, 34),
		FontFace = UiKit.Display,
		TextSize = 32,
		TextColor3 = C.Gold,
		TextStrokeTransparency = 1,
		TextTransparency = 1,
		Text = "",
	})
	noticeText = UiKit.Text(hudRoot, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.17, 38),
		Size = UDim2.fromOffset(620, 44),
		TextSize = 18,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})
end

local function buildReadPanel()
	readPanel = UiKit.Ornate(hudRoot, {
		Name = "Read",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(480, 210),
		Visible = false,
	})
	readGlyph = UiKit.Frame(readPanel, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(44, 44),
	})
	readTitle = UiKit.Text(readPanel, {
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.new(1, -40, 0, 26),
		FontFace = UiKit.Display,
		TextSize = 25,
		TextColor3 = C.Gold,
		Text = "",
	})
	readText = UiKit.Text(readPanel, {
		Position = UDim2.fromOffset(24, 94),
		Size = UDim2.new(1, -48, 1, -104),
		TextSize = 18,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})
end

---------------------------------------------------------------------------
-- Controls panel (H)
---------------------------------------------------------------------------

local function controlsText(): string
	if ClientState.InputMode == "Gamepad" then
		return table.concat({
			"Move              Left stick",
			"Aim / face        Right stick",
			"Attack            R2 (hold: heavy)",
			"Weapon skill      L1",
			"Use item          R1",
			"Change item       D-pad left/right",
			"Interact          X",
			"Dash              A",
			"Cast spell        B (D-pad down: next)",
			"Sneak             Hold L2",
			"Dim lantern       Y",
			"Refill lantern    D-pad up",
			"Turn camera       L3 / R3",
			"Inventory         Select",
			"Pause menu        Start",
		}, "\n")
	elseif ClientState.InputMode == "Touch" then
		return table.concat({
			"Move              Thumbstick",
			"Attack / Skill    Buttons on the right",
			"Use an item       Tap its slot",
			"Interact          Tap the tag",
			"Inventory         Bag button",
		}, "\n")
	end
	return table.concat({
		"Move              W A S D",
		"Aim / face        Mouse",
		"Attack            Left click",
		"Heavy attack      Hold left click",
		"Weapon skill      Q",
		"Dash (dodge)      Space",
		"Spells            Z X C V B",
		"Use item          Right click",
		"Pick hotbar slot  1 2 3 4",
		"Interact          E",
		"Sneak (silent)    Hold Shift",
		"Dim lantern       F",
		"Refill lantern    R",
		"Inventory         I  or  Tab",
		"Perks             L",
		"Journal           J",
		"Turn camera       Left / Right",
		"Zoom              Mouse wheel",
		"Pause menu        M",
		"Hide this list    H",
	}, "\n")
end

local function buildControls()
	controlsPanel = UiKit.Ornate(hudRoot, {
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(272, 330),
		BackgroundTransparency = 0.15,
	})
	UiKit.Text(controlsPanel, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 22),
		FontFace = UiKit.Display,
		TextSize = 20,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Controls",
	})
	local hide = UiKit.Button(controlsPanel, "Hide [H]", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 9),
		Size = UDim2.fromOffset(70, 20),
		TextSize = 14,
		FontFace = UiKit.Body,
	})
	hide.Activated:Connect(function()
		Hud.ToggleControls()
	end)
	controlsBody = UiKit.Text(controlsPanel, {
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 1, -44),
		FontFace = UiKit.Mono,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = false,
		Text = controlsText(),
	})
	controlsTab = UiKit.Button(hudRoot, "Controls [H]", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(112, 28),
		TextSize = 15,
		FontFace = UiKit.Body,
		Visible = false,
	})
	controlsTab.Activated:Connect(function()
		Hud.ToggleControls()
	end)
end

function Hud.ToggleControls()
	controlsShown = not controlsShown
	controlsPanel.Visible = controlsShown
	controlsTab.Visible = not controlsShown
end

function Hud.RefreshControls()
	if controlsBody then
		controlsBody.Text = controlsText()
		local lines = #string.split(controlsBody.Text, "\n")
		controlsPanel.Size = UDim2.fromOffset(272, 50 + lines * 13)
	end
end

local function buildOverlays()
	-- Taking a hit darkens the edges of the screen with a deep red.
	hurtEdge = UiKit.Frame(gui, {
		Name = "Hurt",
		BackgroundColor3 = Color3.fromRGB(90, 8, 8),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.22, 0.85),
		NumberSequenceKeypoint.new(0.78, 0.85),
		NumberSequenceKeypoint.new(1, 0),
	})
	g.Parent = hurtEdge
	fade = UiKit.Frame(gui, {
		Name = "Fade",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	})
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

local function renderVitals()
	local snap = ClientState.Snapshot
	if not snap or not snap.MaxHP then
		return
	end
	local shield = snap.Shield or 0
	hpBar.Set(snap.HP, snap.MaxHP, string.format("%d / %d%s", snap.HP, snap.MaxHP, if shield > 0 then ("  +" .. shield .. " shield") else ""))
	manaBar.Set(snap.Mana or 0, snap.MaxMana or 1, string.format("%d mana", math.floor(snap.Mana or 0)))
	local winded = snap.Winded == true
	staminaBar.Set(snap.Stamina or 0, snap.MaxStamina or 1, if winded then "winded!" else string.format("%d stamina", math.floor(snap.Stamina or 0)))
	staminaBar.Fill.BackgroundTransparency = if winded then 0.5 else 0
end

local function render()
	hudRoot.Visible = ClientState.InRun and ClientState.Panel ~= "Menu" and ClientState.Panel ~= "Create"
	local snap = ClientState.Snapshot
	if not snap or not snap.MaxHP then
		return
	end
	renderVitals()
	nameLabel.Text = string.format("%s  ·  level %d", snap.Name or "", snap.Level)
	if snap.NextExp then
		expBar.Set(snap.Exp - snap.LevelExp, snap.NextExp - snap.LevelExp, string.format("exp %d / %d", snap.Exp, snap.NextExp))
	else
		expBar.Set(1, 1, "max level")
	end
	oilBar.Set(snap.Fuel, snap.MaxFuel, if snap.Fuel <= 0 then "lantern empty" elseif snap.Dim then "lantern dimmed" else "lantern oil")
	statsLine.Text = string.format("Str %d   Armor %d   Dmg %d   Crit %d%%   Gold %d", snap.Str, snap.Armor, snap.Damage, snap.Crit or 0, snap.Gold)
	sneakLabel.Text = if snap.Creep then "Sneaking - your footsteps are silent" else ""
	perkButton.Visible = (snap.PendingPerks or 0) > 0

	for i, s in slots do
		local e = snap.Pack[i]
		local def = if e then Items[e.Id] else nil
		s.Swatch.Visible = def ~= nil
		if e and def then
			s.Swatch.BackgroundColor3 = def.Color
			s.Label.Text = def.Short
			s.Count.Text = if e.Count > 1 then ("x" .. e.Count) elseif (e.Bonus or 0) ~= 0 then ((if e.Bonus > 0 then "+" else "") .. e.Bonus) else ""
		else
			s.Label.Text = ""
			s.Count.Text = ""
		end
		local selected = i == ClientState.SelectedSlot
		s.Stroke.Color = if selected then C.Gold else C.LineDim
		s.Stroke.Thickness = if selected then 2 else 1
	end
	local sel = snap.Pack[ClientState.SelectedSlot]
	local selDef = if sel then Items[sel.Id] else nil
	itemDetail.Text = if sel and selDef then (Items.EntryName(sel) .. " - " .. selDef.Description) else ""

	-- Weapon special.
	local wdef = snap.Weapon and Items[snap.Weapon.Id]
	local sp = wdef and wdef.Special
	abilities[2].Cost.Text = ""
	abilities[2].Id = "Special"
	abilities[2].Stroke.Color = if sp then C.Line else C.LineDim
	-- Spells.
	for i = 1, Config.Spells.MaxSlots do
		local a = abilities[i + 2]
		local id = snap.Spells and snap.Spells[i]
		local def = id and Spells.ById[id]
		local open = i <= (snap.SpellSlots or 0)
		a.Frame.Visible = open
		a.Key.Text = Config.Spells.Keys[i]
		a.Id = id
		if def then
			if a.Icon:GetAttribute("Spell") ~= id then
				setIcon(a, def.Glyph, def.Color)
				a.Icon:SetAttribute("Spell", id)
			end
			a.Cost.Text = tostring(def.Mana)
			a.Stroke.Color = def.Color:Lerp(C.LineDim, 0.4)
		else
			if a.Icon:GetAttribute("Spell") ~= "" then
				setIcon(a, nil, C.Dim)
				a.Icon:SetAttribute("Spell", "")
			end
			a.Cost.Text = ""
			a.Stroke.Color = C.LineDim
		end
	end

	depthLabel.Text = "Dungeon Level " .. snap.Depth
	ruleLabel.Text = if snap.RuleName then ("Rule: " .. snap.RuleName) else "Rule unknown - read the plaque in the first room"
	if glyphBox:GetAttribute("Rule") ~= snap.RuleId then
		glyphBox:ClearAllChildren()
		local rule = FloorRules[snap.RuleId]
		if rule then
			UiKit.Glyph(glyphBox, rule.Glyph, C.Parchment, 2)
		end
		glyphBox:SetAttribute("Rule", snap.RuleId)
	end
end

function Hud.Notice(title: string?, text: string, seconds: number?)
	noticeToken += 1
	local token = noticeToken
	noticeTitle.Text = title or ""
	noticeText.Text = text
	noticeTitle.TextSize = 40
	tween(noticeTitle, 0.3, { TextTransparency = if title then 0 else 1, TextSize = 32 })
	tween(noticeText, 0.3, { TextTransparency = 0 })
	task.delay(seconds or 4.5, function()
		if token == noticeToken then
			tween(noticeTitle, 1, { TextTransparency = 1 })
			tween(noticeText, 1, { TextTransparency = 1 })
		end
	end)
end

function Hud.Read(title: string?, text: string, glyph: { { number } }?)
	readGlyph:ClearAllChildren()
	if glyph then
		UiKit.Glyph(readGlyph, glyph, C.Gold, 2)
	end
	readTitle.Text = title or ""
	readText.Text = text
	readPanel.Visible = true
	local opened = os.clock()
	readPanel:SetAttribute("Opened", opened)
	task.delay(12, function()
		if readPanel:GetAttribute("Opened") == opened then
			readPanel.Visible = false
		end
	end)
end

function Hud.FadeTo(alpha: number, seconds: number)
	return tween(fade, seconds, { BackgroundTransparency = 1 - alpha })
end

function Hud.Hurt(heavy: boolean?)
	hurtEdge.BackgroundTransparency = if heavy then 0.05 else 0.35
	tween(hurtEdge, 0.8, { BackgroundTransparency = 1 })
	Hud.FlashBar("Health")
end

local function floorCard(info)
	local rule = FloorRules[info.RuleId]
	local card = UiKit.Frame(gui, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(640, 170),
		ZIndex = 8,
	})
	local g = UiKit.Frame(card, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(54, 54),
		ZIndex = 8,
	})
	local glyph = UiKit.Glyph(g, rule.Glyph, C.Gold, 2)
	local title = UiKit.Text(card, {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 50),
		FontFace = UiKit.Display,
		TextSize = 46,
		TextColor3 = C.Parchment,
		Text = "Dungeon Level " .. info.Depth,
		TextTransparency = 1,
		ZIndex = 8,
	})
	local sub = UiKit.Text(card, {
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 18,
		TextColor3 = C.Dim,
		Text = if info.RuleName then ("Rule: " .. info.RuleName) else "This level has a special rule. Read the plaque to learn it.",
		TextTransparency = 1,
		ZIndex = 8,
	})
	for _, line in glyph:GetChildren() do
		if line:IsA("Frame") then
			line.BackgroundTransparency = 1
			tween(line, 1.2, { BackgroundTransparency = 0 })
		end
	end
	tween(title, 1.2, { TextTransparency = 0 })
	tween(sub, 1.6, { TextTransparency = 0 })
	task.delay(4, function()
		for _, line in glyph:GetChildren() do
			if line:IsA("Frame") then
				tween(line, 1.5, { BackgroundTransparency = 1 })
			end
		end
		tween(title, 1.5, { TextTransparency = 1 })
		tween(sub, 1.5, { TextTransparency = 1 })
		task.delay(1.6, function()
			card:Destroy()
		end)
	end)
end

function Hud.Gui(): ScreenGui
	return gui
end

function Hud.Start(dependencies)
	deps = dependencies
	local player = Players.LocalPlayer
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	task.spawn(function()
		for _ = 1, 10 do
			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)
			if ok then
				break
			end
			task.wait(1)
		end
	end)

	gui = Instance.new("ScreenGui")
	gui.Name = "RogueAbyssHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	hudRoot = UiKit.Frame(gui, {
		Name = "HudRoot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})

	buildStatus()
	buildSlots()
	buildDepth()
	buildLog()
	buildNotice()
	buildReadPanel()
	buildControls()
	buildOverlays()
	Hud.RefreshControls()
	if ClientState.InputMode == "Touch" then
		Hud.ToggleControls()
	end

	ClientState.Changed.Event:Connect(render)
	ClientState.VitalsChanged.Event:Connect(renderVitals)

	Remotes.StateUpdate.OnClientEvent:Connect(function(snapshot)
		ClientState.Set(snapshot)
	end)
	Remotes.Vitals.OnClientEvent:Connect(function(v)
		ClientState.SetVitals(v)
	end)

	Remotes.Notice.OnClientEvent:Connect(function(n)
		if n.Kind == "Discovery" then
			Hud.Notice("New journal entry: " .. n.Title, n.Text, 6)
			Hud.Message("Journal updated: " .. n.Title .. " (press J to read).")
		elseif n.Kind == "LevelUp" or n.Kind == "Unlock" then
			Hud.Notice(n.Title, n.Text, 6)
			Hud.Message(n.Title .. " " .. n.Text)
		elseif n.Kind == "Stele" then
			local rule = FloorRules[n.RuleId]
			Hud.Read(n.Title, n.Text, rule and rule.Glyph)
		elseif n.Kind == "Note" then
			Hud.Read("A note left by another explorer", n.Text, nil)
		else
			Hud.Message(n.Text)
		end
	end)

	Remotes.FloorEntered.OnClientEvent:Connect(function(info)
		ClientState.InRun = true
		Hud.FadeTo(0, 1.2)
		floorCard(info)
		Hud.Message(string.format("You enter dungeon level %d.", info.Depth))
		render()
	end)

	local lastMode = ClientState.InputMode
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for i = #logLines, 1, -1 do
			local l = logLines[i]
			local age = now - l.Time
			if age > LOG_SECONDS then
				l.Label:Destroy()
				table.remove(logLines, i)
			else
				l.Label.TextTransparency = math.clamp((age - (LOG_SECONDS - 2)) / 2, 0, 1)
			end
		end
		-- Cooldown shading on the ability bar.
		local snap = ClientState.Snapshot
		if snap and hudRoot.Visible then
			local wdef = snap.Weapon and Items[snap.Weapon.Id]
			local spCd = (wdef and wdef.Special and wdef.Special.Cooldown) or 1
			abilities[1].Shade.Size = UDim2.fromScale(1, math.clamp(ClientState.CooldownLeft("Dash") / 0.6, 0, 1))
			abilities[2].Shade.Size = UDim2.fromScale(1, math.clamp(ClientState.CooldownLeft("Special") / spCd, 0, 1))
			for i = 1, Config.Spells.MaxSlots do
				local a = abilities[i + 2]
				local def = a.Id and Spells.ById[a.Id]
				if def then
					local frac = math.clamp(ClientState.CooldownLeft(def.Id) / def.Cooldown, 0, 1)
					if (snap.Mana or 0) < def.Mana then
						frac = 1
					end
					a.Shade.Size = UDim2.fromScale(1, frac)
				else
					a.Shade.Size = UDim2.fromScale(1, 0)
				end
			end
			if perkButton.Visible then
				perkButton.TextColor3 = C.Parchment:Lerp(C.Gold, (math.sin(now * 5) + 1) / 2)
			end
		end
		if ClientState.InputMode ~= lastMode then
			lastMode = ClientState.InputMode
			Hud.RefreshControls()
		end
		if readPanel.Visible then
			local opened = readPanel:GetAttribute("Opened") :: number?
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if opened and os.clock() - opened > 1.5 and humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
				readPanel.Visible = false
			end
		end
	end)
end

return Hud
