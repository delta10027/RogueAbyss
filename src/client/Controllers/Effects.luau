--!strict
-- Local presentation of server events. Restrained VFX as punctuation
-- (ART_BIBLE §17). Noise is drawn as a faint ring on the floor so the player
-- can see how far a sound carries - and notice when a rule changes that.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Items = require(ReplicatedStorage:WaitForChild("Shared").Definitions.Items)

local Audio = require(script.Parent.Audio)

local Effects = {}

local deps: any
local folder: Folder

local RING_COLORS = {
	Step = Color3.fromRGB(170, 160, 140),
	Splash = Color3.fromRGB(140, 160, 170),
	Bell = Color3.fromRGB(200, 180, 120),
	Machine = Color3.fromRGB(170, 140, 110),
}

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

-- A thin expanding ring (cylinder rim made of a disc whose centre fades).
local function ring(pos: Vector3, radius: number, color: Color3, strength: number)
	local disc = localPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 1, 1),
		CFrame = CFrame.new(pos.X, pos.Y + 0.12, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 1 - 0.18 * strength,
	})
	local t = math.clamp(radius / 40, 0.45, 1.2)
	TweenService:Create(disc, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	task.delay(t + 0.1, function()
		disc:Destroy()
	end)
end

local function puff(pos: Vector3, color: Color3, count: number, size: number)
	local p = localPart({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(pos), Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 2.5) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(1, 4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = p
	e:Emit(count)
	task.delay(2, function()
		p:Destroy()
	end)
end

local function throwArc(from: Vector3, to: Vector3, itemId: string, duration: number)
	local def = Items[itemId]
	local ball = localPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.9, 0.9),
		Color = if def then def.Color else Color3.new(1, 1, 1),
		Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(from),
	})
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		local p = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * 5, 0)
		ball.CFrame = CFrame.new(p)
		if t >= 1 then
			conn:Disconnect()
			ball:Destroy()
		end
	end)
end

local function tollDust()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local p = localPart({
		Size = Vector3.new(60, 1, 60),
		CFrame = CFrame.new(root.Position + Vector3.new(0, 16, 0)),
		Transparency = 1,
	})
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(150, 140, 120))
	e.Size = NumberSequence.new(0.35)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(4, 8)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Rate = 0
	e.Parent = p
	e:Emit(70)
	task.delay(3, function()
		p:Destroy()
	end)
end

local function myRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The whoosh of a swing (the weapon trail and arm animation do the rest).
function Effects.LocalSwing(heavy: boolean?)
	local root = myRoot()
	if not root then
		return
	end
	Audio.Play(if heavy then "SwingHeavy" else "Swing", root.Position, if heavy then 0.6 else 0.4, if heavy then 0.8 else 1, 1)
	if heavy then
		deps.Camera.Shake(0.15, 0.15)
	end
end

-- Dust kicked up by a dash.
function Effects.LocalDash()
	local root = myRoot()
	if root then
		puff(root.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(140, 130, 116), 8, 0.6)
		Audio.Play("Swing", root.Position, 0.3, 0.7, 0.6)
	end
end

-- A glow in the weapon hand while a heavy attack charges.
function Effects.ChargeGlow()
	local character = Players.LocalPlayer.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if not hand then
		return
	end
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 210, 140)
	l.Range = 6
	l.Brightness = 0
	l.Parent = hand
	TweenService:Create(l, TweenInfo.new(0.4), { Brightness = 2 }):Play()
	Audio.Play("Magic", hand.Position, 0.25, 0.6, 1)
	task.delay(1.2, function()
		l:Destroy()
	end)
end

local function beam(from: Vector3, to: Vector3, color: Color3, width: number, life: number)
	local len = (to - from).Magnitude
	local p = localPart({
		Size = Vector3.new(width, width, len),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})
	TweenService:Create(p, TweenInfo.new(life), { Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, len) }):Play()
	task.delay(life + 0.05, function()
		p:Destroy()
	end)
end

-- A jagged lightning bolt between points.
local function lightning(points: { Vector3 })
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local prev = a
		for s = 1, 5 do
			local t = s / 5
			local p = a:Lerp(b, t)
			if s < 5 then
				p += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.2
			end
			beam(prev, p, Color3.fromRGB(200, 220, 255), 0.25, 0.25)
			prev = p
		end
	end
end

local function sphereBurst(pos: Vector3, radius: number, color: Color3, time: number, material: Enum.Material?)
	local s = localPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(pos),
		Color = color,
		Material = material or Enum.Material.Neon,
		Transparency = 0.3,
	})
	TweenService:Create(s, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	task.delay(time + 0.05, function()
		s:Destroy()
	end)
end

local function flashLight(pos: Vector3, color: Color3, range: number, time: number)
	local p = localPart({ Size = Vector3.one, CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)), Transparency = 1 })
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 4
	l.Parent = p
	TweenService:Create(l, TweenInfo.new(time), { Brightness = 0 }):Play()
	task.delay(time + 0.05, function()
		p:Destroy()
	end)
end

local projectiles: { [number]: BasePart } = {}

local handlers: { [string]: (any) -> () } = {}

handlers.Noise = function(e)
	local strength = if e.Source == "Step" then 0.45 elseif e.Source == "Splash" then 0.6 else 1
	ring(e.Pos, e.Radius, RING_COLORS[e.Source] or Color3.fromRGB(190, 170, 140), strength)
end
handlers.Throw = function(e)
	throwArc(e.From, e.To, e.Item, e.Time)
end
handlers.Shatter = function(e)
	Audio.Play("Shatter", e.Pos, 0.7, 1, 3)
	puff(e.Pos, Color3.fromRGB(150, 110, 60), 12, 0.8)
end
handlers.Bell = function(e)
	Audio.Play("Bell", e.Pos, 0.7, 1.1, 1.6)
end
handlers.Toll = function(_e)
	Audio.Play("Toll", nil, 0.8, 0.85, 6)
	tollDust()
end
handlers.TollWarn = function(_e)
	Audio.Play("Grind", nil, 0.25, 0.5, 2.5)
end
handlers.Grind = function(e)
	Audio.Play("Grind", e.Pos, 0.5, 0.7, 1.1)
	puff(e.Pos, Color3.fromRGB(110, 104, 96), 3, 0.6)
end
handlers.Clang = function(e)
	Audio.Play("Rubble", e.Pos, 0.6, 1.4, 1.2)
end
handlers.Telegraph = function(e)
	Audio.Play(if e.Creature == "Listener" then "Hiss" else "Growl", e.Pos, 0.5, if e.Creature == "Listener" then 0.55 else 1.2, 1.2)
	deps.Feedback.Telegraph(e)
end
handlers.Hit = function(e)
	deps.Feedback.Hit(e)
end
handlers.Blocked = function(e)
	deps.Feedback.Hit({ Pos = e.Pos, Model = e.Model, Blocked = true })
end
handlers.StrikeMiss = function(_e) end
handlers.Winded = function(_e)
	deps.Hud.FlashBar("Stamina")
	local root = myRoot()
	if root then
		Audio.Play("Hiss", root.Position, 0.25, 1.6, 0.6)
	end
end
handlers.Dodged = function(_e)
	local root = myRoot()
	if root then
		deps.Feedback.Number(root.Position, "dodged", Color3.fromRGB(200, 220, 255))
	end
end
handlers.ShieldHit = function(e)
	local root = myRoot()
	if root then
		sphereBurst(root.Position, 4, Color3.fromRGB(210, 200, 170), 0.3, Enum.Material.ForceField)
		Audio.Play("Clang", root.Position, 0.4, 0.8, 0.8)
		if e.Broken then
			deps.Hud.Message("Your stoneskin crumbles.")
		end
	end
end
handlers.Heal = function(_e)
	local root = myRoot()
	if root then
		deps.Feedback.Burst(root.Position, Color3.fromRGB(140, 230, 140), 18, 6, 0.35)
		Audio.Play("Shimmer", nil, 0.25, 1.2, 1.5)
	end
end
handlers.Cast = function(e)
	local root = myRoot()
	local Spells = require(game:GetService("ReplicatedStorage").Shared.Definitions.Spells)
	local def = Spells.ById[e.Spell]
	if root and def then
		deps.Feedback.Burst(root.Position + Vector3.new(0, 1, 0), def.Color, 12, 8, 0.3)
		Audio.Play("Magic", root.Position, 0.35, 1, 1.2)
	end
end
handlers.NoMana = function(_e)
	deps.Hud.FlashBar("Mana")
end
handlers.Learn = function(_e)
	local root = myRoot()
	if root then
		sphereBurst(root.Position, 6, Color3.fromRGB(180, 150, 255), 0.6)
		Audio.Play("Shimmer", nil, 0.5, 1, 3)
	end
end
handlers.Enchant = function(_e)
	local root = myRoot()
	if root then
		deps.Feedback.Burst(root.Position + Vector3.new(0, 1, 0), Color3.fromRGB(140, 180, 255), 30, 10, 0.4)
		Audio.Play("Shimmer", nil, 0.5, 1.3, 2.5)
	end
end
handlers.Perk = function(_e)
	local root = myRoot()
	if root then
		ring(root.Position - Vector3.new(0, 2.5, 0), 12, Color3.fromRGB(230, 200, 130), 3)
	end
end
handlers.Fireball = function(e)
	local ball = localPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(e.From), Color = Color3.fromRGB(255, 140, 50), Material = Enum.Material.Neon })
	local f = Instance.new("Fire")
	f.Size = 4
	f.Heat = 0
	f.Parent = ball
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 150, 70)
	l.Range = 16
	l.Brightness = 2.5
	l.Parent = ball
	Audio.Play("FireWhoosh", e.From, 0.6, 1, 1.2)
	TweenService:Create(ball, TweenInfo.new(e.Time or 0.3, Enum.EasingStyle.Linear), { CFrame = CFrame.new(e.To + Vector3.new(0, 1.5, 0)) }):Play()
	task.delay(e.Time or 0.3, function()
		ball:Destroy()
	end)
end
handlers.Explosion = function(e)
	local pos: Vector3 = e.Pos
	local color = if e.Fire then Color3.fromRGB(255, 140, 50) else Color3.fromRGB(200, 200, 255)
	sphereBurst(pos + Vector3.new(0, 1, 0), e.Radius or 6, color, 0.45)
	puff(pos + Vector3.new(0, 1, 0), Color3.fromRGB(60, 50, 44), if e.Big then 30 else 16, if e.Big then 2.5 else 1.6)
	deps.Feedback.Burst(pos + Vector3.new(0, 1, 0), Color3.fromRGB(255, 190, 110), 30, 30, 0.45)
	flashLight(pos, color, (e.Radius or 6) * 3, 0.6)
	ring(pos, (e.Radius or 6) * 1.2, color, 3)
	Audio.Play("Explosion", pos, if e.Big then 1 else 0.7, if e.Big then 0.8 else 1, 3)
	local root = myRoot()
	local d = if root then (root.Position - pos).Magnitude else 99
	deps.Camera.Shake(if e.Big then 1.4 else 0.7, if e.Big then 0.5 else 0.3)
	local _ = d
end
handlers.FrostNova = function(e)
	sphereBurst(e.Pos, e.Radius, Color3.fromRGB(170, 220, 255), 0.5, Enum.Material.Ice)
	ring(e.Pos - Vector3.new(0, 2.5, 0), e.Radius, Color3.fromRGB(170, 220, 255), 3)
	deps.Feedback.Burst(e.Pos, Color3.fromRGB(220, 240, 255), 40, 25, 0.4)
	Audio.Play("Glass", e.Pos, 0.6, 1.4, 2)
	deps.Camera.Shake(0.3, 0.2)
end
handlers.Lightning = function(e)
	lightning(e.Points)
	for _, p in e.Points do
		flashLight(p, Color3.fromRGB(200, 220, 255), 14, 0.3)
	end
	Audio.Play("Thunder", e.Points[#e.Points], 0.5, 1.4, 1.5)
end
handlers.Bolt = function(e)
	lightning({ e.Pos + Vector3.new(0, 30, 0), e.Pos })
	flashLight(e.Pos, Color3.fromRGB(200, 220, 255), 22, 0.4)
	deps.Feedback.Burst(e.Pos, Color3.fromRGB(220, 230, 255), 20, 20, 0.35)
	Audio.Play("Thunder", e.Pos, 0.6, 1.2, 1.5)
	deps.Camera.Shake(0.4, 0.2)
end
handlers.Drain = function(e)
	for i = 0, 6 do
		task.delay(i * 0.05, function()
			local a = (e.From :: Vector3):Lerp(e.To, i / 6) + Vector3.new(0, 2, 0)
			deps.Feedback.Burst(a, Color3.fromRGB(200, 50, 90), 4, 3, 0.4)
		end)
	end
	beam(e.From + Vector3.new(0, 2, 0), e.To + Vector3.new(0, 2, 0), Color3.fromRGB(180, 40, 80), 0.35, 0.4)
	Audio.Play("Whisper", e.To, 0.3, 1.4, 1.5)
end
handlers.Stoneskin = function(_e)
	local root = myRoot()
	if root then
		sphereBurst(root.Position, 5, Color3.fromRGB(210, 200, 170), 0.6, Enum.Material.ForceField)
		Audio.Play("Rubble", root.Position, 0.5, 0.8, 1.5)
	end
end
handlers.Haste = function(e)
	local character = Players.LocalPlayer.Character
	local root = myRoot()
	if not character or not root then
		return
	end
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140))
	em.LightEmission = 1
	em.Size = NumberSequence.new(0.25)
	em.Lifetime = NumberRange.new(0.3, 0.5)
	em.Rate = 30
	em.Speed = NumberRange.new(0.5, 1)
	em.Parent = root
	Audio.Play("Shimmer", nil, 0.35, 1.6, 1.5)
	task.delay(e.Seconds or 8, function()
		em:Destroy()
	end)
end
handlers.Scare = function(e)
	ring(e.Pos - Vector3.new(0, 2.5, 0), e.Radius, Color3.fromRGB(160, 110, 200), 3)
	Audio.Play("Whisper", e.Pos, 0.7, 0.6, 3)
end
handlers.Hold = function(e)
	beam(e.From + Vector3.new(0, 2, 0), e.Pos + Vector3.new(0, 2, 0), Color3.fromRGB(140, 220, 160), 0.3, 0.5)
	Audio.Play("Magic", e.Pos, 0.4, 0.7, 1.5)
end
handlers.LightSpell = function(e)
	deps.Feedback.Burst(e.Pos + Vector3.new(0, 6, 0), Color3.fromRGB(255, 230, 170), 20, 8, 0.4)
	Audio.Play("Shimmer", e.Pos, 0.4, 1.5, 2)
end
handlers.MeteorWarn = function(e)
	local ring2 = localPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, e.Radius * 2, e.Radius * 2),
		CFrame = CFrame.new(e.Pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 100, 40),
		Material = Enum.Material.Neon,
		Transparency = 0.7,
	})
	local rock = localPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(e.Pos + Vector3.new(14, 60, 10)), Color = Color3.fromRGB(80, 40, 20), Material = Enum.Material.Basalt })
	local f = Instance.new("Fire")
	f.Size = 8
	f.Parent = rock
	TweenService:Create(rock, TweenInfo.new(e.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(e.Pos) }):Play()
	task.delay(e.Time, function()
		rock:Destroy()
		ring2:Destroy()
	end)
end
handlers.Projectile = function(e)
	local p = localPart({
		Size = Vector3.new(0.25, 0.25, 3),
		CFrame = CFrame.lookAt(e.From, e.From + e.Dir),
		Color = Color3.fromRGB(120, 96, 70),
		Material = Enum.Material.Wood,
	})
	projectiles[e.Id] = p
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if not p.Parent or t > (e.Life or 1.5) then
			conn:Disconnect()
			p:Destroy()
			projectiles[e.Id] = nil
			return
		end
		local pos = e.From + e.Dir * e.Speed * t
		p.CFrame = CFrame.lookAt(pos, pos + e.Dir)
	end)
	Audio.Play("Swing", e.From, 0.4, 1.3, 0.5)
end
handlers.ProjectileEnd = function(e)
	local p = projectiles[e.Id]
	if p then
		p:Destroy()
		projectiles[e.Id] = nil
	end
	puff(e.Pos, Color3.fromRGB(120, 110, 100), 4, 0.4)
end
handlers.Slam = function(e)
	ring(e.Pos - Vector3.new(0, 2, 0), e.Radius, Color3.fromRGB(190, 160, 120), 3)
	puff(e.Pos - Vector3.new(0, 2, 0), Color3.fromRGB(120, 110, 96), 18, 1.2)
	Audio.Play("Rubble", e.Pos, 0.8, 0.7, 1.5)
	deps.Camera.Shake(0.6, 0.3)
end
handlers.Roar = function(e)
	Audio.Play("Growl", e.Pos, 0.9, 0.7, 2)
	deps.Camera.Shake(0.25, 0.4)
end
handlers.BreakHit = function(e)
	Audio.Play(if e.Material == "Pot" then "Pot" else "Crate", e.Pos, 0.4, 1.4, 0.6)
	deps.Feedback.Burst(e.Pos, Color3.fromRGB(200, 170, 120), 6, 10, 0.3)
end
handlers.Break = function(e)
	Audio.Play(if e.Material == "Pot" then "Pot" else "Crate", e.Pos, 0.7, 1, 2)
	puff(e.Pos, Color3.fromRGB(130, 116, 96), 10, 0.9)
	deps.Camera.Shake(0.2, 0.12)
end
handlers.WallBreak = function(e)
	Audio.Play("Rubble", e.Pos, 1, 0.7, 2.5)
	puff(e.Pos + Vector3.new(0, 3, 0), Color3.fromRGB(120, 112, 100), 40, 2)
	deps.Camera.Shake(0.9, 0.4)
	-- Chunks of the wall tumble out.
	for _ = 1, 10 do
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.new(math.random() * 1.2 + 0.4, math.random() * 1 + 0.4, math.random() * 1.2 + 0.4)
		chunk.CFrame = CFrame.new(e.Pos + Vector3.new(math.random() * 4 - 2, 2 + math.random() * 5, math.random() * 4 - 2))
		chunk.Color = Color3.fromRGB(96, 90, 82)
		chunk.Material = Enum.Material.Slate
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.CollisionGroup = "Debris"
		local away = (e.Pos - (e.From or e.Pos))
		local dir = if away.Magnitude > 0.1 then Vector3.new(away.X, 0, away.Z).Unit else Vector3.xAxis
		chunk.AssemblyLinearVelocity = dir * (10 + math.random() * 15) + Vector3.new(0, 8, 0)
		chunk.Parent = folder
		task.delay(3, function()
			chunk:Destroy()
		end)
	end
end
handlers.Special = function(_e) end
handlers.SpecialFx = function(e)
	local id = e.Id
	if id == "Sweep" or id == "Whirlwind" or id == "SoulHarvest" then
		local color = if id == "SoulHarvest" then Color3.fromRGB(160, 60, 200) else Color3.fromRGB(230, 220, 200)
		ring(e.Pos - Vector3.new(0, 2.5, 0), e.Radius, color, 3)
		puff(e.Pos - Vector3.new(0, 2.5, 0), Color3.fromRGB(140, 130, 116), 14, 0.8)
		Audio.Play("SwingHeavy", e.Pos, 0.7, 0.8, 1)
		if id == "Whirlwind" then
			for i = 1, 2 do
				task.delay(i * 0.28, function()
					ring(e.Pos - Vector3.new(0, 2.5, 0), e.Radius, color, 2)
					Audio.Play("Swing", e.Pos, 0.5, 1, 0.6)
				end)
			end
		end
	elseif id == "GroundSlam" then
		ring(e.Pos - Vector3.new(0, 2.5, 0), e.Radius, Color3.fromRGB(220, 190, 140), 4)
		puff(e.Pos - Vector3.new(0, 2.5, 0), Color3.fromRGB(130, 116, 96), 30, 1.6)
		Audio.Play("Rubble", e.Pos, 1, 0.6, 2)
		deps.Camera.Shake(1, 0.4)
	elseif id == "Lunge" then
		beam(e.From, e.To, Color3.fromRGB(230, 220, 200), 0.6, 0.3)
		Audio.Play("SwingHeavy", e.From, 0.7, 1.2, 1)
	elseif id == "Cleave" or id == "Rend" then
		Audio.Play("SwingHeavy", e.Pos, 0.9, 0.7, 1)
		task.delay(0.25, function()
			puff(e.Pos + (e.Dir or Vector3.zero) * 6 - Vector3.new(0, 2, 0), Color3.fromRGB(140, 120, 100), 20, 1.2)
			deps.Camera.Shake(0.8, 0.3)
		end)
	elseif id == "FireSpray" then
		local dir = e.Dir or Vector3.zAxis
		for i = 1, 8 do
			task.delay(i * 0.03, function()
				local spread = CFrame.Angles(0, math.rad(math.random(-28, 28)), 0):VectorToWorldSpace(dir)
				deps.Feedback.Burst(e.Pos + spread * (2 + i * 1.5), Color3.fromRGB(255, 140, 50), 6, 6, 0.6, "rbxasset://textures/particles/fire_main.dds")
			end)
		end
		Audio.Play("FireWhoosh", e.Pos, 0.7, 0.8, 1.2)
	elseif id == "IceShard" then
		beam(e.From, e.To, Color3.fromRGB(170, 220, 255), 0.4, 0.35)
		deps.Feedback.Burst(e.To, Color3.fromRGB(220, 240, 255), 16, 14, 0.35)
		Audio.Play("Glass", e.To, 0.5, 1.6, 1)
	end
end
handlers.Clank = function(e)
	Audio.Play("Clank", e.Pos, 0.6, 0.7, 2)
end
handlers.Lever = function(e)
	Audio.Play("Clank", e.Pos, 0.7, 0.5, 2)
end
handlers.Door = function(e)
	Audio.Play("Door", e.Pos, 0.6, 0.9, 2.5)
end
handlers.Vault = function(e)
	Audio.Play("Grind", e.Pos, 0.6, 0.6, 2)
end
handlers.WallHit = function(e)
	Audio.Play("Rubble", e.Pos, 0.7, 1, 1.5)
	puff(e.Pos + Vector3.new(0, 3, 0), Color3.fromRGB(120, 112, 100), 6 * e.Hits, 0.7)
	deps.Feedback.Burst(e.Pos + Vector3.new(0, 3, 0), Color3.fromRGB(200, 180, 150), 10, 18, 0.3)
	deps.Camera.Shake(0.35, 0.15)
	deps.Animator.HitStop(0.05)
	if e.Hits < (e.Max or 3) then
		deps.Hud.Message(string.format("The wall cracks... (%d/%d)", e.Hits, e.Max or 3))
	end
end
handlers.Kindle = function(e)
	puff(e.Pos + Vector3.new(0, 3.5, 0), Color3.fromRGB(180, 120, 70), 6, 0.5)
end
handlers.Hurt = function(e)
	deps.Hud.Hurt(e.Heavy)
	deps.Camera.Shake(if e.Heavy then 0.8 else 0.4, 0.25)
	local root = myRoot()
	if root and e.Amount and e.Amount > 0 then
		deps.Feedback.Number(root.Position, "-" .. e.Amount, Color3.fromRGB(255, 90, 80))
		Audio.Play("HitFlesh", root.Position, 0.5, 0.8, 1)
	end
end
handlers.Descend = function(_e)
	deps.Hud.FadeTo(1, 0.8)
end
handlers.Collapse = function(_e)
	deps.Hud.FadeTo(0.7, 1.2)
end
handlers.Missile = function(e)
	local bolt = localPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.9, 0.9),
		Color = Color3.fromRGB(170, 190, 255),
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(e.From),
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 170, 255)
	light.Range = 10
	light.Brightness = 2
	light.Parent = bolt
	local t = math.clamp((e.To - e.From).Magnitude / 90, 0.08, 0.45)
	TweenService:Create(bolt, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = CFrame.new(e.To) }):Play()
	Audio.Play("Swing", e.From, 0.4, 1.6, 1)
	task.delay(t, function()
		puff(e.To, Color3.fromRGB(150, 160, 210), 8, 0.5)
		bolt:Destroy()
	end)
end
handlers.SlowWave = function(e)
	ring(e.Pos, e.Radius, Color3.fromRGB(120, 150, 210), 2.5)
	Audio.Play("Hiss", e.Pos, 0.4, 0.4, 1.5)
end
handlers.Blink = function(e)
	puff(e.From + Vector3.new(0, 2, 0), Color3.fromRGB(150, 160, 210), 12, 0.6)
	puff(e.To + Vector3.new(0, 2, 0), Color3.fromRGB(150, 160, 210), 12, 0.6)
	Audio.Play("Swing", e.To, 0.5, 0.6, 1)
end
handlers.Teleport = function(_e)
	deps.Hud.FadeTo(0.8, 0.05)
	task.delay(0.15, function()
		deps.Hud.FadeTo(0, 0.6)
	end)
end
handlers.LevelUp = function(_e)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		ring(root.Position - Vector3.new(0, 2.5, 0), 14, Color3.fromRGB(230, 200, 130), 3)
		puff(root.Position, Color3.fromRGB(230, 200, 140), 14, 0.5)
	end
	Audio.Play("Bell", nil, 0.5, 1.5, 2)
end
handlers.Chest = function(e)
	Audio.Play("Door", e.Pos, 0.6, 1.3, 1.5)
	puff(e.Pos + Vector3.new(0, 2, 0), Color3.fromRGB(150, 130, 100), 8, 0.5)
end
handlers.Gold = function(_e)
	Audio.Play("Bell", nil, 0.25, 2.2, 0.6)
end
handlers.Pickup = function(_e)
	Audio.Play("Clank", nil, 0.2, 1.8, 0.5)
end
handlers.Equip = function(_e)
	Audio.Play("Clank", nil, 0.3, 1.2, 0.6)
end
handlers.Kill = function(e)
	puff(e.Pos, Color3.fromRGB(120, 112, 100), 10, 0.8)
end
handlers.Alert = function(e)
	Audio.Play("Hiss", e.Pos, 0.35, 1.3, 0.8)
end

-- Scroll of Magic Mapping: an arrow on the ground beside you that points
-- to the stairs down for a while.
handlers.Reveal = function(e)
	local function bar(): Part
		return localPart({
			Size = Vector3.new(0.5, 0.1, 2.4),
			Color = Color3.fromRGB(230, 200, 130),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
		})
	end
	local arrow, tipL, tipR = bar(), bar(), bar()
	local parts = { arrow, tipL, tipR }
	local untilT = os.clock() + (e.Seconds or 45)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if os.clock() > untilT or not root then
			conn:Disconnect()
			for _, p in parts do
				p:Destroy()
			end
			return
		end
		local to = Vector3.new(e.Pos.X - root.Position.X, 0, e.Pos.Z - root.Position.Z)
		local hidden = to.Magnitude < 8
		for _, p in parts do
			p.Transparency = if hidden then 1 else 0.3
		end
		if hidden then
			return
		end
		local base = Vector3.new(root.Position.X, e.Pos.Y + 0.3, root.Position.Z) + to.Unit * 5
		local cf = CFrame.lookAt(base, base + to.Unit)
		arrow.CFrame = cf
		-- Chevron head at the front end.
		tipL.CFrame = cf * CFrame.new(0, 0, -1.2) * CFrame.Angles(0, math.rad(40), 0) * CFrame.new(0, 0, 1)
		tipR.CFrame = cf * CFrame.new(0, 0, -1.2) * CFrame.Angles(0, math.rad(-40), 0) * CFrame.new(0, 0, 1)
	end)
end

function Effects.Start(dependencies)
	deps = dependencies
	folder = Instance.new("Folder")
	folder.Name = "LocalEffects"
	folder.Parent = Workspace -- (lights under the Camera do not illuminate)

	Remotes.Effect.OnClientEvent:Connect(function(e)
		local h = type(e) == "table" and handlers[e.Kind]
		if h then
			local ok, err = pcall(h, e)
			if not ok then
				warn("[Effects] " .. tostring(e.Kind) .. ": " .. tostring(err))
			end
		end
	end)
	Remotes.FloorEntered.OnClientEvent:Connect(function(info)
		Audio.SetFloor(info.RuleId)
	end)

	-- The buried machine's wheel turns while it runs.
	RunService.RenderStepped:Connect(function(dt)
		for _, gear in CollectionService:GetTagged("Spinner") do
			if gear:IsA("Model") and gear:GetAttribute("Running") and gear.PrimaryPart then
				gear:PivotTo(gear:GetPivot() * CFrame.Angles(dt * 0.35, 0, 0))
			end
		end
	end)
end

return Effects
