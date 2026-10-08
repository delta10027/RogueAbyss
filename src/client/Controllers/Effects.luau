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

-- A short pale crescent in front of the explorer: the staff's sweep.
function Effects.LocalSwing()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	Audio.Play("Swing", root.Position, 0.35, 0.8, 1)
	local parts = {}
	for i = -2, 2 do
		local a = math.rad(i * 22)
		local cf = root.CFrame * CFrame.Angles(0, a, 0) * CFrame.new(0, -0.5, -5)
		table.insert(parts, localPart({
			Size = Vector3.new(1.6, 0.08, 0.25),
			CFrame = cf,
			Color = Color3.fromRGB(210, 196, 160),
			Material = Enum.Material.Neon,
			Transparency = 0.55,
		}))
	end
	for _, p in parts do
		TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		task.delay(0.3, function()
			p:Destroy()
		end)
	end
end

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
	Audio.Play("Hiss", e.Pos, 0.8, 0.55, 1.2)
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
	Audio.Play("Rubble", e.Pos, 0.6, 1, 1.5)
	puff(e.Pos + Vector3.new(0, 3, 0), Color3.fromRGB(120, 112, 100), 6 * e.Hits, 0.7)
end
handlers.Kindle = function(e)
	puff(e.Pos + Vector3.new(0, 3.5, 0), Color3.fromRGB(180, 120, 70), 6, 0.5)
end
handlers.Hurt = function(_e)
	deps.Hud.Hurt()
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
	folder.Parent = Workspace.CurrentCamera

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
