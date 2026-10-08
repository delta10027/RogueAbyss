--!strict
-- Interactive and recurring physical fixtures: doors, gates, braziers,
-- glyphs, the descent, item models. Fixtures only build Instances and expose
-- small handles; gameplay decisions live in services.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Kit = require(script.Parent.Kit)

local P = Kit.Palette
local Grid = Config.Grid

local Fixtures = {}

-- `axis` is the direction the wall runs: "X" (north/south walls) or "Z".
local function wallFrame(pos: Vector3, axis: string): CFrame
	if axis == "X" then
		return CFrame.new(pos)
	end
	return CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0)
end
Fixtures.WallFrame = wallFrame

-- Plain verbs shown to the player; the internal action id stays stable.
local ACTION_TEXT = {
	Take = "Pick up",
	Kindle = "Light",
	Descend = "Go down",
	Drink = "Drink",
	Read = "Read",
	Open = "Open",
	Unlock = "Unlock",
	Pull = "Pull",
	OpenChest = "Open",
}

function Fixtures.Prompt(parent: Instance, action: string, objectText: string, ref: string?, distance: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = ACTION_TEXT[action] or action
	prompt.ObjectText = objectText
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = distance or 8
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt:SetAttribute("Action", action)
	if ref then
		prompt:SetAttribute("Ref", ref)
	end
	prompt.Parent = parent
	return prompt
end

-- Two posts and a heavy lintel: reads as a doorway from the top-down camera.
function Fixtures.DoorFrame(parent: Instance, pos: Vector3, axis: string, color: Color3?, material: Enum.Material?)
	local cf = wallFrame(pos, axis)
	local half = Grid.DoorWidth / 2
	local H = Grid.WallHeight
	local c = color or P.DarkStone
	local m = material or Enum.Material.Slate
	for _, sx in { -1, 1 } do
		Kit.Part(parent, {
			Name = "DoorPost",
			Size = Vector3.new(1.6, H + 1, 3),
			CFrame = cf * CFrame.new(sx * (half + 0.8), (H + 1) / 2, 0),
			Color = c,
			Material = m,
		})
	end
	local lintel = Kit.Deco(parent, {
		Name = "Lintel",
		Size = Vector3.new(Grid.DoorWidth + 3.2, 1.4, 3.2),
		CFrame = cf * CFrame.new(0, H + 0.7, 0),
		Color = P.Soot,
		Material = m,
	})
	CollectionService:AddTag(lintel, "Occluder")
end

-- Wooden door that swings open once. Returns the model and an Open function.
function Fixtures.WoodDoor(parent: Instance, pos: Vector3, axis: string, openSign: number)
	local model = Kit.Model(parent, "WoodDoor")
	local cf = wallFrame(pos, axis)
	local w = Grid.DoorWidth
	local hingeCf = cf * CFrame.new(-w / 2, 0, 0)
	local leaf = Kit.Part(model, {
		Name = "Leaf",
		Size = Vector3.new(w, 8, 0.6),
		CFrame = cf * CFrame.new(0, 4, 0),
		Color = P.Wood,
		Material = Enum.Material.WoodPlanks,
	})
	for _, yy in { 1.6, 6.4 } do
		Kit.Deco(model, {
			Size = Vector3.new(w - 0.4, 0.4, 0.8),
			CFrame = cf * CFrame.new(0, yy, 0),
			Color = P.OldIron,
			Material = Enum.Material.CorrodedMetal,
		})
	end
	model.PrimaryPart = leaf
	local opened = false
	local function open()
		if opened then
			return
		end
		opened = true
		local pivot = hingeCf * CFrame.new(0, 0, 0)
		local rel = {}
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				rel[p] = pivot:ToObjectSpace(p.CFrame)
				p.CanCollide = false
			end
		end
		local value = Instance.new("NumberValue")
		value.Value = 0
		value.Changed:Connect(function(a)
			local rot = pivot * CFrame.Angles(0, math.rad(a * 100 * openSign), 0)
			for p, r in rel do
				p.CFrame = rot * r
			end
		end)
		local tween = TweenService:Create(value, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
		tween:Play()
		tween.Completed:Once(function()
			value:Destroy()
		end)
	end
	return model, open
end

-- Iron portcullis. SetOpen raises or lowers the bars.
function Fixtures.Gate(parent: Instance, pos: Vector3, axis: string)
	local model = Kit.Model(parent, "Gate")
	local cf = wallFrame(pos, axis)
	local w = Grid.DoorWidth
	local bars = {}
	for i = 0, 6 do
		local x = -w / 2 + 0.6 + i * ((w - 1.2) / 6)
		table.insert(bars, Kit.Part(model, {
			Name = "Bar",
			Size = Vector3.new(0.45, 9, 0.45),
			CFrame = cf * CFrame.new(x, 4.5, 0),
			Color = P.OldIron,
			Material = Enum.Material.CorrodedMetal,
		}))
	end
	for _, yy in { 2.5, 6.5 } do
		table.insert(bars, Kit.Part(model, {
			Name = "Cross",
			Size = Vector3.new(w, 0.45, 0.45),
			CFrame = cf * CFrame.new(0, yy, 0),
			Color = P.OldIron,
			Material = Enum.Material.CorrodedMetal,
		}))
	end
	local base: { [BasePart]: CFrame } = {}
	for _, b in bars do
		base[b] = b.CFrame
	end
	local isOpen = false
	local function setOpen(open: boolean, instant: boolean?)
		isOpen = open
		for b, c in base do
			local target = if open then c * CFrame.new(0, 8.6, 0) else c
			b.CanCollide = not open
			if instant then
				b.CFrame = target
			else
				TweenService:Create(b, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = target }):Play()
			end
		end
	end
	return model, setOpen, function()
		return isOpen
	end
end

-- Locked iron door; opens by sliding sideways into the wall.
function Fixtures.IronDoor(parent: Instance, pos: Vector3, axis: string)
	local model = Kit.Model(parent, "IronDoor")
	local cf = wallFrame(pos, axis)
	local w = Grid.DoorWidth
	local slab = Kit.Part(model, {
		Name = "Slab",
		Size = Vector3.new(w, 9, 1.2),
		CFrame = cf * CFrame.new(0, 4.5, 0),
		Color = Color3.fromRGB(46, 42, 40),
		Material = Enum.Material.CorrodedMetal,
	})
	for _, xx in { -2.6, 0, 2.6 } do
		Kit.Deco(model, {
			Size = Vector3.new(0.5, 8.6, 1.4),
			CFrame = cf * CFrame.new(xx, 4.5, 0),
			Color = P.Rust,
			Material = Enum.Material.CorrodedMetal,
		})
	end
	local lock = Kit.Deco(model, {
		Name = "Lock",
		Size = Vector3.new(1.2, 1.4, 1.8),
		CFrame = cf * CFrame.new(1.2, 4, 0),
		Color = P.Gold,
		Material = Enum.Material.Metal,
	})
	local opened = false
	local function open()
		if opened then
			return
		end
		opened = true
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Sine), { CFrame = p.CFrame * CFrame.new(0, -8.8, 0) }):Play()
			end
		end
	end
	return model, open, slab, lock
end

-- Breakable cracked masonry used to hide secret passages. The crack is
-- subtle: same stone, darker seams, and the draft visibly drawn into it.
function Fixtures.CrackedWall(parent: Instance, pos: Vector3, axis: string, wallColor: Color3, wallMaterial: Enum.Material, inward: Vector3)
	local model = Kit.Model(parent, "CrackedWall")
	local cf = wallFrame(pos, axis)
	local w = Grid.DoorWidth + 0.4
	local H = Grid.WallHeight
	local block = Kit.Part(model, {
		Name = "Block",
		Size = Vector3.new(w, H, 2),
		CFrame = cf * CFrame.new(0, H / 2, 0),
		Color = wallColor,
		Material = wallMaterial,
	})
	CollectionService:AddTag(block, "Occluder")
	local seams = {
		{ -1.5, 2.0, 0.25, 3.4, 20 },
		{ -0.6, 4.4, 0.25, 2.6, -25 },
		{ 0.4, 6.2, 0.25, 3.0, 30 },
		{ 1.6, 3.2, 0.25, 2.2, -10 },
	}
	for _, s in seams do
		for _, face in { -1, 1 } do
			Kit.Deco(model, {
				Size = Vector3.new(s[3], s[4], 0.1),
				CFrame = cf * CFrame.new(s[1], s[2], face * 1.02) * CFrame.Angles(0, 0, math.rad(s[5])),
				Color = P.Soot,
				Material = Enum.Material.Slate,
				CastShadow = false,
			})
		end
	end
	local dustAnchor = Kit.Attachment(block, block.CFrame:VectorToObjectSpace(-inward) * 1.6 + Vector3.new(0, -H / 2 + 1, 0))
	Kit.Dust(dustAnchor, inward, 5)
	local function shatter()
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.Transparency = 1
			end
		end
		local rng = Random.new()
		for _ = 1, 7 do
			local chunk = Instance.new("Part")
			chunk.Size = Vector3.new(rng:NextNumber(0.8, 1.8), rng:NextNumber(0.6, 1.4), rng:NextNumber(0.8, 1.6))
			chunk.CFrame = block.CFrame * CFrame.new(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), 0)
			chunk.Color = wallColor
			chunk.Material = wallMaterial
			chunk.CanCollide = true
			chunk.CollisionGroup = "Debris"
			chunk.AssemblyLinearVelocity = inward * rng:NextNumber(8, 16) + Vector3.new(0, 6, 0)
			chunk.Parent = model
			Debris:AddItem(chunk, 6)
		end
		task.delay(6.5, function()
			if model.Parent then
				for _, p in model:GetChildren() do
					if p:IsA("BasePart") then
						p:Destroy()
					end
				end
			end
		end)
	end
	return model, block, shatter
end

export type BrazierHandle = {
	Model: Model,
	Bowl: BasePart,
	Light: PointLight,
	SetLit: (boolean) -> (),
	IsLit: () -> boolean,
}

function Fixtures.Brazier(parent: Instance, pos: Vector3, lit: boolean): BrazierHandle
	local model = Kit.Model(parent, "Brazier")
	for i = 0, 2 do
		local a = math.rad(i * 120)
		Kit.Part(model, {
			Name = "Leg",
			Size = Vector3.new(0.3, 3, 0.3),
			CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 0.9, 1.5, math.sin(a) * 0.9)) * CFrame.Angles(math.sin(a) * 0.15, 0, -math.cos(a) * 0.15),
			Color = P.OldIron,
			Material = Enum.Material.CorrodedMetal,
		})
	end
	local bowl = Kit.Part(model, {
		Name = "Bowl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.9, 2.6, 2.6),
		CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = P.OldIron,
		Material = Enum.Material.CorrodedMetal,
	})
	local coals = Kit.Deco(model, {
		Name = "Coals",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 2.1, 2.1),
		CFrame = CFrame.new(pos + Vector3.new(0, 3.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = P.Soot,
		Material = Enum.Material.Slate,
	})
	local flameAt = Kit.Attachment(bowl, Vector3.new(0.6, 0, 0))
	local flame = Kit.Flame(flameAt, 1.1)
	local embers = Kit.Embers(flameAt)
	local light = Kit.PointLight(flameAt, P.Amber, Config.Brazier.LightRadius, 1.5, true)
	model.PrimaryPart = bowl
	local isLit = false
	local function setLit(on: boolean)
		isLit = on
		flame.Enabled = on
		embers.Enabled = on
		light.Enabled = on
		coals.Color = if on then Color3.fromRGB(78, 34, 16) else P.Soot
		coals.Material = if on then Enum.Material.Neon else Enum.Material.Slate
		model:SetAttribute("Lit", on)
	end
	setLit(lit)
	CollectionService:AddTag(model, "Brazier")
	return {
		Model = model,
		Bowl = bowl,
		Light = light,
		SetLit = setLit,
		IsLit = function()
			return isLit
		end,
	}
end

function Fixtures.Candle(parent: Instance, pos: Vector3, withLight: boolean)
	local wax = Kit.Deco(parent, {
		Name = "Candle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.9, 0.35, 0.35),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = P.Bone,
		Material = Enum.Material.SmoothPlastic,
		CastShadow = false,
	})
	local tip = Kit.Attachment(wax, Vector3.new(0.55, 0, 0))
	local e = Kit.Flame(tip, 0.25)
	e.Rate = 10
	if withLight then
		Kit.PointLight(tip, P.Candle, 10, 0.8, false)
	end
	return wax
end

-- Draws glyph strokes (unit square, y down) onto a surface. `surface` is a
-- CFrame at the glyph centre whose LookVector points out of the surface.
function Fixtures.Glyph(parent: Instance, surface: CFrame, size: number, strokes: { { number } }, color: Color3, thickness: number?, glow: boolean?)
	local model = Kit.Model(parent, "Glyph")
	local t = thickness or size * 0.07
	for _, s in strokes do
		-- X is negated: a surface seen from the front shows its RightVector
		-- on the viewer's left, so this keeps glyphs un-mirrored.
		local a = Vector3.new(-(s[1] - 0.5) * size, -(s[2] - 0.5) * size, 0)
		local b = Vector3.new(-(s[3] - 0.5) * size, -(s[4] - 0.5) * size, 0)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + t
		local angle = math.atan2(b.Y - a.Y, b.X - a.X)
		local part = Kit.Deco(model, {
			Name = "Stroke",
			Size = Vector3.new(len, t, 0.12),
			CFrame = surface * CFrame.new(mid.X, mid.Y, -0.04) * CFrame.Angles(0, 0, angle),
			Color = color,
			Material = if glow then Enum.Material.Neon else Enum.Material.Slate,
			CastShadow = false,
		})
		part.CanQuery = false
	end
	return model
end

-- Horizontal glyph carved into the floor (faces up).
function Fixtures.FloorGlyph(parent: Instance, center: Vector3, size: number, strokes: { { number } }, color: Color3, yaw: number?)
	-- Faces up, with the glyph's top pointing north (screen-up for the camera).
	local facing = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))
	local surface = CFrame.new(center + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, yaw or 0, 0) * facing
	return Fixtures.Glyph(parent, surface, size, strokes, color, size * 0.08)
end

-- The way down: a square pit with a few visible steps, cold light rising.
function Fixtures.Descent(parent: Instance, center: Vector3, size: number)
	local model = Kit.Model(parent, "Descent")
	local half = size / 2
	-- Rim stones.
	for _, e in {
		{ Vector3.new(size + 2, 0.6, 1), Vector3.new(0, 0.3, -half - 0.5) },
		{ Vector3.new(size + 2, 0.6, 1), Vector3.new(0, 0.3, half + 0.5) },
		{ Vector3.new(1, 0.6, size), Vector3.new(-half - 0.5, 0.3, 0) },
		{ Vector3.new(1, 0.6, size), Vector3.new(half + 0.5, 0.3, 0) },
	} do
		Kit.Part(model, {
			Name = "Rim",
			Size = e[1],
			CFrame = CFrame.new(center + e[2]),
			Color = P.PaleStone,
			Material = Enum.Material.Slate,
		})
	end
	-- Black void floor far below and the pit walls.
	Kit.Part(model, {
		Name = "PitBottom",
		Size = Vector3.new(size, 1, size),
		CFrame = CFrame.new(center + Vector3.new(0, -26, 0)),
		Color = Color3.new(0, 0, 0),
		Material = Enum.Material.Slate,
	})
	for _, e in {
		{ Vector3.new(size, 26, 0.5), Vector3.new(0, -13, -half) },
		{ Vector3.new(size, 26, 0.5), Vector3.new(0, -13, half) },
		{ Vector3.new(0.5, 26, size), Vector3.new(-half, -13, 0) },
		{ Vector3.new(0.5, 26, size), Vector3.new(half, -13, 0) },
	} do
		Kit.Part(model, {
			Name = "PitWall",
			Size = e[1],
			CFrame = CFrame.new(center + e[2]),
			Color = P.Soot,
			Material = Enum.Material.Slate,
		})
	end
	-- Spiral steps vanishing into the dark.
	for i = 0, 9 do
		local a = math.rad(i * 34)
		local r = half - 1.6
		Kit.Part(model, {
			Name = "Step",
			Size = Vector3.new(3, 0.6, 2.2),
			CFrame = CFrame.new(center + Vector3.new(math.cos(a) * r, -1.5 - i * 1.6, math.sin(a) * r)) * CFrame.Angles(0, -a, 0),
			Color = Kit.Vary(P.AgedStone, 0.1, i),
			Material = Enum.Material.Slate,
		})
	end
	-- Invisible lid keeps players from falling in; the descent is a choice.
	Kit.Part(model, {
		Name = "Lid",
		Size = Vector3.new(size, 0.4, size),
		CFrame = CFrame.new(center + Vector3.new(0, -0.2, 0)),
		Transparency = 1,
		CastShadow = false,
	})
	local glowAt = Kit.Part(model, {
		Name = "Glow",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(center + Vector3.new(0, -8, 0)),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	})
	Kit.PointLight(glowAt, P.Moon, size + 14, 1.2, false)
	local promptPart = Kit.Part(model, {
		Name = "PromptAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 1.5, 0)),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	})
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(120, 140, 170))
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime = NumberRange.new(4, 6)
	mist.Rate = 3
	mist.Speed = NumberRange.new(0.6, 1.2)
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Parent = glowAt
	return model, promptPart
end

-- A wooden chest with an iron band. Returns the model, the prompt part and
-- an Open() function that swings the lid back.
function Fixtures.Chest(parent: Instance, pos: Vector3, facing: Vector3, quality: number)
	local model = Kit.Model(parent, "Chest")
	local cf = CFrame.lookAt(pos, pos + facing)
	local wood = if quality >= 3 then P.Burgundy else P.Wood
	local body = Kit.Part(model, {
		Name = "Body",
		Size = Vector3.new(3.4, 1.8, 2.2),
		CFrame = cf * CFrame.new(0, 0.9, 0),
		Color = wood,
		Material = Enum.Material.Wood,
	})
	local hinge = cf * CFrame.new(0, 1.8, 1.1)
	local lid = Kit.Part(model, {
		Name = "Lid",
		Size = Vector3.new(3.5, 0.6, 2.3),
		CFrame = hinge * CFrame.new(0, 0.3, -1.15),
		Color = wood,
		Material = Enum.Material.Wood,
	})
	local bandColor = if quality >= 3 then P.Gold else P.OldIron
	for _, x in { -1.2, 1.2 } do
		Kit.Deco(model, {
			Size = Vector3.new(0.3, 2.5, 2.35),
			CFrame = cf * CFrame.new(x, 1.2, 0),
			Color = bandColor,
			Material = Enum.Material.Metal,
		})
	end
	local lock = Kit.Deco(model, {
		Size = Vector3.new(0.5, 0.6, 0.2),
		CFrame = cf * CFrame.new(0, 1.6, -1.15),
		Color = bandColor,
		Material = Enum.Material.Metal,
	})
	model.PrimaryPart = body
	local function open()
		local lidOffset = hinge:ToObjectSpace(lid.CFrame)
		local target = hinge * CFrame.Angles(math.rad(105), 0, 0) * lidOffset
		TweenService:Create(lid, TweenInfo.new(0.5, Enum.EasingStyle.Back), { CFrame = target }):Play()
		lock.Transparency = 1
		local glow = Kit.Attachment(body, Vector3.new(0, 1, 0))
		Kit.PointLight(glow, Color3.fromRGB(255, 200, 120), 8, 0.8, false)
	end
	return model, body, open
end

-- Physical item models (ART_BIBLE §16): small, grounded, no beams.
function Fixtures.ItemModel(parent: Instance, pos: Vector3, itemId: string, color: Color3, category: string?): Model
	local model = Kit.Model(parent, "Item_" .. itemId)
	local base: BasePart
	if category == "Weapon" then
		base = Kit.Part(model, {
			Name = "Body",
			Size = Vector3.new(0.35, 0.25, 3.4),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.rad(35), 0),
			Color = color,
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		Kit.Deco(model, {
			Size = Vector3.new(1.3, 0.3, 0.3),
			CFrame = base.CFrame * CFrame.new(0, 0, 1.1),
			Color = P.DarkBrown,
			Material = Enum.Material.Wood,
		})
		-- A faint glint so gear reads in the dark.
		Kit.PointLight(base, Color3.fromRGB(200, 190, 160), 5, 0.6, false)
	elseif category == "Armor" then
		base = Kit.Part(model, {
			Name = "Body",
			Size = Vector3.new(2, 0.4, 1.6),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.rad(20), 0),
			Color = color,
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		Kit.Deco(model, {
			Size = Vector3.new(2.6, 0.35, 0.6),
			CFrame = base.CFrame * CFrame.new(0, 0.05, -0.8),
			Color = color,
			Material = Enum.Material.Metal,
		})
		Kit.PointLight(base, Color3.fromRGB(200, 190, 160), 5, 0.6, false)
	elseif category == "Potion" then
		base = Kit.Part(model, {
			Name = "Body",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.45, 0)),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.1,
			CanCollide = false,
		})
		Kit.Deco(model, {
			Size = Vector3.new(0.3, 0.5, 0.3),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.1, 0)),
			Color = P.Wood,
			Material = Enum.Material.Wood,
		})
		Kit.PointLight(base, color, 4, 0.5, false)
	elseif category == "Scroll" then
		base = Kit.Part(model, {
			Name = "Body",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 0.45, 0.45),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.23, 0)) * CFrame.Angles(0, math.rad(60), 0),
			Color = P.Parchment,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
		Kit.Deco(model, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 0.5, 0.5),
			CFrame = base.CFrame,
			Color = P.Burgundy,
			Material = Enum.Material.Fabric,
		})
	elseif category == "Food" then
		base = Kit.Part(model, {
			Name = "Body",
			Size = Vector3.new(1.2, 0.5, 0.8),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, math.rad(15), 0),
			Color = color,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	elseif category == "Gold" then
		base = Kit.Part(model, {
			Name = "Body",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 1.1, 1.1),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		for i = 1, 3 do
			local a = i * 2.1
			Kit.Deco(model, {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.15, 0.6, 0.6),
				CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 0.7, 0.08 + i * 0.05, math.sin(a) * 0.7)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = color,
				Material = Enum.Material.Metal,
			})
		end
		Kit.PointLight(base, Color3.fromRGB(255, 200, 110), 5, 0.7, false)
	elseif itemId == "OilFlask" then
		base = Kit.Part(model, {
			Name = "Body",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.1, 1.1, 1.1),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.55, 0)),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			CanCollide = false,
		})
		Kit.Deco(model, {
			Size = Vector3.new(0.35, 0.6, 0.35),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.3, 0)),
			Color = P.DarkBrown,
			Material = Enum.Material.Wood,
		})
	elseif itemId == "TinBell" then
		base = Kit.Part(model, {
			Name = "Body",
			Size = Vector3.new(1, 0.9, 1),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.45, 0)),
			Color = color,
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		Kit.Deco(model, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.8, 0.8, 0.8),
			CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)),
			Color = color,
			Material = Enum.Material.Metal,
		})
		Kit.Deco(model, {
			Size = Vector3.new(0.15, 0.6, 0.15),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.55, 0)),
			Color = P.DarkBrown,
			Material = Enum.Material.Fabric,
		})
	elseif itemId == "Tincture" then
		base = Kit.Part(model, {
			Name = "Body",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.1, 0.55, 0.55),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.1,
			CanCollide = false,
		})
		Kit.Deco(model, {
			Size = Vector3.new(0.3, 0.3, 0.3),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.25, 0)),
			Color = P.Wood,
			Material = Enum.Material.Wood,
		})
	elseif itemId == "RustedKey" then
		base = Kit.Part(model, {
			Name = "Body",
			Size = Vector3.new(1.6, 0.2, 0.3),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.rad(30), 0),
			Color = color,
			Material = Enum.Material.CorrodedMetal,
			CanCollide = false,
		})
		Kit.Deco(model, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 0.8, 0.8),
			CFrame = base.CFrame * CFrame.new(-0.9, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = Enum.Material.CorrodedMetal,
		})
	else -- Curio on a small plinth
		Kit.Part(model, {
			Name = "Plinth",
			Size = Vector3.new(2, 2.4, 2),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0)),
			Color = P.PaleStone,
			Material = Enum.Material.Limestone,
		})
		base = Kit.Part(model, {
			Name = "Body",
			Size = Vector3.new(0.7, 0.7, 0.7),
			CFrame = CFrame.new(pos + Vector3.new(0, 2.8, 0)) * CFrame.Angles(math.rad(20), math.rad(35), 0),
			Color = P.Gold,
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
	end
	model.PrimaryPart = base
	return model
end

return Fixtures
