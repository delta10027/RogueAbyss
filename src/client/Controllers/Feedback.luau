--!strict
-- Combat feedback: everything that makes a hit feel like a hit.
--   * a white flash on the struck monster, sparks/dust, a thud, hit-stop
--     and a small camera kick (bigger for crits, heavies and kills)
--   * restrained damage numbers (crits and backstabs stand out)
--   * health bars over monsters once they are hurt (always for elites)
--   * status visuals: frozen, burning, stunned, held, slowed, feared
--   * warning shapes on the floor while a monster winds up an attack
--   * wraiths fade unless something lights them

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UiKit = require(script.Parent.UiKit)
local Audio = require(script.Parent.Audio)

local C = UiKit.Colors

local Feedback = {}

local deps: any
local folder: Folder

local function localPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = folder
	return p
end
Feedback.LocalPart = localPart

function Feedback.Burst(pos: Vector3, color: Color3, count: number, speed: number, size: number, texture: string?)
	local p = localPart({ Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(pos), Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.7
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.25, 0.5)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -25, 0)
	e.Drag = 3
	e.Rate = 0
	e.Parent = p
	e:Emit(count)
	task.delay(1, function()
		p:Destroy()
	end)
end

-- A white flash over a model.
function Feedback.Flash(model: Instance?, color: Color3?, seconds: number?)
	if not model or not model.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = color or Color3.new(1, 1, 1)
	h.FillTransparency = 0.25
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	TweenService:Create(h, TweenInfo.new(seconds or 0.16), { FillTransparency = 1 }):Play()
	task.delay((seconds or 0.16) + 0.05, function()
		h:Destroy()
	end)
end

-- Floating number above a hit.
function Feedback.Number(pos: Vector3, text: string, color: Color3, big: boolean?)
	local anchor = localPart({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(pos + Vector3.new(math.random() - 0.5, 3.5, math.random() - 0.5)), Transparency = 1 })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 40)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = anchor
	bb.Parent = anchor
	local t = UiKit.Text(bb, {
		Size = UDim2.fromScale(1, 1),
		FontFace = if big then UiKit.DisplayBold else UiKit.BodyBold,
		TextSize = if big then 30 else 20,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		Text = text,
	})
	if big then
		t.TextSize = 40
		TweenService:Create(t, TweenInfo.new(0.18, Enum.EasingStyle.Back), { TextSize = 30 }):Play()
	end
	TweenService:Create(anchor, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = anchor.CFrame + Vector3.new(0, 2.5, 0) }):Play()
	task.delay(0.45, function()
		TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(0.9, function()
		anchor:Destroy()
	end)
end

-- A monster was hit (or blocked, or immune).
function Feedback.Hit(e)
	local pos: Vector3 = e.Pos
	local model = e.Model
	if e.Blocked then
		Feedback.Flash(model, Color3.fromRGB(180, 200, 255), 0.12)
		Feedback.Burst(pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 230, 160), 14, 22, 0.35)
		Feedback.Number(pos, "BLOCKED", Color3.fromRGB(170, 190, 220))
		Audio.Play("Clang", pos, 0.8, 1.1, 1)
		deps.Camera.Shake(0.25, 0.12)
		deps.Animator.HitStop(0.05)
		return
	end
	if e.Immune then
		Feedback.Burst(pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(200, 200, 200), 6, 10, 0.25)
		Audio.Play("Clang", pos, 0.5, 1.4, 0.8)
		if e.Amount == 0 and model and model:GetAttribute("Kind") == "Wraith" then
			Feedback.Number(pos, "no effect", C.Dim)
		end
		return
	end
	local amount = math.floor((e.Amount or 0) + 0.5)
	if amount <= 0 then
		return
	end
	local dot = e.Source == "Dot"
	local heavy = e.Heavy or e.Crit or e.Backstab
	Feedback.Flash(model, if e.Element == "Fire" then Color3.fromRGB(255, 160, 80) elseif e.Element == "Shock" then Color3.fromRGB(190, 210, 255) else nil, if dot then 0.08 else 0.16)
	if not dot then
		local dir = if typeof(e.Dir) == "Vector3" and e.Dir.Magnitude > 0.1 then e.Dir.Unit else Vector3.yAxis
		Feedback.Burst(pos + Vector3.new(0, 1.5, 0) + dir * 0.5, Color3.fromRGB(255, 225, 170), if heavy then 18 else 9, if heavy then 26 else 16, if heavy then 0.45 else 0.3)
		Feedback.Burst(pos + Vector3.new(0, 1, 0), Color3.fromRGB(70, 20, 20), if heavy then 10 else 5, 12, 0.35, "rbxasset://textures/particles/smoke_main.dds")
		Audio.Play(if heavy then "HitHeavy" else "HitFlesh", pos, if heavy then 0.9 else 0.7, if e.Crit then 0.85 else 1, 1.2)
		if e.Source == "Melee" then
			deps.Animator.HitStop(if heavy then 0.09 else 0.045)
		end
		deps.Camera.Shake(if heavy then 0.55 else 0.22, if heavy then 0.2 else 0.1)
	end
	local color = if e.Backstab then Color3.fromRGB(255, 120, 200)
		elseif e.Crit then Color3.fromRGB(255, 200, 80)
		elseif e.Element == "Fire" then Color3.fromRGB(255, 150, 70)
		elseif e.Element == "Shock" then Color3.fromRGB(190, 210, 255)
		elseif dot then Color3.fromRGB(220, 140, 120)
		else Color3.fromRGB(240, 232, 214)
	local text = tostring(amount)
	if e.Backstab then
		text = "BACKSTAB " .. amount
	elseif e.Crit then
		text = amount .. "!"
	end
	Feedback.Number(pos, text, color, e.Crit or e.Backstab)
end

---------------------------------------------------------------------------
-- Telegraphs: a shape on the floor that fills up as the attack winds up.
---------------------------------------------------------------------------

function Feedback.Telegraph(e)
	local radius = e.Radius or 5
	local time = e.Time or 0.6
	local model = e.Model
	local root = model and model.PrimaryPart
	local base = if root then Vector3.new(root.Position.X, root.Position.Y, root.Position.Z) else e.Pos
	local groundY = base.Y - (if root then (root.Size.Y / 2 + 1) else 2)
	local color = Color3.fromRGB(190, 60, 36)
	local parts = {}
	if e.Shape == "Line" or e.Shape == "Throw" then
		local dir: Vector3 = if typeof(e.Dir) == "Vector3" and e.Dir.Magnitude > 0.1 then e.Dir.Unit else Vector3.zAxis
		local len = if e.Shape == "Throw" then 26 else 20
		local p = localPart({
			Size = Vector3.new(radius * 1.2, 0.06, len),
			CFrame = CFrame.lookAt(Vector3.new(base.X, groundY + 0.12, base.Z) + dir * len / 2, Vector3.new(base.X, groundY + 0.12, base.Z) + dir * len),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.8,
		})
		table.insert(parts, p)
		TweenService:Create(p, TweenInfo.new(time), { Transparency = 0.6 }):Play()
	else
		local ring = localPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.06, radius * 2, radius * 2),
			CFrame = CFrame.new(base.X, groundY + 0.1, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.85,
		})
		local fill = localPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.07, 0.4, 0.4),
			CFrame = ring.CFrame,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.75,
		})
		table.insert(parts, ring)
		table.insert(parts, fill)
		TweenService:Create(fill, TweenInfo.new(time, Enum.EasingStyle.Linear), { Size = Vector3.new(0.07, radius * 2, radius * 2), Transparency = 0.6 }):Play()
	end
	Feedback.Flash(model, Color3.fromRGB(255, 120, 60), time)
	task.delay(time + 0.1, function()
		for _, p in parts do
			TweenService:Create(p, TweenInfo.new(0.15), { Transparency = 1 }):Play()
			task.delay(0.2, function()
				p:Destroy()
			end)
		end
	end)
end

---------------------------------------------------------------------------
-- Health bars and status visuals on tagged creatures
---------------------------------------------------------------------------

local STATUS_COLOR = {
	Freeze = Color3.fromRGB(140, 200, 255),
	Burn = Color3.fromRGB(255, 130, 50),
	Bleed = Color3.fromRGB(200, 40, 40),
	Stun = Color3.fromRGB(255, 230, 120),
	Hold = Color3.fromRGB(140, 220, 160),
	Slow = Color3.fromRGB(110, 140, 220),
	Fear = Color3.fromRGB(170, 120, 200),
}

local function attach(model: Model)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local elite = model:GetAttribute("Elite") == true
	local bb = Instance.new("BillboardGui")
	bb.Name = "RA_Bar"
	bb.Size = UDim2.fromOffset(if elite then 130 else 90, 30)
	bb.StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y / 2 + 3.2, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.Adornee = root
	bb.Enabled = elite
	bb.Parent = folder
	local nameLabel = UiKit.Text(bb, {
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 13,
		FontFace = UiKit.BodyBold,
		TextColor3 = if elite then Color3.fromRGB(255, 170, 90) else C.Text,
		TextStrokeTransparency = 0.3,
		Text = "",
	})
	local back = UiKit.Frame(bb, { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(10, 6, 6) })
	UiKit.Stroke(back, Color3.fromRGB(40, 30, 26), 1)
	local ghost = UiKit.Frame(back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(240, 220, 190) })
	local fill = UiKit.Frame(back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = if elite then Color3.fromRGB(220, 110, 50) else Color3.fromRGB(180, 50, 44) })
	local statusLabel = UiKit.Text(bb, {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 10),
		TextSize = 11,
		FontFace = UiKit.BodyBold,
		TextStrokeTransparency = 0.4,
		Text = "",
	})
	local function refresh()
		local hp = (model:GetAttribute("HP") :: number?) or 0
		local max = (model:GetAttribute("MaxHP") :: number?) or 0
		local name = (model:GetAttribute("DisplayName") :: string?) or model.Name
		nameLabel.Text = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
		if max <= 0 then
			back.Visible = false
			return
		end
		local frac = math.clamp(hp / max, 0, 1)
		fill.Size = UDim2.fromScale(frac, 1)
		TweenService:Create(ghost, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(frac, 1) }):Play()
		if hp < max then
			bb.Enabled = true
		end
	end
	refresh()
	model:GetAttributeChangedSignal("HP"):Connect(refresh)

	-- Status visuals.
	local effects: { [string]: Instance } = {}
	local function status()
		local s = (model:GetAttribute("Status") :: string?) or ""
		local active = {}
		for _, k in string.split(s, ",") do
			if k ~= "" then
				active[k] = true
			end
		end
		local first = next(active)
		statusLabel.Text = string.upper(s:gsub(",", " · "))
		statusLabel.TextColor3 = if first then STATUS_COLOR[first] or C.Text else C.Text
		for k, inst in effects do
			if not active[k] then
				inst:Destroy()
				effects[k] = nil
			end
		end
		for k in active do
			if not effects[k] then
				if k == "Freeze" or k == "Hold" then
					local h = Instance.new("Highlight")
					h.FillColor = STATUS_COLOR[k]
					h.FillTransparency = 0.45
					h.OutlineColor = Color3.new(1, 1, 1)
					h.OutlineTransparency = 0.4
					h.DepthMode = Enum.HighlightDepthMode.Occluded
					h.Parent = model
					effects[k] = h
				elseif k == "Burn" then
					local f = Instance.new("Fire")
					f.Size = 4
					f.Heat = 6
					f.Color = Color3.fromRGB(255, 140, 60)
					f.SecondaryColor = Color3.fromRGB(200, 50, 20)
					f.Parent = root
					effects[k] = f
				else
					local e = Instance.new("ParticleEmitter")
					e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					e.Color = ColorSequence.new(STATUS_COLOR[k] or Color3.new(1, 1, 1))
					e.LightEmission = 0.8
					e.Size = NumberSequence.new(0.3)
					e.Lifetime = NumberRange.new(0.4, 0.7)
					e.Rate = if k == "Stun" then 14 else 6
					e.Speed = NumberRange.new(1, 2)
					e.SpreadAngle = Vector2.new(180, 30)
					e.Parent = root
					effects[k] = e
				end
			end
		end
	end
	status()
	model:GetAttributeChangedSignal("Status"):Connect(status)

	-- Exposed (zombie after a slam): glow so the opening is readable.
	local exposedHl: Highlight? = nil
	model:GetAttributeChangedSignal("Exposed"):Connect(function()
		if model:GetAttribute("Exposed") then
			local h = Instance.new("Highlight")
			h.FillColor = Color3.fromRGB(255, 220, 120)
			h.FillTransparency = 0.7
			h.OutlineColor = Color3.fromRGB(255, 220, 120)
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = model
			exposedHl = h
			Feedback.Number(root.Position, "EXPOSED", Color3.fromRGB(255, 220, 120))
		elseif exposedHl then
			exposedHl:Destroy()
			exposedHl = nil
		end
	end)

	-- Wraiths are barely visible outside light.
	if model:GetAttribute("Kind") == "Wraith" then
		local function fade()
			local lit = model:GetAttribute("Lit") == true
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
					d.LocalTransparencyModifier = if lit then 0 else 0.88
				end
			end
		end
		fade()
		model:GetAttributeChangedSignal("Lit"):Connect(fade)
	end

	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			bb:Destroy()
		end
	end)
end

function Feedback.Start(dependencies)
	deps = dependencies
	folder = Instance.new("Folder")
	folder.Name = "Feedback"
	folder.Parent = Workspace -- (lights under the Camera do not illuminate)
	for _, m in CollectionService:GetTagged("RA_Creature") do
		if m:IsA("Model") then
			task.spawn(attach, m)
		end
	end
	CollectionService:GetInstanceAddedSignal("RA_Creature"):Connect(function(m)
		if m:IsA("Model") then
			task.defer(attach, m)
		end
	end)
end

return Feedback
