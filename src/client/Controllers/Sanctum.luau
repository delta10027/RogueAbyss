--!strict
-- The Sanctum: a small candlelit ruin built locally (only this player sees
-- it) that sits behind the main menu, and the stage for character
-- creation. In creation the explorer is drawn up out of a pool of shadow on
-- the left while a voice on the right asks who they are.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boons = require(Shared.Definitions.Boons)
local Spells = require(Shared.Definitions.Spells)

local ClientState = require(script.Parent.ClientState)
local UiKit = require(script.Parent.UiKit)
local Audio = require(script.Parent.Audio)

local C = UiKit.Colors

local Sanctum = {}

local ORIGIN = Vector3.new(-5000, 0, -5000)

local scene: Model? = nil
local figure: Model? = nil
local cameraMode = "Off" -- "Off" | "Menu" | "Create"
local cameraStart = 0

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Slate
	p.Color = Color3.fromRGB(70, 64, 58)
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function flame(parent: BasePart, scale: number, lightRange: number)
	local at = Instance.new("Attachment")
	at.Position = Vector3.new(0, parent.Size.Y / 2 + 0.1, 0)
	at.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/fire_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 210, 140), Color3.fromRGB(220, 90, 30))
	e.LightEmission = 0.7
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * scale), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Rate = 14
	e.Speed = NumberRange.new(1 * scale, 2 * scale)
	e.SpreadAngle = Vector2.new(6, 6)
	e.Parent = at
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 170, 100)
	l.Range = lightRange
	l.Brightness = 2.4
	l.Shadows = true
	l.Parent = at
	game:GetService("CollectionService"):AddTag(l, "Flicker")
end

local function build()
	if scene then
		return
	end
	local m = Instance.new("Model")
	m.Name = "Sanctum"
	local o = ORIGIN
	-- Floor and a raised round dais.
	part(m, { Name = "Floor", Size = Vector3.new(120, 2, 120), CFrame = CFrame.new(o + Vector3.new(0, -1, 0)), Color = Color3.fromRGB(40, 37, 34), Material = Enum.Material.Slate })
	part(m, { Name = "Dais", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 26, 26), CFrame = CFrame.new(o + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(62, 58, 54), Material = Enum.Material.Slate })
	part(m, { Name = "DaisRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 27, 27), CFrame = CFrame.new(o + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(110, 92, 64), Material = Enum.Material.Metal })
	-- The pool of shadow the explorer rises from.
	local pool = part(m, { Name = "Pool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 8, 8), CFrame = CFrame.new(o + Vector3.new(-4, 1.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(4, 3, 6), Material = Enum.Material.Glass, Reflectance = 0.2 })
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Shadow"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(10, 6, 14))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 4.5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(2, 3.5)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(0.5, 1.5)
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Parent = pool
	-- A ring of pillars and broken arches behind.
	for i = 0, 6 do
		local a = math.rad(-150 + i * 50)
		local p = o + Vector3.new(math.sin(a) * 22, 0, -math.cos(a) * 22)
		local h = if i % 3 == 1 then 7 else 16
		part(m, { Name = "Pillar", Size = Vector3.new(3, h, 3), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)), Color = Color3.fromRGB(86, 80, 72) })
		part(m, { Name = "Base", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(p + Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(60, 56, 52) })
		if h > 10 then
			part(m, { Name = "Capital", Size = Vector3.new(4, 1.2, 4), CFrame = CFrame.new(p + Vector3.new(0, h + 0.6, 0)), Color = Color3.fromRGB(60, 56, 52) })
		else
			part(m, { Name = "Rubble", Size = Vector3.new(2.5, 1.6, 2), CFrame = CFrame.new(p + Vector3.new(2.5, 0.8, 1)) * CFrame.Angles(0.3, 0.6, 0.2), Color = Color3.fromRGB(80, 74, 66) })
		end
	end
	part(m, { Name = "Lintel", Size = Vector3.new(26, 2.4, 3), CFrame = CFrame.new(o + Vector3.new(0, 17.2, -22)), Color = Color3.fromRGB(80, 74, 66) })
	-- A great hooded statue watching from the back.
	local statue = o + Vector3.new(6, 0, -16)
	part(m, { Name = "Plinth", Size = Vector3.new(6, 3, 6), CFrame = CFrame.new(statue + Vector3.new(0, 1.5, 0)), Color = Color3.fromRGB(60, 56, 52) })
	part(m, { Name = "Robe", Size = Vector3.new(5, 10, 4), CFrame = CFrame.new(statue + Vector3.new(0, 8, 0)), Color = Color3.fromRGB(96, 92, 86) })
	part(m, { Name = "Hood", Size = Vector3.new(3.6, 3.8, 3.6), CFrame = CFrame.new(statue + Vector3.new(0, 14.6, 0.3)) * CFrame.Angles(math.rad(-12), 0, 0), Color = Color3.fromRGB(92, 88, 82) })
	part(m, { Name = "Face", Size = Vector3.new(2.4, 2.2, 0.3), CFrame = CFrame.new(statue + Vector3.new(0, 14.4, 2.05)), Color = Color3.fromRGB(8, 6, 6), Material = Enum.Material.SmoothPlastic })
	local eye = part(m, { Name = "Eye", Size = Vector3.new(0.9, 0.2, 0.1), CFrame = CFrame.new(statue + Vector3.new(0, 14.6, 2.25)), Color = Color3.fromRGB(255, 190, 110), Material = Enum.Material.Neon })
	local eyeLight = Instance.new("PointLight")
	eyeLight.Color = Color3.fromRGB(255, 170, 90)
	eyeLight.Range = 8
	eyeLight.Brightness = 1.2
	eyeLight.Parent = eye
	-- Candle clusters around the dais.
	for i = 0, 7 do
		local a = math.rad(i * 45 + 20)
		local base = o + Vector3.new(math.sin(a) * 11.5, 1, math.cos(a) * 11.5)
		for j = 0, 2 do
			local h = 0.8 + ((i + j) % 3) * 0.5
			local c = part(m, { Name = "Candle", Size = Vector3.new(0.4, h, 0.4), CFrame = CFrame.new(base + Vector3.new(j * 0.6 - 0.6, h / 2, (j % 2) * 0.5)), Color = Color3.fromRGB(150, 136, 112), Material = Enum.Material.Sand })
			if j == 1 then
				flame(c, 0.6, 12)
			else
				local at = Instance.new("Attachment")
				at.Position = Vector3.new(0, h / 2 + 0.1, 0)
				at.Parent = c
				local e = Instance.new("ParticleEmitter")
				e.Texture = "rbxasset://textures/particles/fire_main.dds"
				e.Color = ColorSequence.new(Color3.fromRGB(255, 210, 140))
				e.LightEmission = 0.7
				e.LightInfluence = 0
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
				e.Lifetime = NumberRange.new(0.3, 0.5)
				e.Rate = 12
				e.Speed = NumberRange.new(0.6, 1.2)
				e.Parent = at
			end
		end
	end
	-- Drifting embers over everything.
	local emberBox = part(m, { Name = "Embers", Size = Vector3.new(40, 1, 40), CFrame = CFrame.new(o + Vector3.new(0, 0.5, 0)), Transparency = 1 })
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.Color = ColorSequence.new(Color3.fromRGB(255, 160, 80))
	em.LightEmission = 1
	em.LightInfluence = 0
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	em.Lifetime = NumberRange.new(4, 7)
	em.Rate = 12
	em.Speed = NumberRange.new(1, 2.5)
	em.SpreadAngle = Vector2.new(25, 25)
	em.Acceleration = Vector3.new(0.3, 0.4, 0)
	em.Parent = emberBox
	-- Tall braziers between the pillars and a soft fill so the scene reads.
	for _, a in { -60, -20, 20, 60 } do
		local r = math.rad(a)
		local p = o + Vector3.new(math.sin(r) * 17, 0, -math.cos(r) * 17)
		part(m, { Name = "BrazierStand", Size = Vector3.new(0.6, 4, 0.6), CFrame = CFrame.new(p + Vector3.new(0, 2, 0)), Color = Color3.fromRGB(50, 46, 42), Material = Enum.Material.Metal })
		local bowl = part(m, { Name = "BrazierBowl", Size = Vector3.new(2.4, 0.8, 2.4), CFrame = CFrame.new(p + Vector3.new(0, 4.3, 0)), Color = Color3.fromRGB(60, 50, 40), Material = Enum.Material.Metal })
		flame(bowl, 1.6, 28)
	end
	local fill = part(m, { Name = "Fill", Size = Vector3.one, CFrame = CFrame.new(o + Vector3.new(4, 14, 12)), Transparency = 1 })
	local fl = Instance.new("PointLight")
	fl.Color = Color3.fromRGB(200, 170, 150)
	fl.Range = 70
	fl.Brightness = 1.6
	fl.Shadows = false
	fl.Parent = fill
	-- A cold light from above for the risen figure.
	local spot = part(m, { Name = "SpotHolder", Size = Vector3.new(1, 1, 1), CFrame = CFrame.lookAt(o + Vector3.new(-2, 16, 6), o + Vector3.new(-4, 0, 0)), Transparency = 1 })
	local sl = Instance.new("SpotLight")
	sl.Name = "FigureLight"
	sl.Color = Color3.fromRGB(170, 180, 220)
	sl.Range = 30
	sl.Angle = 35
	sl.Brightness = 0
	sl.Face = Enum.NormalId.Front
	sl.Parent = spot
	m.Parent = Workspace -- local only; lights under the Camera do not illuminate
	scene = m
end

-- Lights created before the camera reaches this far-off spot are never
-- picked up by the lighting engine; re-enabling them once it arrives does.
local function refreshLights()
	if not scene then
		return
	end
	for _, d in scene:GetDescendants() do
		if d:IsA("Light") and d.Enabled then
			d.Enabled = false
			d.Enabled = true
		end
	end
end

local function setCameraMode(m: string)
	cameraMode = m
	cameraStart = os.clock()
	ClientState.CameraOverride = m ~= "Off"
	if m ~= "Off" then
		for _, t in { 0.1, 0.5, 1.5 } do
			task.delay(t, refreshLights)
		end
	end
end

function Sanctum.ShowMenu()
	build()
	setCameraMode("Menu")
end

function Sanctum.Hide()
	setCameraMode("Off")
	if figure then
		figure:Destroy()
		figure = nil
	end
	local spot = scene and scene:FindFirstChild("SpotHolder")
	local sl = spot and spot:FindFirstChild("FigureLight") :: SpotLight?
	if sl then
		sl.Brightness = 0
	end
end

-- Clones the player's (dressed) character and draws it up out of the pool.
local function raiseFigure()
	if figure then
		figure:Destroy()
		figure = nil
	end
	local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 5)
	character.Archivable = true
	local ok, clone = pcall(function()
		return character:Clone()
	end)
	character.Archivable = false
	if not ok or not clone then
		return
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.Anchored = true -- the whole figure is posed, not simulated
		end
	end
	local root = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if not root then
		clone:Destroy()
		return
	end
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.PlatformStand = true
	end
	root.Anchored = true
	local height = root.Size.Y / 2 + (if hum then hum.HipHeight else 2)
	local stand = CFrame.lookAt(ORIGIN + Vector3.new(-4, 1 + height, 0), ORIGIN + Vector3.new(-4, 1 + height, 30))
	clone:PivotTo(stand * CFrame.new(0, -7, 0))
	clone.Parent = scene
	figure = clone
	-- Born of shadow: black at first, colour seeps in as it rises.
	local shade = Instance.new("Highlight")
	shade.FillColor = Color3.new(0, 0, 0)
	shade.FillTransparency = 0
	shade.OutlineColor = Color3.fromRGB(140, 120, 200)
	shade.OutlineTransparency = 0.4
	shade.DepthMode = Enum.HighlightDepthMode.Occluded
	shade.Parent = clone
	local t0 = os.clock()
	local rise = 3.2
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not clone.Parent then
			conn:Disconnect()
			return
		end
		local a = math.clamp((os.clock() - t0) / rise, 0, 1)
		local e = 1 - (1 - a) ^ 3
		clone:PivotTo(stand * CFrame.new(0, -7 * (1 - e), 0) * CFrame.Angles(0, math.sin(os.clock() * 0.6) * 0.05, 0))
		if a >= 1 then
			conn:Disconnect()
		end
	end)
	TweenService:Create(shade, TweenInfo.new(rise + 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	local pool = scene and scene:FindFirstChild("Pool")
	local smoke = pool and pool:FindFirstChild("Shadow") :: ParticleEmitter?
	if smoke then
		smoke:Emit(40)
	end
	local spot = scene and scene:FindFirstChild("SpotHolder")
	local sl = spot and spot:FindFirstChild("FigureLight") :: SpotLight?
	if sl then
		sl.Brightness = 0
		TweenService:Create(sl, TweenInfo.new(rise), { Brightness = 3 }):Play()
	end
	Audio.Play("Sting", nil, 0.5, 0.7, 5)
	Audio.Play("Whisper", nil, 0.45, 0.8, 3.5)
end

---------------------------------------------------------------------------
-- Character creation
---------------------------------------------------------------------------

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

-- Runs the creation scene inside `layer`. Calls onDone(config) or
-- onCancel(). `prev` pre-fills the answers.
function Sanctum.Create(layer: Frame, prev: any?, onDone: (any) -> (), onCancel: () -> ())
	build()
	setCameraMode("Create")
	task.spawn(raiseFigure)

	local config = {
		Name = (prev and prev.Name) or Players.LocalPlayer.DisplayName,
		Boons = {},
		Flaws = {},
		Spell = (prev and prev.Spell) or "MagicMissile",
	}

	local root = UiKit.Frame(layer, { Name = "Creation", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 })
	-- Darken the right side for the text.
	local shadeFrame = UiKit.Frame(root, { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 30 })
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.62, 0.25), NumberSequenceKeypoint.new(1, 0.1) })
	g.Parent = shadeFrame
	local panel = UiKit.Frame(root, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 0),
		Size = UDim2.new(0.44, 0, 0.86, 0),
		ZIndex = 31,
	})
	local voice = UiKit.Text(panel, {
		Size = UDim2.new(1, 0, 0, 90),
		FontFace = UiKit.Display,
		TextSize = 30,
		TextColor3 = C.Parchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		ZIndex = 32,
	})
	local hint = UiKit.Text(panel, {
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 32,
	})
	local body = UiKit.Frame(panel, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 124), Size = UDim2.new(1, 0, 1, -184), ZIndex = 32 })
	local nav = UiKit.Frame(panel, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 46), ZIndex = 32 })
	UiKit.List(nav, 10, true)

	local stepIndex = 1
	local steps: { () -> () } = {}
	local cancelType: (() -> ())? = nil

	local function clearBody()
		for _, c in body:GetChildren() do
			c:Destroy()
		end
		for _, c in nav:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	local function say(text: string, sub: string?)
		if cancelType then
			cancelType()
		end
		cancelType = UiKit.Typewrite(voice, text, 38)
		hint.Text = sub or ""
		Audio.Play("Whisper", nil, 0.3, 0.9 + math.random() * 0.2, 2.5)
	end

	local function navButton(text: string, w: number, onClick: () -> ())
		local b = UiKit.Button(nav, text, { Size = UDim2.fromOffset(w, 42), ZIndex = 33, LayoutOrder = #nav:GetChildren() })
		b.Activated:Connect(onClick)
		return b
	end

	local function go(i: number)
		stepIndex = i
		clearBody()
		steps[i]()
	end

	-- A grid of toggleable trait cards.
	local function traitGrid(list, chosen: { string }, limit: () -> number, onChange: () -> (), accent: Color3)
		local scroll = Instance.new("ScrollingFrame")
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.Size = UDim2.fromScale(1, 1)
		scroll.ScrollBarThickness = 4
		scroll.ScrollBarImageColor3 = C.LineDim
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new()
		scroll.ZIndex = 32
		scroll.Parent = body
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0.5, -6, 0, 62)
		grid.CellPadding = UDim2.fromOffset(8, 8)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = scroll
		for i, t in list do
			local card = Instance.new("TextButton")
			card.Text = ""
			card.AutoButtonColor = false
			card.BackgroundColor3 = Color3.new(1, 1, 1)
			card.LayoutOrder = i
			card.ZIndex = 33
			card.Parent = scroll
			local grad = UiKit.Gradient(card, Color3.fromRGB(34, 28, 24), Color3.fromRGB(12, 10, 10), 90)
			local stroke = UiKit.Stroke(card, C.LineDim, 1.2)
			UiKit.Text(card, { Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -20, 0, 22), FontFace = UiKit.Display, TextSize = 20, TextColor3 = C.Parchment, TextXAlignment = Enum.TextXAlignment.Left, Text = t.Name, ZIndex = 34 })
			UiKit.Text(card, { Position = UDim2.fromOffset(10, 27), Size = UDim2.new(1, -20, 0, 32), TextSize = 14, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = t.Description, ZIndex = 34 })
			local function paint()
				local on = table.find(chosen, t.Id) ~= nil
				stroke.Color = if on then accent else C.LineDim
				stroke.Thickness = if on then 2 else 1.2
				grad.Color = if on then ColorSequence.new(accent:Lerp(Color3.new(0, 0, 0), 0.6), Color3.fromRGB(14, 11, 10)) else ColorSequence.new(Color3.fromRGB(34, 28, 24), Color3.fromRGB(12, 10, 10))
			end
			paint()
			card.Activated:Connect(function()
				local idx = table.find(chosen, t.Id)
				if idx then
					table.remove(chosen, idx)
				elseif #chosen < limit() then
					table.insert(chosen, t.Id)
					Audio.Play("Clank", nil, 0.2, 1.6, 0.5)
				else
					return
				end
				paint()
				onChange()
			end)
		end
	end

	steps[1] = function()
		say("Who descends into the abyss?", "Give your explorer a name.")
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(1, 0, 0, 56)
		box.BackgroundColor3 = Color3.fromRGB(14, 11, 10)
		box.BorderSizePixel = 0
		box.FontFace = UiKit.Display
		box.TextSize = 32
		box.TextColor3 = C.Gold
		box.PlaceholderText = "your name"
		box.PlaceholderColor3 = C.Dim
		box.ClearTextOnFocus = false
		box.Text = config.Name
		box.ZIndex = 33
		box.Parent = body
		UiKit.Stroke(box, C.Line, 1.5)
		local function nextStep()
			local n = string.sub(box.Text, 1, 20)
			config.Name = if n:match("%S") then n else Players.LocalPlayer.DisplayName
			go(2)
		end
		box.FocusLost:Connect(function(enter)
			if enter then
				nextStep()
			end
		end)
		navButton("Back", 120, onCancel)
		navButton("Continue", 180, nextStep)
		navButton("Random hero", 170, function()
			config.Name = box.Text ~= "" and box.Text or config.Name
			config.Flaws = {}
			config.Boons = {}
			local flaws = table.clone(Boons.Flaws)
			for _ = 1, math.random(0, 1) do
				local f = table.remove(flaws, math.random(1, #flaws))
				table.insert(config.Flaws, f.Id)
			end
			local boons = table.clone(Boons.Boons)
			for _ = 1, Boons.FreeBoons + #config.Flaws do
				local b = table.remove(boons, math.random(1, #boons))
				table.insert(config.Boons, b.Id)
			end
			local starters = {}
			for _, s in Spells.List do
				if s.Starter then
					table.insert(starters, s.Id)
				end
			end
			config.Spell = pick(starters)
			go(5)
		end)
	end

	steps[2] = function()
		say("Every soul carries a burden down with it. Which are yours?", "Optional: take up to 2 flaws. Each flaw lets you choose one more boon.")
		traitGrid(Boons.Flaws, config.Flaws, function()
			return Boons.MaxFlaws
		end, function()
			-- Dropping flaws may leave too many boons chosen.
			while #config.Boons > Boons.FreeBoons + #config.Flaws do
				table.remove(config.Boons)
			end
		end, Color3.fromRGB(190, 70, 60))
		navButton("Back", 120, function()
			go(1)
		end)
		navButton("Continue", 180, function()
			go(3)
		end)
	end

	local boonCount: TextLabel? = nil
	steps[3] = function()
		local allowed = Boons.FreeBoons + #config.Flaws
		say("And what gifts did you bring?", string.format("Choose %d boons.", allowed))
		traitGrid(Boons.Boons, config.Boons, function()
			return Boons.FreeBoons + #config.Flaws
		end, function()
			if boonCount then
				boonCount.Text = string.format("%d of %d chosen", #config.Boons, Boons.FreeBoons + #config.Flaws)
			end
		end, C.Gold)
		navButton("Back", 120, function()
			go(2)
		end)
		navButton("Continue", 180, function()
			go(4)
		end)
		boonCount = UiKit.Text(nav, { Size = UDim2.fromOffset(160, 42), TextSize = 16, TextColor3 = C.Dim, Text = string.format("%d of %d chosen", #config.Boons, allowed), LayoutOrder = 99, ZIndex = 33 })
	end

	steps[4] = function()
		say("Which words of power do you still remember?", "Choose your first spell. You will find spellbooks with more in the dungeon.")
		local list = UiKit.Frame(body, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 32 })
		UiKit.List(list, 8)
		local cards = {}
		for i, s in Spells.List do
			if s.Starter then
				local card = Instance.new("TextButton")
				card.Text = ""
				card.AutoButtonColor = false
				card.BackgroundColor3 = Color3.new(1, 1, 1)
				card.Size = UDim2.new(1, 0, 0, 70)
				card.LayoutOrder = i
				card.ZIndex = 33
				card.Parent = list
				local grad = UiKit.Gradient(card, Color3.fromRGB(34, 28, 24), Color3.fromRGB(12, 10, 10), 90)
				local stroke = UiKit.Stroke(card, C.LineDim, 1.2)
				local icon = UiKit.Frame(card, { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 13), Size = UDim2.fromOffset(44, 44), ZIndex = 34 })
				UiKit.Glyph(icon, s.Glyph, s.Color, 2.5)
				UiKit.Text(card, { Position = UDim2.fromOffset(70, 6), Size = UDim2.new(1, -80, 0, 24), FontFace = UiKit.Display, TextSize = 22, TextColor3 = C.Parchment, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s   ·   %d mana", s.Name, s.Mana), ZIndex = 34 })
				UiKit.Text(card, { Position = UDim2.fromOffset(70, 30), Size = UDim2.new(1, -80, 0, 36), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = s.Description, ZIndex = 34 })
				local function paint()
					local on = config.Spell == s.Id
					stroke.Color = if on then s.Color else C.LineDim
					stroke.Thickness = if on then 2 else 1.2
					grad.Color = if on then ColorSequence.new(s.Color:Lerp(Color3.new(0, 0, 0), 0.65), Color3.fromRGB(14, 11, 10)) else ColorSequence.new(Color3.fromRGB(34, 28, 24), Color3.fromRGB(12, 10, 10))
				end
				cards[s.Id] = paint
				paint()
				card.Activated:Connect(function()
					config.Spell = s.Id
					Audio.Play("Magic", nil, 0.3, 1, 1.5)
					for _, p in cards do
						p()
					end
				end)
			end
		end
		navButton("Back", 120, function()
			go(3)
		end)
		navButton("Continue", 180, function()
			go(5)
		end)
	end

	steps[5] = function()
		say("Then go, " .. config.Name .. ". The abyss is waiting.", "")
		local lines = {}
		local function names(ids: { string }, byId): string
			local out = {}
			for _, id in ids do
				table.insert(out, byId[id] and byId[id].Name or id)
			end
			return if #out > 0 then table.concat(out, ", ") else "none"
		end
		table.insert(lines, "Boons:  " .. names(config.Boons, Boons.BoonById))
		table.insert(lines, "Flaws:  " .. names(config.Flaws, Boons.FlawById))
		table.insert(lines, "Spell:  " .. (Spells.ById[config.Spell] and Spells.ById[config.Spell].Name or "?"))
		table.insert(lines, "Gear:   quarterstaff, leather armor, a lantern, a potion and food")
		UiKit.Text(body, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LineHeight = 1.4,
			Text = table.concat(lines, "\n"),
			ZIndex = 33,
		})
		navButton("Back", 120, function()
			go(4)
		end)
		local descend = navButton("Descend", 220, function()
			root:Destroy()
			Audio.Play("Toll", nil, 0.5, 0.8, 4)
			onDone(config)
		end)
		descend.TextColor3 = C.Gold
	end

	go(1)
	local _ = stepIndex
	return root
end

function Sanctum.Start()
	RunService:BindToRenderStep("RogueAbyssSanctumCamera", Enum.RenderPriority.Camera.Value + 2, function()
		if cameraMode == "Off" then
			return
		end
		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		local t = os.clock() - cameraStart
		if cameraMode == "Menu" then
			-- A slow drift around the dais.
			local a = math.rad(-25) + math.sin(t * 0.07) * 0.35
			local pos = ORIGIN + Vector3.new(math.sin(a) * 30, 9 + math.sin(t * 0.13) * 1.2, math.cos(a) * 30)
			camera.CFrame = CFrame.lookAt(pos, ORIGIN + Vector3.new(0, 5, -4))
			camera.FieldOfView = 55
		else
			-- Frame the figure on the left third, pushing in slowly.
			local push = math.clamp(t / 6, 0, 1)
			local pos = ORIGIN + Vector3.new(4.5, 5.2, 15 - push * 3)
			camera.CFrame = CFrame.lookAt(pos, ORIGIN + Vector3.new(1.2, 3.8, 0))
			camera.FieldOfView = 50
		end
	end)
end

return Sanctum
