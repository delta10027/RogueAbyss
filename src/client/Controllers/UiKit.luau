--!strict
-- UI building blocks in the Rogue Abyss visual language (ART_BIBLE §19-20):
-- dark surfaces, aged-gold borders with corner studs, parchment text,
-- restrained motion. Everything on screen is built from these.

local TweenService = game:GetService("TweenService")

local UiKit = {}

UiKit.Colors = {
	Ink = Color3.fromRGB(12, 10, 10),
	Panel = Color3.fromRGB(22, 18, 17),
	PanelLight = Color3.fromRGB(36, 29, 25),
	Line = Color3.fromRGB(150, 120, 74),
	LineDim = Color3.fromRGB(76, 64, 50),
	Gold = Color3.fromRGB(214, 170, 90),
	Parchment = Color3.fromRGB(226, 208, 168),
	Text = Color3.fromRGB(206, 194, 172),
	Dim = Color3.fromRGB(134, 124, 108),
	Amber = Color3.fromRGB(236, 164, 86),
	Blood = Color3.fromRGB(150, 44, 40),
	Health = Color3.fromRGB(176, 50, 44),
	Mana = Color3.fromRGB(70, 110, 210),
	Stamina = Color3.fromRGB(196, 170, 70),
	Exp = Color3.fromRGB(150, 120, 200),
}

-- Display face for titles; body face for anything read quickly.
UiKit.Display = Font.fromEnum(Enum.Font.Garamond)
UiKit.DisplayBold = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
UiKit.Body = Font.fromEnum(Enum.Font.SourceSans)
UiKit.BodyBold = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold)
UiKit.Mono = Font.fromEnum(Enum.Font.RobotoMono)

function UiKit.Frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UiKit.Colors.Panel
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

function UiKit.Stroke(parent: GuiObject, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or UiKit.Colors.Line
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UiKit.Corner(parent: GuiObject, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
	return c
end

function UiKit.Gradient(parent: GuiObject, top: Color3, bottom: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function UiKit.Text(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextColor3 = UiKit.Colors.Text
	t.FontFace = UiKit.Body
	t.TextSize = 18
	t.TextWrapped = true
	t.RichText = false
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

-- Small gold diamonds at the four corners of a frame: the "ornate" border.
function UiKit.Studs(frame: GuiObject, size: number?, color: Color3?)
	local s = size or 7
	for _, a in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local d = Instance.new("Frame")
		d.Name = "Stud"
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Position = UDim2.fromScale(a.X, a.Y)
		d.Size = UDim2.fromOffset(s, s)
		d.Rotation = 45
		d.BackgroundColor3 = color or UiKit.Colors.Gold
		d.BorderSizePixel = 0
		d.ZIndex = frame.ZIndex + 1
		d.Parent = frame
	end
end

-- A panel with a dark gradient, gold border and corner studs.
function UiKit.Ornate(parent: Instance, props: { [string]: any }): Frame
	local f = UiKit.Frame(parent, props)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	UiKit.Gradient(f, UiKit.Colors.PanelLight, UiKit.Colors.Ink, 90)
	UiKit.Stroke(f, UiKit.Colors.Line, 1.5)
	-- Inner hairline for a double border.
	local inner = Instance.new("Frame")
	inner.Name = "InnerLine"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(4, 4)
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.ZIndex = f.ZIndex
	inner.Parent = f
	UiKit.Stroke(inner, UiKit.Colors.LineDim, 1, 0.3)
	UiKit.Studs(f)
	return f
end

-- A button with a gentle hover lift and a press flash.
function UiKit.Button(parent: Instance, text: string, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Text = text
	b.TextColor3 = UiKit.Colors.Parchment
	b.FontFace = UiKit.Display
	b.TextSize = 22
	for k, v in props do
		(b :: any)[k] = v
	end
	local grad = UiKit.Gradient(b, Color3.fromRGB(44, 34, 28), Color3.fromRGB(16, 13, 12), 90)
	local stroke = UiKit.Stroke(b, UiKit.Colors.LineDim, 1.2)
	-- A gradient also tints an object's own text, so the text lives in a
	-- child label that mirrors the button's text properties.
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = b.ZIndex
	label.TextWrapped = true
	local function sync()
		label.Text = b.Text
		label.TextColor3 = b.TextColor3
		label.TextSize = b.TextSize
		label.FontFace = b.FontFace
		label.TextXAlignment = b.TextXAlignment
		label.ZIndex = b.ZIndex
	end
	sync()
	b.TextTransparency = 1
	for _, prop in { "Text", "TextColor3", "TextSize", "FontFace", "TextXAlignment", "ZIndex" } do
		b:GetPropertyChangedSignal(prop):Connect(sync)
	end
	label.Parent = b
	b.Parent = parent
	local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
	b.MouseEnter:Connect(function()
		TweenService:Create(stroke, info, { Color = UiKit.Colors.Gold }):Play()
		TweenService:Create(b, info, { TextColor3 = Color3.fromRGB(255, 236, 196) }):Play()
		grad.Color = ColorSequence.new(Color3.fromRGB(70, 52, 36), Color3.fromRGB(24, 18, 15))
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(stroke, info, { Color = UiKit.Colors.LineDim }):Play()
		TweenService:Create(b, info, { TextColor3 = UiKit.Colors.Parchment }):Play()
		grad.Color = ColorSequence.new(Color3.fromRGB(44, 34, 28), Color3.fromRGB(16, 13, 12))
	end)
	b.MouseButton1Down:Connect(function()
		grad.Color = ColorSequence.new(Color3.fromRGB(110, 80, 46), Color3.fromRGB(40, 28, 20))
	end)
	b.MouseButton1Up:Connect(function()
		grad.Color = ColorSequence.new(Color3.fromRGB(70, 52, 36), Color3.fromRGB(24, 18, 15))
	end)
	return b
end

function UiKit.Pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
end

function UiKit.List(parent: Instance, padding: number, horizontal: boolean?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.Parent = parent
	return l
end

export type Bar = { Root: Frame, Fill: Frame, Ghost: Frame, Label: TextLabel, Set: (number, number, string?) -> () }

-- A resource bar with a trailing "ghost" that shows recent loss.
function UiKit.Bar(parent: Instance, props: { [string]: any }, color: Color3): Bar
	local root = UiKit.Frame(parent, props)
	root.BackgroundColor3 = Color3.fromRGB(8, 6, 6)
	UiKit.Stroke(root, UiKit.Colors.LineDim, 1)
	local ghost = UiKit.Frame(root, { Name = "Ghost", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(230, 210, 180), BackgroundTransparency = 0.35, ZIndex = root.ZIndex })
	local fill = UiKit.Frame(root, { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = root.ZIndex + 1 })
	UiKit.Gradient(fill, color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.35), 90)
	local label = UiKit.Text(root, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 13,
		FontFace = UiKit.BodyBold,
		TextColor3 = Color3.fromRGB(250, 240, 220),
		TextStrokeTransparency = 0.4,
		Text = "",
		ZIndex = root.ZIndex + 2,
	})
	local last = 1
	local bar: any = { Root = root, Fill = fill, Ghost = ghost, Label = label }
	function bar.Set(value: number, max: number, text: string?)
		local frac = if max > 0 then math.clamp(value / max, 0, 1) else 0
		fill.Size = UDim2.fromScale(frac, 1)
		if frac < last then
			task.delay(0.35, function()
				TweenService:Create(ghost, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(frac, 1) }):Play()
			end)
		else
			ghost.Size = UDim2.fromScale(frac, 1)
		end
		last = frac
		label.Text = text or string.format("%d / %d", math.floor(value + 0.5), max)
	end
	return bar
end

-- Draws glyph strokes (unit square, y down) as thin rotated frames.
function UiKit.Glyph(parent: Instance, strokes: { { number } }, color: Color3, thickness: number): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = parent
	for _, s in strokes do
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = color
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		local function layout()
			local size = holder.AbsoluteSize
			local ax, ay = s[1] * size.X, s[2] * size.Y
			local bx, by = s[3] * size.X, s[4] * size.Y
			local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) + thickness
			line.Size = UDim2.fromOffset(len, thickness)
			line.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
			line.Rotation = math.deg(math.atan2(by - ay, bx - ax))
		end
		layout()
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
		line.ZIndex = (parent :: any).ZIndex or 1
		line.Parent = holder
	end
	return holder
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX" }
function UiKit.Roman(n: number): string
	return ROMAN[n] or tostring(n)
end

local ORDINAL = { "FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH", "SIXTH", "SEVENTH", "EIGHTH", "NINTH", "TENTH" }
function UiKit.Ordinal(n: number): string
	return ORDINAL[n] or (UiKit.Roman(n) .. "th")
end

-- Typewriter text: reveals `text` over time. Returns a cancel function.
function UiKit.Typewrite(label: TextLabel, text: string, charsPerSecond: number?): () -> ()
	local cancelled = false
	label.Text = text
	label.MaxVisibleGraphemes = 0
	task.spawn(function()
		local cps = charsPerSecond or 40
		local n = utf8.len(text) or #text
		for i = 1, n do
			if cancelled then
				return
			end
			label.MaxVisibleGraphemes = i
			task.wait(1 / cps)
		end
		label.MaxVisibleGraphemes = -1
	end)
	return function()
		cancelled = true
		label.MaxVisibleGraphemes = -1
	end
end

return UiKit
