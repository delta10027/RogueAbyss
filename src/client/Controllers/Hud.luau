--!strict
-- Minimal HUD (GAME_DESIGN §24): vigor, lantern oil, a four-slot satchel,
-- depth and the floor glyph, one quiet notice line. Plus the panels that
-- appear only when asked for: reading, journal, run summary.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local FloorRules = require(Shared.Definitions.FloorRules)
local Discoveries = require(Shared.Definitions.Discoveries)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClientState = require(script.Parent.ClientState)
local UiKit = require(script.Parent.UiKit)

local C = UiKit.Colors

local Hud = {}

local gui: ScreenGui
local deps: any

local vigorPips: { Frame } = {}
local fuelFill: Frame
local fuelLabel: TextLabel
local creepLabel: TextLabel
local slots: { { Frame: TextButton, Label: TextLabel, Swatch: Frame, Stroke: UIStroke } } = {}
local depthLabel: TextLabel
local ruleLabel: TextLabel
local glyphBox: Frame
local noticeTitle: TextLabel
local noticeText: TextLabel
local noticeToken = 0
local readPanel: Frame
local readTitle: TextLabel
local readText: TextLabel
local readGlyph: Frame
local journal: Frame
local journalList: ScrollingFrame
local summary: Frame
local fade: Frame
local vignette: Frame
local controlsHint: TextLabel
local itemDetail: TextLabel

local function tween(obj: Instance, t: number, props: { [string]: any })
	local tw = TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Sine), props)
	tw:Play()
	return tw
end

-- Bottom-left: vigor pips and oil.
local function buildStatus()
	local box = UiKit.Frame(gui, {
		Name = "Status",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 22, 1, -22),
		Size = UDim2.fromOffset(220, 70),
	})
	local pipRow = UiKit.Frame(box, { BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 22) })
	UiKit.List(pipRow, 10, true)
	for i = 1, Config.Player.MaxVigor do
		local holder = UiKit.Frame(pipRow, { BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 22), LayoutOrder = i })
		local pip = UiKit.Frame(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			Rotation = 45,
			BackgroundColor3 = C.Parchment,
		})
		UiKit.Stroke(pip, C.Line, 1)
		vigorPips[i] = pip
	end
	local bar = UiKit.Frame(box, {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.fromOffset(150, 6),
		BackgroundColor3 = C.Ink,
	})
	UiKit.Stroke(bar, C.LineDim, 1)
	fuelFill = UiKit.Frame(bar, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Amber })
	fuelLabel = UiKit.Text(box, {
		Position = UDim2.fromOffset(158, 27),
		Size = UDim2.fromOffset(70, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 15,
		TextColor3 = C.Dim,
		Text = "oil",
	})
	creepLabel = UiKit.Text(box, {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.fromOffset(200, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 15,
		TextColor3 = C.Dim,
		Text = "",
	})
end

-- Bottom-centre: the satchel.
local function buildSlots()
	local row = UiKit.Frame(gui, {
		Name = "Satchel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(4 * 54 + 3 * 8, 54),
	})
	UiKit.List(row, 8, true)
	for i = 1, Config.Player.InventorySlots do
		local b = Instance.new("TextButton")
		b.Name = "Slot" .. i
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = C.Ink
		b.BackgroundTransparency = 0.15
		b.BorderSizePixel = 0
		b.Size = UDim2.fromOffset(54, 54)
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
		slots[i] = { Frame = b, Label = label, Swatch = swatch, Stroke = stroke }
	end
	itemDetail = UiKit.Text(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -80),
		Size = UDim2.fromOffset(460, 20),
		TextSize = 15,
		TextColor3 = C.Dim,
		Text = "",
	})
end

-- Top-left: depth and the floor's glyph.
local function buildDepth()
	local box = UiKit.Frame(gui, {
		Name = "Depth",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(22, 18),
		Size = UDim2.fromOffset(320, 48),
	})
	glyphBox = UiKit.Frame(box, { BackgroundTransparency = 1, Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(0, 4) })
	depthLabel = UiKit.Text(box, {
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.fromOffset(260, 26),
		FontFace = UiKit.Display,
		TextSize = 24,
		TextColor3 = C.Parchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	ruleLabel = UiKit.Text(box, {
		Position = UDim2.fromOffset(46, 24),
		Size = UDim2.fromOffset(260, 20),
		TextSize = 15,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
end

local function buildNotice()
	noticeTitle = UiKit.Text(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -128),
		Size = UDim2.fromOffset(560, 24),
		FontFace = UiKit.Display,
		TextSize = 22,
		TextColor3 = C.Parchment,
		TextTransparency = 1,
		Text = "",
	})
	noticeText = UiKit.Text(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.fromOffset(560, 22),
		TextSize = 17,
		TextTransparency = 1,
		Text = "",
	})
end

local function buildReadPanel()
	readPanel = UiKit.Frame(gui, {
		Name = "Read",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(440, 200),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	UiKit.Stroke(readPanel, C.Line, 1)
	local glyphHolder = UiKit.Frame(readPanel, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(48, 48),
	})
	readGlyph = glyphHolder
	readTitle = UiKit.Text(readPanel, {
		Position = UDim2.fromOffset(20, 70),
		Size = UDim2.new(1, -40, 0, 26),
		FontFace = UiKit.Display,
		TextSize = 24,
		TextColor3 = C.Parchment,
		Text = "",
	})
	readText = UiKit.Text(readPanel, {
		Position = UDim2.fromOffset(24, 100),
		Size = UDim2.new(1, -48, 1, -112),
		TextSize = 19,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})
end

local function buildOverlays()
	-- Hurt shows as a brief darkening of the whole view, never red flashes.
	vignette = UiKit.Frame(gui, {
		Name = "Hurt",
		BackgroundColor3 = Color3.fromRGB(12, 4, 4),
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

	controlsHint = UiKit.Text(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -22),
		Size = UDim2.fromOffset(300, 120),
		TextSize = 15,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextTransparency = 1,
		Text = "WASD move · mouse to face\nE interact · click strike\nright-click throw / use · 1-4 choose\nhold Shift creep · F dim lantern · R refill\nJ journal · Z/C turn view",
	})
end

local function buildJournal()
	journal = UiKit.Frame(gui, {
		Name = "Journal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 520, 0.72, 0),
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 10,
	})
	UiKit.Stroke(journal, C.Line, 1)
	UiKit.Text(journal, {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 34),
		FontFace = UiKit.Display,
		TextSize = 30,
		TextColor3 = C.Parchment,
		Text = "Journal",
		ZIndex = 10,
	})
	journalList = Instance.new("ScrollingFrame")
	journalList.BackgroundTransparency = 1
	journalList.BorderSizePixel = 0
	journalList.Position = UDim2.fromOffset(24, 58)
	journalList.Size = UDim2.new(1, -48, 1, -76)
	journalList.ScrollBarThickness = 3
	journalList.ScrollBarImageColor3 = C.LineDim
	journalList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	journalList.CanvasSize = UDim2.new()
	journalList.ZIndex = 10
	journalList.Parent = journal
	UiKit.List(journalList, 10)
end

local function refreshJournal()
	for _, c in journalList:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local known: { [string]: boolean } = {}
	local snap = ClientState.Snapshot
	if snap and snap.Known then
		for _, id in snap.Known do
			known[id] = true
		end
	end
	local count = 0
	for _, def in Discoveries.List do
		local entry = UiKit.Frame(journalList, {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = def.Order,
			ZIndex = 10,
		})
		UiKit.List(entry, 2)
		if known[def.Id] then
			count += 1
			UiKit.Text(entry, {
				Size = UDim2.new(1, 0, 0, 22),
				FontFace = UiKit.Display,
				TextSize = 21,
				TextColor3 = C.Parchment,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = def.Title .. "   ·   " .. string.lower(def.Category),
				LayoutOrder = 1,
				ZIndex = 10,
			})
			UiKit.Text(entry, {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = def.Text,
				LayoutOrder = 2,
				ZIndex = 10,
			})
		else
			UiKit.Text(entry, {
				Size = UDim2.new(1, 0, 0, 22),
				TextSize = 17,
				TextColor3 = C.LineDim,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "· · ·",
				LayoutOrder = 1,
				ZIndex = 10,
			})
		end
	end
	UiKit.Text(journalList, {
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 15,
		TextColor3 = C.Dim,
		Text = string.format("%d of %d things understood", count, #Discoveries.List),
		LayoutOrder = 999,
		ZIndex = 10,
	})
end

function Hud.ToggleJournal()
	if summary and summary.Visible then
		return
	end
	journal.Visible = not journal.Visible
	ClientState.UIBlocking = journal.Visible
	if journal.Visible then
		refreshJournal()
	end
end

local function render()
	local snap = ClientState.Snapshot
	if not snap then
		return
	end
	for i, pip in vigorPips do
		local full = i <= snap.Vigor
		pip.BackgroundTransparency = if full then 0 else 1
		pip.Visible = i <= snap.MaxVigor
	end
	tween(fuelFill, 0.4, { Size = UDim2.fromScale(math.clamp(snap.Fuel / snap.MaxFuel, 0, 1), 1) })
	fuelFill.BackgroundColor3 = if snap.Dim then Color3.fromRGB(150, 110, 70) else C.Amber
	fuelLabel.Text = if snap.Fuel <= 0 then "no oil" elseif snap.Dim then "dimmed" else "oil"
	creepLabel.Text = if snap.Creep then "creeping - silent" else ""
	for i, s in slots do
		local id = snap.Inventory[i]
		local def = id and Items[id]
		s.Swatch.Visible = def ~= nil
		if def then
			s.Swatch.BackgroundColor3 = def.Color
			s.Label.Text = def.Short
		else
			s.Label.Text = ""
		end
		local selected = i == ClientState.SelectedSlot
		s.Stroke.Color = if selected then C.Parchment else C.LineDim
		s.Stroke.Thickness = if selected then 1.5 else 1
	end
	local selId = snap.Inventory[ClientState.SelectedSlot]
	local selDef = selId and Items[selId]
	itemDetail.Text = if selDef then (selDef.Name .. " - " .. selDef.Description) else ""
	depthLabel.Text = "Depth " .. UiKit.Roman(snap.Depth)
	ruleLabel.Text = snap.RuleName or "an unread rule"
	if glyphBox:GetAttribute("Rule") ~= snap.RuleId then
		glyphBox:ClearAllChildren()
		local rule = FloorRules[snap.RuleId]
		if rule then
			UiKit.Glyph(glyphBox, rule.Glyph, C.Parchment, 2)
		end
		glyphBox:SetAttribute("Rule", snap.RuleId)
	end
	if journal.Visible then
		refreshJournal()
	end
end

function Hud.Notice(title: string?, text: string, seconds: number?)
	noticeToken += 1
	local token = noticeToken
	noticeTitle.Text = title or ""
	noticeText.Text = text
	tween(noticeTitle, 0.3, { TextTransparency = if title then 0 else 1 })
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
		UiKit.Glyph(readGlyph, glyph, C.Parchment, 2)
	end
	readTitle.Text = title or ""
	readText.Text = text
	readPanel.Visible = true
	readPanel.BackgroundTransparency = 0.08
	local opened = os.clock()
	readPanel:SetAttribute("Opened", opened)
	task.delay(8, function()
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

-- Floor title card: fades in over the dungeon, never blocks movement.
local function floorCard(info)
	local rule = FloorRules[info.RuleId]
	local card = UiKit.Frame(gui, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(600, 160),
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
		Text = "The " .. string.lower(UiKit.Ordinal(info.Depth)):gsub("^%l", string.upper) .. " Depth",
		TextTransparency = 1,
		ZIndex = 8,
	})
	local sub = UiKit.Text(card, {
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 18,
		TextColor3 = C.Dim,
		Text = info.RuleName or "Its rule is not yet known to you.",
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

local function titleCard()
	local t = UiKit.Text(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.16),
		Size = UDim2.fromOffset(700, 60),
		FontFace = UiKit.Display,
		TextSize = 54,
		TextColor3 = C.Parchment,
		Text = "R O G U E   A B Y S S",
		TextTransparency = 1,
		ZIndex = 8,
	})
	tween(t, 2, { TextTransparency = 0.05 })
	task.delay(5, function()
		tween(t, 2.5, { TextTransparency = 1 })
		task.delay(2.6, function()
			t:Destroy()
		end)
	end)
end

local function showSummary(s)
	if summary then
		summary:Destroy()
	end
	journal.Visible = false
	readPanel.Visible = false
	ClientState.UIBlocking = true
	summary = UiKit.Frame(gui, {
		Name = "Summary",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 560, 0.84, 0),
		BackgroundTransparency = 0.02,
		ZIndex = 30,
	})
	UiKit.Stroke(summary, C.Line, 1)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(28, 22)
	scroll.Size = UDim2.new(1, -56, 1, -100)
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = C.LineDim
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ZIndex = 30
	scroll.Parent = summary
	UiKit.List(scroll, 6)
	local order = 0
	local function line(text: string, size: number, color: Color3, display: boolean?)
		order += 1
		return UiKit.Text(scroll, {
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			FontFace = if display then UiKit.Display else UiKit.Body,
			TextSize = size,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = text,
			LayoutOrder = order,
			ZIndex = 30,
		})
	end
	line("The dark keeps you", 34, C.Parchment, true)
	line(s.CauseText, 19, C.Text)
	line(string.format("Depth %s reached  ·  %d:%02d underground  ·  deepest ever: %s",
		UiKit.Roman(s.Depth), s.Duration // 60, s.Duration % 60, UiKit.Roman(math.max(1, s.BestDepth))), 17, C.Dim)
	if s.Hint then
		line(" ", 6, C.Dim)
		line(s.Hint, 18, C.Amber)
	end
	if #s.Discoveries > 0 then
		line(" ", 6, C.Dim)
		line("Understood this descent", 22, C.Parchment, true)
		for _, d in s.Discoveries do
			line("·  " .. d, 17, C.Text)
		end
	end
	if #s.Events > 0 then
		line(" ", 6, C.Dim)
		line("What happened", 22, C.Parchment, true)
		for _, e in s.Events do
			line("·  " .. e, 17, C.Text)
		end
	end
	if #s.Curios > 0 then
		line(" ", 6, C.Dim)
		line("Carried out of the dark", 22, C.Parchment, true)
		for _, c in s.Curios do
			line("·  " .. c, 17, C.Text)
		end
	end
	line(" ", 6, C.Dim)
	line("seed " .. tostring(s.Seed), 14, C.LineDim)

	local again = UiKit.Button(summary, "Descend again", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(220, 44),
		ZIndex = 31,
	})
	local function restart()
		if not summary then
			return
		end
		Remotes.RequestRestart:FireServer()
		summary:Destroy()
		summary = nil :: any
		ClientState.UIBlocking = false
		Hud.FadeTo(1, 0.2)
	end
	again.Activated:Connect(restart)
	local conn
	conn = UserInputService.InputBegan:Connect(function(input, processed)
		if not summary then
			conn:Disconnect()
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Space then
			conn:Disconnect()
			restart()
		end
	end)
	Hud.FadeTo(0.55, 0.6)
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

	buildStatus()
	buildSlots()
	buildDepth()
	buildNotice()
	buildReadPanel()
	buildJournal()
	buildOverlays()

	ClientState.Changed.Event:Connect(render)

	Remotes.StateUpdate.OnClientEvent:Connect(function(snapshot)
		ClientState.Set(snapshot)
	end)

	Remotes.Notice.OnClientEvent:Connect(function(n)
		if n.Kind == "Discovery" then
			Hud.Notice("Journal · " .. n.Title, n.Text, 6)
		elseif n.Kind == "Stele" then
			local rule = FloorRules[n.RuleId]
			Hud.Read(n.Title, n.Text, rule and rule.Glyph)
		elseif n.Kind == "Note" then
			Hud.Read("A note, in a careful hand", n.Text, nil)
		elseif n.Kind == "Curio" then
			Hud.Notice(nil, n.Text, 4)
		else
			Hud.Notice(nil, n.Text, 3.5)
		end
	end)

	local firstFloor = true
	Remotes.FloorEntered.OnClientEvent:Connect(function(info)
		ClientState.UIBlocking = false
		if summary then
			summary:Destroy()
			summary = nil :: any
		end
		Hud.FadeTo(0, 1.2)
		floorCard(info)
		if firstFloor and info.Depth == 1 then
			firstFloor = false
			titleCard()
			if ClientState.InputMode ~= "Touch" then
				tween(controlsHint, 2, { TextTransparency = 0.1 })
				task.delay(30, function()
					tween(controlsHint, 3, { TextTransparency = 1 })
				end)
			end
		end
	end)

	Remotes.RunEnded.OnClientEvent:Connect(showSummary)

	-- Reading panels close when the explorer walks away.
	game:GetService("RunService").Heartbeat:Connect(function()
		if readPanel.Visible then
			local opened = readPanel:GetAttribute("Opened") :: number?
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if opened and os.clock() - opened > 1 and humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
				readPanel.Visible = false
			end
		end
	end)
end

return Hud
