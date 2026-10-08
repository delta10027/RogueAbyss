--!strict
-- UI building blocks in the Rogue Abyss visual language (ART_BIBLE §19-20):
-- thin borders, dark surfaces, parchment accents, restrained type.

local UiKit = {}

UiKit.Colors = {
	Ink = Color3.fromRGB(14, 12, 12),
	Panel = Color3.fromRGB(22, 19, 18),
	Line = Color3.fromRGB(120, 104, 80),
	LineDim = Color3.fromRGB(70, 62, 52),
	Parchment = Color3.fromRGB(214, 198, 160),
	Text = Color3.fromRGB(200, 190, 170),
	Dim = Color3.fromRGB(130, 122, 108),
	Amber = Color3.fromRGB(230, 160, 90),
	Blood = Color3.fromRGB(120, 44, 40),
}

-- Display face only for titles and floor names; body face for anything the
-- player must read quickly.
UiKit.Display = Font.fromEnum(Enum.Font.Garamond)
UiKit.Body = Font.fromEnum(Enum.Font.SourceSans)
UiKit.BodyBold = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold)

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

function UiKit.Button(parent: Instance, text: string, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = UiKit.Colors.Ink
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Text = text
	b.TextColor3 = UiKit.Colors.Parchment
	b.FontFace = UiKit.Display
	b.TextSize = 22
	for k, v in props do
		(b :: any)[k] = v
	end
	UiKit.Stroke(b, UiKit.Colors.Line, 1)
	b.Parent = parent
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

return UiKit
