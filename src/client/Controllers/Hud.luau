--!strict
-- In-game HUD (GAME_DESIGN §24), laid out like a classic roguelike:
--   top-left      dungeon level and its rule
--   top-centre    message log ("You hit the giant rat for 5.")
--   bottom-left   health, lantern oil, experience, Str / Armor / Damage / Gold
--   bottom-centre ability bar above the 4-slot hotbar
--   right         controls panel (toggle with H)
-- Full-screen panels (inventory, journal, menus) live in Panels.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local FloorRules = require(Shared.Definitions.FloorRules)
local Abilities = require(Shared.Definitions.Abilities)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClientState = require(script.Parent.ClientState)
local UiKit = require(script.Parent.UiKit)

local C = UiKit.Colors

local Hud = {}

local gui: ScreenGui
local deps: any

type Bar = { Fill: Frame, Label: TextLabel }

local hpBar: Bar
local oilBar: Bar
local expBar: Bar
local statsLine: TextLabel
local sneakLabel: TextLabel
local slots: { { Frame: TextButton, Label: TextLabel, Count: TextLabel, Swatch: Frame, Stroke: UIStroke } } = {}
local abilityBoxes: { [string]: { Frame: Frame, Shade: Frame, Label: TextLabel, Key: TextLabel, Stroke: UIStroke } } = {}
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
local vignette: Frame
local itemDetail: TextLabel
local controlsPanel: Frame
local controlsBody: TextLabel
local controlsTab: TextButton
local hudRoot: Frame
local controlsShown = true

local LOG_LINES = 4
local LOG_SECONDS = 9

local function tween(obj: Instance, t: number, props: { [string]: any })
	local tw = TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Sine), props)
	tw:Play()
	return tw
end

local function bar(parent: Instance, y: number, title: string, color: Color3): Bar
	UiKit.Text(parent, {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(62, 18),
		TextSize = 15,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	})
	local back = UiKit.Frame(parent, {
		Position = UDim2.fromOffset(64, y + 5),
		Size = UDim2.fromOffset(150, 9),
		BackgroundColor3 = C.Ink,
	})
	UiKit.Stroke(back, C.LineDim, 1)
	local fill = UiKit.Frame(back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color })
	local label = UiKit.Text(parent, {
		Position = UDim2.fromOffset(222, y),
		Size = UDim2.fromOffset(80, 18),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	return { Fill = fill, Label = label }
end

-- Bottom-left: health, oil, experience and the stat line.
local function buildStatus()
	local box = UiKit.Frame(hudRoot, {
		Name = "Status",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(310, 112),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.35,
	})
	UiKit.Pad(box, 8)
	hpBar = bar(box, 0, "Health", Color3.fromRGB(168, 64, 56))
	oilBar = bar(box, 20, "Lantern", C.Amber)
	expBar = bar(box, 40, "Exp", C.Parchment)
	statsLine = UiKit.Text(box, {
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 15,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	sneakLabel = UiKit.Text(box, {
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 15,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
end

-- Bottom-centre: hotbar (pack slots 1-4) with the ability bar above it.
local function buildSlots()
	local n = Config.Player.HotbarSlots
	local row = UiKit.Frame(hudRoot, {
		Name = "Hotbar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(n * 60 + (n - 1) * 8, 60),
	})
	UiKit.List(row, 8, true)
	for i = 1, n do
		local b = Instance.new("TextButton")
		b.Name = "Slot" .. i
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = C.Ink
		b.BackgroundTransparency = 0.15
		b.BorderSizePixel = 0
		b.Size = UDim2.fromOffset(60, 60)
		b.LayoutOrder = i
		b.Parent = row
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
			Size = UDim2.fromOffset(24, 14),
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

	local abilityRow = UiKit.Frame(hudRoot, {
		Name = "Abilities",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -84),
		Size = UDim2.fromOffset(#Abilities.List * 52 + (#Abilities.List - 1) * 6, 46),
	})
	UiKit.List(abilityRow, 6, true)
	for i, a in Abilities.List do
		local f = UiKit.Frame(abilityRow, {
			Size = UDim2.fromOffset(52, 46),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.2,
			LayoutOrder = i,
		})
		local stroke = UiKit.Stroke(f, C.LineDim, 1)
		local key = UiKit.Text(f, {
			Position = UDim2.fromOffset(3, 1),
			Size = UDim2.new(1, -6, 0, 14),
			TextSize = 12,
			TextColor3 = C.Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = a.Key,
		})
		local label = UiKit.Text(f, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.new(1, -4, 0, 16),
			TextSize = 13,
			Text = a.Short,
		})
		local shade = UiKit.Frame(f, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			ZIndex = 2,
		})
		abilityBoxes[a.Id] = { Frame = f, Shade = shade, Label = label, Key = key, Stroke = stroke }
	end

	itemDetail = UiKit.Text(hudRoot, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -136),
		Size = UDim2.fromOffset(560, 20),
		TextSize = 15,
		TextColor3 = C.Dim,
		Text = "",
	})
end

-- Top-left: dungeon level and its rule.
local function buildDepth()
	local box = UiKit.Frame(hudRoot, {
		Name = "Depth",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.fromOffset(340, 48),
	})
	glyphBox = UiKit.Frame(box, { BackgroundTransparency = 1, Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(0, 4) })
	depthLabel = UiKit.Text(box, {
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.fromOffset(280, 26),
		FontFace = UiKit.BodyBold,
		TextSize = 22,
		TextColor3 = C.Parchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	ruleLabel = UiKit.Text(box, {
		Position = UDim2.fromOffset(46, 24),
		Size = UDim2.fromOffset(300, 20),
		TextSize = 15,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
end

-- Top-centre: Rogue-style message log.
local function buildLog()
	logFrame = UiKit.Frame(hudRoot, {
		Name = "Messages",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(620, LOG_LINES * 22),
	})
	UiKit.List(logFrame, 2)
end

function Hud.Message(text: string)
	local label = UiKit.Text(logFrame, {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 17,
		TextColor3 = C.Text,
		TextStrokeTransparency = 0.6,
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
		Position = UDim2.new(0.5, 0, 0.2, 0),
		Size = UDim2.fromOffset(640, 30),
		FontFace = UiKit.Display,
		TextSize = 28,
		TextColor3 = C.Parchment,
		TextStrokeTransparency = 0.5,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		Text = "",
	})
	noticeText = UiKit.Text(hudRoot, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 32),
		Size = UDim2.fromOffset(600, 44),
		TextSize = 18,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})
end

local function buildReadPanel()
	readPanel = UiKit.Frame(hudRoot, {
		Name = "Read",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(460, 200),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	UiKit.Stroke(readPanel, C.Line, 1)
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
		TextSize = 24,
		TextColor3 = C.Parchment,
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

-- Right side: the always-available controls list.
local function controlsText(): string
	if ClientState.InputMode == "Gamepad" then
		return table.concat({
			"Move              Left stick",
			"Aim / face        Right stick",
			"Attack            R2",
			"Use item          R1",
			"Change item       D-pad left / right",
			"Interact          X",
			"Sneak             Hold L2",
			"Dim lantern       Y",
			"Refill lantern    D-pad up",
			"Dash (Lv 2)       A",
			"Cast spell        B (D-pad down to switch)",
			"Turn camera       L3 / R3",
			"Inventory         Select",
			"Pause menu        Start",
		}, "\n")
	elseif ClientState.InputMode == "Touch" then
		return table.concat({
			"Move              Thumbstick",
			"Attack / Use      Buttons on the right",
			"Use an item       Tap its slot",
			"Interact          Tap the tag",
			"Inventory         Bag button",
		}, "\n")
	end
	return table.concat({
		"Move              W A S D",
		"Aim / face        Mouse",
		"Attack            Left click",
		"Use item          Right click",
		"Pick hotbar slot  1 2 3 4",
		"Interact          E",
		"Sneak (silent)    Hold Shift",
		"Dim lantern       F",
		"Refill lantern    R",
		"Dash (Lv 2)       Space",
		"Spells (Lv 3+)    Z  X  C  V",
		"Inventory         I  or  Tab",
		"Journal           J",
		"Turn camera       Left / Right arrow",
		"Zoom              Mouse wheel",
		"Pause menu        M",
		"Hide this list    H",
	}, "\n")
end

local function buildControls()
	controlsPanel = UiKit.Frame(hudRoot, {
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(268, 330),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.3,
	})
	UiKit.Stroke(controlsPanel, C.LineDim, 1)
	UiKit.Pad(controlsPanel, 10)
	UiKit.Text(controlsPanel, {
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = UiKit.BodyBold,
		TextSize = 17,
		TextColor3 = C.Parchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Controls",
	})
	local hide = UiKit.Button(controlsPanel, "Hide [H]", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(70, 20),
		TextSize = 14,
		FontFace = UiKit.Body,
	})
	hide.Activated:Connect(function()
		Hud.ToggleControls()
	end)
	controlsBody = UiKit.Text(controlsPanel, {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		FontFace = Font.fromEnum(Enum.Font.RobotoMono),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = false,
		Text = controlsText(),
	})
	controlsTab = UiKit.Button(hudRoot, "Controls [H]", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(110, 26),
		TextSize = 15,
		FontFace = UiKit.Body,
		BackgroundTransparency = 0.3,
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
		controlsPanel.Size = UDim2.fromOffset(268, 52 + lines * 13)
	end
end

local function buildOverlays()
	-- Hurt shows as a brief darkening of the whole view, never red flashes.
	vignette = UiKit.Frame(gui, {
		Name = "Hurt",
		BackgroundColor3 = Color3.fromRGB(20, 4, 4),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	fade = UiKit.Frame(gui, {
		Name = "Fade",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	})
end

local function fillBar(b: Bar, frac: number, text: string)
	tween(b.Fill, 0.3, { Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1) })
	b.Label.Text = text
end

local function render()
	hudRoot.Visible = ClientState.InRun and ClientState.Panel ~= "Menu"
	local snap = ClientState.Snapshot
	if not snap then
		return
	end
	fillBar(hpBar, snap.HP / snap.MaxHP, string.format("%d / %d", snap.HP, snap.MaxHP))
	hpBar.Fill.BackgroundColor3 = if snap.HP <= snap.MaxHP * 0.3 then Color3.fromRGB(210, 70, 50) else Color3.fromRGB(168, 64, 56)
	fillBar(oilBar, snap.Fuel / snap.MaxFuel, if snap.Fuel <= 0 then "empty" elseif snap.Dim then "dimmed" else "lit")
	oilBar.Fill.BackgroundColor3 = if snap.Dim then Color3.fromRGB(150, 110, 70) else C.Amber
	if snap.NextExp then
		local span = snap.NextExp - snap.LevelExp
		fillBar(expBar, (snap.Exp - snap.LevelExp) / span, string.format("Lv %d  (%d/%d)", snap.Level, snap.Exp, snap.NextExp))
	else
		fillBar(expBar, 1, string.format("Lv %d  (max)", snap.Level))
	end
	statsLine.Text = string.format("Str %d    Armor %d    Damage %d    Gold %d", snap.Str, snap.Armor, snap.Damage, snap.Gold)
	sneakLabel.Text = if snap.Creep then "Sneaking - your footsteps are silent" else ""

	for i, s in slots do
		local e = snap.Pack[i]
		local def = if e then Items[e.Id] else nil
		s.Swatch.Visible = def ~= nil
		if e and def then
			s.Swatch.BackgroundColor3 = def.Color
			s.Label.Text = def.Short
			s.Count.Text = if e.Count > 1 then ("x" .. e.Count) elseif e.Bonus ~= 0 then ((if e.Bonus > 0 then "+" else "") .. e.Bonus) else ""
		else
			s.Label.Text = ""
			s.Count.Text = ""
		end
		local selected = i == ClientState.SelectedSlot
		s.Stroke.Color = if selected then C.Parchment else C.LineDim
		s.Stroke.Thickness = if selected then 2 else 1
	end
	local sel = snap.Pack[ClientState.SelectedSlot]
	local selDef = if sel then Items[sel.Id] else nil
	itemDetail.Text = if sel and selDef then (Items.EntryName(sel) .. " - " .. selDef.Description) else ""

	for _, a in Abilities.List do
		local box = abilityBoxes[a.Id]
		local unlocked = snap.Level >= a.Level
		box.Label.TextColor3 = if unlocked then C.Parchment else C.LineDim
		box.Key.Text = if unlocked then a.Key else ("Lv " .. a.Level)
		box.Stroke.Color = if unlocked then C.Line else C.LineDim
	end

	depthLabel.Text = "Dungeon level " .. snap.Depth
	ruleLabel.Text = if snap.RuleName then ("Rule: " .. snap.RuleName) else "Rule: unknown - read the plaque in the first room"
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
	tween(noticeTitle, 0.3, { TextTransparency = if title then 0 else 1, TextStrokeTransparency = if title then 0.5 else 1 })
	tween(noticeText, 0.3, { TextTransparency = 0 })
	task.delay(seconds or 4.5, function()
		if token == noticeToken then
			tween(noticeTitle, 1, { TextTransparency = 1, TextStrokeTransparency = 1 })
			tween(noticeText, 1, { TextTransparency = 1 })
		end
	end)
end

function Hud.Read(title: string?, text: string, glyph: { { number } }?)
	readGlyph:ClearAllChildren()
	if glyph then
		UiKit.Glyph(readGlyph, glyph, C.Parchment, 2)
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

function Hud.Hurt()
	vignette.BackgroundTransparency = 0.45
	tween(vignette, 0.9, { BackgroundTransparency = 1 })
end

-- Level title card: fades in over the dungeon, never blocks movement.
local function floorCard(info)
	local rule = FloorRules[info.RuleId]
	local card = UiKit.Frame(gui, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(640, 160),
		ZIndex = 8,
	})
	local g = UiKit.Frame(card, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(54, 54),
		ZIndex = 8,
	})
	local glyph = UiKit.Glyph(g, rule.Glyph, C.Parchment, 2)
	local title = UiKit.Text(card, {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 44),
		FontFace = UiKit.Display,
		TextSize = 40,
		TextColor3 = C.Parchment,
		Text = "Dungeon Level " .. info.Depth,
		TextTransparency = 1,
		ZIndex = 8,
	})
	local sub = UiKit.Text(card, {
		Position = UDim2.fromOffset(0, 108),
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

	Remotes.StateUpdate.OnClientEvent:Connect(function(snapshot)
		ClientState.Set(snapshot)
	end)

	Remotes.Notice.OnClientEvent:Connect(function(n)
		if n.Kind == "Discovery" then
			Hud.Notice("New journal entry: " .. n.Title, n.Text, 6)
			Hud.Message("Journal updated: " .. n.Title .. " (press J to read).")
		elseif n.Kind == "LevelUp" or n.Kind == "Unlock" then
			Hud.Notice(n.Title, n.Text, 6)
			Hud.Message(if n.Kind == "LevelUp" then n.Text else (n.Title .. "!"))
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
		-- Old messages fade out.
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
		-- Ability cooldown shading.
		local snap = ClientState.Snapshot
		if snap then
			for _, a in Abilities.List do
				local left = ClientState.CooldownLeft(a.Id)
				local box = abilityBoxes[a.Id]
				box.Shade.Size = UDim2.fromScale(1, if snap.Level < a.Level then 1 else math.clamp(left / a.Cooldown, 0, 1))
			end
		end
		if ClientState.InputMode ~= lastMode then
			lastMode = ClientState.InputMode
			Hud.RefreshControls()
		end
		-- Reading panels close when the explorer walks away.
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
