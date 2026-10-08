--!strict
-- Per-archetype room dressing. Each dresser receives a context with helpers
-- and writes any interactive handles it creates into `ctx.Built`.
-- Dressing is deterministic per (seed, room id).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)
local FloorRules = require(Shared.Definitions.FloorRules)

local Kit = require(script.Parent.Kit)
local Fixtures = require(script.Parent.Fixtures)

local P = Kit.Palette

local Dressers = {}

export type Ctx = {
	Floor: any,
	Room: any,
	Origin: Vector3,
	Parent: Instance,
	Built: any,
	Rng: Random,
	W: (number, number, number?) -> Vector3, -- floor-space (x, z, y) to world
	ClearOfDoors: (number, number, number) -> boolean,
}

local function pillar(parent: Instance, pos: Vector3, height: number, color: Color3, broken: boolean, seed: number)
	local h = if broken then height * 0.45 else height
	Kit.Part(parent, {
		Name = "PillarBase",
		Size = Vector3.new(3.2, 0.8, 3.2),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)),
		Color = P.DarkStone,
		Material = Enum.Material.Slate,
	})
	local shaft = Kit.Part(parent, {
		Name = "Pillar",
		Size = Vector3.new(2.4, h, 2.4),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.8 + h / 2, 0)),
		Color = Kit.Vary(color, 0.07, seed),
		Material = Enum.Material.Slate,
	})
	CollectionService:AddTag(shaft, "Occluder")
	if broken then
		local r = Random.new(seed)
		for i = 1, 3 do
			Kit.Part(parent, {
				Name = "Rubble",
				Size = Vector3.new(r:NextNumber(0.8, 1.8), r:NextNumber(0.6, 1.2), r:NextNumber(0.8, 1.8)),
				CFrame = CFrame.new(pos + Vector3.new(r:NextNumber(-3, 3), 0.4, r:NextNumber(-3, 3)))
					* CFrame.Angles(0, r:NextNumber(0, 6.28), r:NextNumber(-0.3, 0.3)),
				Color = Kit.Vary(color, 0.1, seed + i),
				Material = Enum.Material.Slate,
				CanCollide = false,
			})
		end
	else
		Kit.Deco(parent, {
			Name = "Capital",
			Size = Vector3.new(3.2, 0.8, 3.2),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.8 + h + 0.4, 0)),
			Color = P.DarkStone,
			Material = Enum.Material.Slate,
		})
	end
end

local function rect(ctx: Ctx)
	local r = ctx.Room.Rect
	return r.X0, r.Z0, r.X1, r.Z1, r.X1 - r.X0, r.Z1 - r.Z0
end

-- Antechamber: symmetrical, a stele carrying the floor's glyph, warm light.
function Dressers.Antechamber(ctx: Ctx)
	local x0, z0, x1, z1, w, d = rect(ctx)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	for _, c in { { x0 + 5, z0 + 5 }, { x1 - 5, z0 + 5 }, { x0 + 5, z1 - 5 }, { x1 - 5, z1 - 5 } } do
		if ctx.ClearOfDoors(c[1], c[2], 4) then
			pillar(ctx.Parent, ctx.W(c[1], c[2]), 8, P.PaleStone, false, math.floor(c[1] * 31 + c[2]))
		end
	end
	Kit.Deco(ctx.Parent, {
		Name = "Rug",
		Size = Vector3.new(w * 0.42, 0.1, d * 0.5),
		CFrame = CFrame.new(ctx.W(cx, cz, 0.05)),
		Color = P.Burgundy,
		Material = Enum.Material.Fabric,
		CastShadow = false,
	})
	-- Stele with the rule glyph, facing south toward the camera.
	local rule = FloorRules[ctx.Floor.RuleId]
	local stelePos = ctx.W(cx, cz - d * 0.18)
	local stele = Kit.Part(ctx.Parent, {
		Name = "Stele",
		Size = Vector3.new(4.4, 6.5, 1.2),
		CFrame = CFrame.new(stelePos + Vector3.new(0, 3.25, 0)),
		Color = P.Charcoal,
		Material = Enum.Material.Basalt,
	})
	Kit.Part(ctx.Parent, {
		Name = "SteleBase",
		Size = Vector3.new(5.4, 0.8, 2.2),
		CFrame = CFrame.new(stelePos + Vector3.new(0, 0.4, 0)),
		Color = P.DarkStone,
		Material = Enum.Material.Slate,
	})
	local face = CFrame.lookAt(stele.Position + Vector3.new(0, 0.6, 0.62), stele.Position + Vector3.new(0, 0.6, 5))
	Fixtures.Glyph(ctx.Parent, face, 3.2, rule.Glyph, P.Parchment, 0.26, false)
	-- The glyph is also carved, large, into the floor so it reads from above.
	Fixtures.FloorGlyph(ctx.Parent, ctx.W(cx, cz + d * 0.08), 5.5, rule.Glyph, Color3.fromRGB(150, 128, 92))
	local prompt = Fixtures.Prompt(stele, "Read", "Stele", ctx.Floor.RuleId, 9)
	ctx.Built.StelePrompt = prompt
	ctx.Built.Spawn = CFrame.lookAt(ctx.W(cx, cz + d * 0.3, 3), ctx.W(cx, cz - d, 3))
end

function Dressers.Stairwell(ctx: Ctx)
	local x0, z0, x1, z1 = rect(ctx)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local size = 10
	local model, anchor = Fixtures.Descent(ctx.Parent, ctx.W(cx, cz), size)
	local prompt = Fixtures.Prompt(anchor, "Descend", "Stair into the dark", nil, 10)
	ctx.Built.Descent = { Prompt = prompt, Pos = ctx.W(cx, cz), Model = model }
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local px, pz = cx + c[1] * (size / 2 + 2.5), cz + c[2] * (size / 2 + 2.5)
		pillar(ctx.Parent, ctx.W(px, pz), 6, P.PaleStone, false, math.floor(px * 7 + pz))
	end
end

function Dressers.Hall(ctx: Ctx)
	local x0, z0, x1, z1, w, d = rect(ctx)
	local alongX = w >= d
	local len = if alongX then w else d
	local count = math.max(2, math.floor((len - 10) / 9))
	local seedBase = RNG.HashString(ctx.Room.Id)
	for row = 1, 2 do
		for i = 1, count do
			local t = (i - 0.5) / count
			local px, pz
			if alongX then
				px = x0 + 5 + t * (w - 10)
				pz = if row == 1 then z0 + d / 3 else z1 - d / 3
			else
				pz = z0 + 5 + t * (d - 10)
				px = if row == 1 then x0 + w / 3 else x1 - w / 3
			end
			if ctx.ClearOfDoors(px, pz, 5) then
				local broken = ctx.Rng:NextNumber() < 0.25
				pillar(ctx.Parent, ctx.W(px, pz), 9, P.AgedStone, broken, seedBase + row * 100 + i)
			end
		end
	end
	-- Worn path down the middle: the route that something walks often.
	Kit.Deco(ctx.Parent, {
		Name = "WornPath",
		Size = if alongX then Vector3.new(w - 6, 0.06, 3) else Vector3.new(3, 0.06, d - 6),
		CFrame = CFrame.new(ctx.W((x0 + x1) / 2, (z0 + z1) / 2, 0.03)),
		Color = Color3.fromRGB(70, 64, 58),
		Material = Enum.Material.Slate,
		CastShadow = false,
	})
end

local function crate(parent: Instance, pos: Vector3, size: number, yaw: number)
	Kit.Part(parent, {
		Name = "Crate",
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(pos + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, yaw, 0),
		Color = Kit.Vary(P.Wood, 0.12, math.floor(pos.X * 13 + pos.Z)),
		Material = Enum.Material.WoodPlanks,
	})
end

local function barrel(parent: Instance, pos: Vector3)
	Kit.Part(parent, {
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3.2, 2.4, 2.4),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = P.DarkBrown,
		Material = Enum.Material.Wood,
	})
end

function Dressers.Storeroom(ctx: Ctx)
	local x0, z0, x1, z1, w, d = rect(ctx)
	local n = math.floor((w + d) / 8)
	for _ = 1, n do
		local side = ctx.Rng:NextInteger(1, 4)
		local px, pz
		if side == 1 then
			px, pz = x0 + 2.5, ctx.Rng:NextNumber(z0 + 3, z1 - 3)
		elseif side == 2 then
			px, pz = x1 - 2.5, ctx.Rng:NextNumber(z0 + 3, z1 - 3)
		elseif side == 3 then
			px, pz = ctx.Rng:NextNumber(x0 + 3, x1 - 3), z0 + 2.5
		else
			px, pz = ctx.Rng:NextNumber(x0 + 3, x1 - 3), z1 - 2.5
		end
		if ctx.ClearOfDoors(px, pz, 6) then
			if ctx.Rng:NextNumber() < 0.6 then
				crate(ctx.Parent, ctx.W(px, pz), ctx.Rng:NextNumber(2.4, 3.6), ctx.Rng:NextNumber(-0.3, 0.3))
			else
				barrel(ctx.Parent, ctx.W(px, pz))
			end
		end
	end
	-- A patched wall section: someone kept repairing this place.
	Kit.Deco(ctx.Parent, {
		Name = "Patch",
		Size = Vector3.new(math.min(10, w - 12), 4, 0.4),
		CFrame = CFrame.new(ctx.W((x0 + x1) / 2, z0 + 0.2, 5)),
		Color = P.Brick,
		Material = Enum.Material.Brick,
	})
end

function Dressers.Gallery(ctx: Ctx)
	local x0, z0, x1, z1 = rect(ctx)
	local spots = {
		{ x0 + 3, (z0 + z1) / 2 }, { x1 - 3, (z0 + z1) / 2 },
		{ (x0 + x1) / 2, z0 + 3 }, { (x0 + x1) / 2, z1 - 3 },
		{ x0 + 3, z0 + 3 }, { x1 - 3, z1 - 3 },
	}
	for i, s in spots do
		if ctx.ClearOfDoors(s[1], s[2], 6) and ctx.Rng:NextNumber() < 0.75 then
			local pos = ctx.W(s[1], s[2])
			Kit.Part(ctx.Parent, {
				Name = "Plinth",
				Size = Vector3.new(2.6, 3, 2.6),
				CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)),
				Color = P.DarkStone,
				Material = Enum.Material.Slate,
			})
			-- Faceless busts: similar enough to a Watcher to make you look twice.
			Kit.Deco(ctx.Parent, {
				Name = "Bust",
				Size = Vector3.new(1.8, 1.6, 1.2),
				CFrame = CFrame.new(pos + Vector3.new(0, 3.8, 0)),
				Color = P.PaleStone,
				Material = Enum.Material.Limestone,
			})
			Kit.Deco(ctx.Parent, {
				Name = "Head",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.4, 1.4, 1.4),
				CFrame = CFrame.new(pos + Vector3.new(0, 5.2, 0)),
				Color = P.PaleStone,
				Material = Enum.Material.Limestone,
			})
			if i <= 2 then
				Fixtures.Candle(ctx.Parent, pos + Vector3.new(0.8, 3, 0.8), i == 1)
			end
		end
	end
end

function Dressers.Overgrown(ctx: Ctx)
	local x0, z0, x1, z1 = rect(ctx)
	for i = 1, 7 do
		local px = ctx.Rng:NextNumber(x0 + 3, x1 - 3)
		local pz = ctx.Rng:NextNumber(z0 + 3, z1 - 3)
		if ctx.ClearOfDoors(px, pz, 5) then
			Kit.Deco(ctx.Parent, {
				Name = "Root",
				Size = Vector3.new(ctx.Rng:NextNumber(6, 12), 0.8, 0.9),
				CFrame = CFrame.new(ctx.W(px, pz, 0.3)) * CFrame.Angles(0, ctx.Rng:NextNumber(0, 6.28), ctx.Rng:NextNumber(-0.1, 0.1)),
				Color = Kit.Vary(P.DarkBrown, 0.15, i),
				Material = Enum.Material.Wood,
			})
		end
	end
	-- Faint fungus glow: the only cold colour in an otherwise warm palette.
	for i = 1, 3 do
		local px = ctx.Rng:NextNumber(x0 + 2, x1 - 2)
		local pz = if i % 2 == 0 then z0 + 1.5 else z1 - 1.5
		local cap = Kit.Deco(ctx.Parent, {
			Name = "Fungus",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 0.5, 1.2),
			CFrame = CFrame.new(ctx.W(px, pz, 0.3)),
			Color = Color3.fromRGB(90, 120, 110),
			Material = Enum.Material.SmoothPlastic,
		})
		Kit.PointLight(cap, Color3.fromRGB(110, 150, 140), 7, 0.5, false)
	end
end

function Dressers.Junction(ctx: Ctx)
	local x0, z0, x1, z1 = rect(ctx)
	local c = ctx.W((x0 + x1) / 2, (z0 + z1) / 2)
	Kit.Deco(ctx.Parent, {
		Name = "Grate",
		Size = Vector3.new(3, 0.1, 3),
		CFrame = CFrame.new(c + Vector3.new(0, 0.05, 0)),
		Color = P.OldIron,
		Material = Enum.Material.DiamondPlate,
		CastShadow = false,
	})
end

function Dressers.Shrine(ctx: Ctx)
	local x0, z0, x1, z1, w, d = rect(ctx)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	-- Basin.
	local basin = Kit.Part(ctx.Parent, {
		Name = "Basin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 4.6, 4.6),
		CFrame = CFrame.new(ctx.W(cx, cz, 1.1)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = P.PaleStone,
		Material = Enum.Material.Limestone,
	})
	local water = Kit.Deco(ctx.Parent, {
		Name = "Water",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 3.8, 3.8),
		CFrame = CFrame.new(ctx.W(cx, cz, 2.15)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 80, 96),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
	})
	local prompt = Fixtures.Prompt(basin, "Drink", "Still water", nil, 8)
	ctx.Built.Shrine = { Prompt = prompt, Water = water, Used = false, RoomId = ctx.Room.Id }
	-- Symmetric candle rows.
	for i = 0, 3 do
		local t = (i + 0.5) / 4
		for _, sx in { -1, 1 } do
			local px = cx + sx * (w / 2 - 3)
			local pz = z0 + 3 + t * (d - 6)
			if ctx.ClearOfDoors(px, pz, 5) then
				Fixtures.Candle(ctx.Parent, ctx.W(px, pz), i % 2 == 0)
			end
		end
	end
	-- Salt lines across every threshold: nothing that hunts will cross.
	for _, connId in ctx.Room.Doors do
		local door = ctx.Built.DoorPositions[ctx.Room.Id .. ":" .. connId]
		if door then
			local along = if door.Axis == "X" then Vector3.new(8.5, 0.08, 0.6) else Vector3.new(0.6, 0.08, 8.5)
			Kit.Deco(ctx.Parent, {
				Name = "Salt",
				Size = along,
				CFrame = CFrame.new(door.Inside + Vector3.new(0, 0.04, 0)),
				Color = Color3.fromRGB(214, 208, 196),
				Material = Enum.Material.Sand,
				CastShadow = false,
			})
		end
	end
end

function Dressers.Machine(ctx: Ctx)
	local x0, z0, x1, z1 = rect(ctx)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local center = ctx.W(cx, cz)
	-- Housing (collidable) with a great wheel half-sunk into the floor.
	Kit.Part(ctx.Parent, {
		Name = "Housing",
		Size = Vector3.new(16, 2, 4),
		CFrame = CFrame.new(center + Vector3.new(0, 1, 0)),
		Color = P.OldIron,
		Material = Enum.Material.CorrodedMetal,
	})
	local gear = Kit.Model(ctx.Parent, "Gear")
	local hub = Kit.Part(gear, {
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 13, 13),
		CFrame = CFrame.new(center + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(70, 60, 50),
		Material = Enum.Material.CorrodedMetal,
		CanCollide = false,
	})
	for i = 0, 13 do
		local a = math.rad(i * (360 / 14))
		Kit.Deco(gear, {
			Name = "Tooth",
			Size = Vector3.new(1.6, 1.6, 1.4),
			CFrame = hub.CFrame * CFrame.Angles(a, 0, 0) * CFrame.new(0, 7, 0),
			Color = Color3.fromRGB(70, 60, 50),
			Material = Enum.Material.CorrodedMetal,
		})
	end
	Kit.Deco(gear, {
		Name = "Axle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 2.4, 2.4),
		CFrame = hub.CFrame,
		Color = P.Rust,
		Material = Enum.Material.CorrodedMetal,
	})
	gear.PrimaryPart = hub
	gear:SetAttribute("Running", true)
	CollectionService:AddTag(gear, "Spinner")
	-- Hanging chains.
	for _, c in { { x0 + 4, z0 + 4 }, { x1 - 4, z1 - 4 }, { x1 - 4, z0 + 4 } } do
		for k = 0, 4 do
			Kit.Deco(ctx.Parent, {
				Name = "Chain",
				Size = Vector3.new(0.3, 1.1, 0.6),
				CFrame = CFrame.new(ctx.W(c[1], c[2], 9.5 - k * 1.1)) * CFrame.Angles(0, k * 1.57, 0),
				Color = P.OldIron,
				Material = Enum.Material.CorrodedMetal,
			})
		end
	end
	-- The lever.
	local lx, lz = cx, cz + 5
	local leverBase = Kit.Part(ctx.Parent, {
		Name = "LeverBase",
		Size = Vector3.new(1.6, 1, 1.6),
		CFrame = CFrame.new(ctx.W(lx, lz, 0.5)),
		Color = P.OldIron,
		Material = Enum.Material.CorrodedMetal,
	})
	local handle = Kit.Deco(ctx.Parent, {
		Name = "LeverHandle",
		Size = Vector3.new(0.35, 3, 0.35),
		CFrame = CFrame.new(ctx.W(lx, lz, 2)) * CFrame.Angles(math.rad(-30), 0, 0),
		Color = P.Rust,
		Material = Enum.Material.CorrodedMetal,
	})
	local prompt = Fixtures.Prompt(leverBase, "Pull", "Lever", nil, 8)
	ctx.Built.Machine = { Gear = gear, Prompt = prompt, Handle = handle, Running = true, Pos = center, RoomId = ctx.Room.Id }
end

function Dressers.Cistern(ctx: Ctx)
	local x0, z0, x1, z1, w, d = rect(ctx)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local pw, pd = w - 14, d - 14
	local water = Kit.Deco(ctx.Parent, {
		Name = "Water",
		Size = Vector3.new(pw, 1.1, pd),
		CFrame = CFrame.new(ctx.W(cx, cz, 0.55)),
		Color = Color3.fromRGB(38, 52, 58),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CastShadow = false,
	})
	water.CanQuery = false
	-- Low rim.
	for _, e in {
		{ Vector3.new(pw + 2, 0.6, 1), Vector3.new(0, 0, -pd / 2 - 0.5) },
		{ Vector3.new(pw + 2, 0.6, 1), Vector3.new(0, 0, pd / 2 + 0.5) },
		{ Vector3.new(1, 0.6, pd), Vector3.new(-pw / 2 - 0.5, 0, 0) },
		{ Vector3.new(1, 0.6, pd), Vector3.new(pw / 2 + 0.5, 0, 0) },
	} do
		Kit.Deco(ctx.Parent, {
			Name = "Rim",
			Size = e[1],
			CFrame = CFrame.new(ctx.W(cx, cz, 0.3)) * CFrame.new(e[2]),
			Color = P.PaleStone,
			Material = Enum.Material.Slate,
		})
	end
	-- Stepping stones: a quiet but narrow way across.
	local alongX = w >= d
	local n = math.floor((if alongX then pw else pd) / 3.2)
	for i = 0, n - 1 do
		local t = (i + 0.5) / n
		local px = if alongX then cx - pw / 2 + t * pw else cx + math.sin(i * 1.3) * 1.2
		local pz = if alongX then cz + math.sin(i * 1.3) * 1.2 else cz - pd / 2 + t * pd
		Kit.Part(ctx.Parent, {
			Name = "SteppingStone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.3, 2.6, 2.6),
			CFrame = CFrame.new(ctx.W(px, pz, 0.65)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Kit.Vary(P.AgedStone, 0.1, i),
			Material = Enum.Material.Slate,
		})
	end
	ctx.Built.Water = ctx.Built.Water or {}
	table.insert(ctx.Built.Water, {
		Center = ctx.W(cx, cz),
		Half = Vector2.new(pw / 2, pd / 2),
	})
	local drip = Instance.new("ParticleEmitter")
	drip.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drip.Color = ColorSequence.new(Color3.fromRGB(150, 170, 190))
	drip.Size = NumberSequence.new(0.12)
	drip.Lifetime = NumberRange.new(1, 1.2)
	drip.Rate = 2
	drip.Speed = NumberRange.new(0)
	drip.Acceleration = Vector3.new(0, -20, 0)
	drip.Parent = Kit.Attachment(water, Vector3.new(0, 10, 0))
end

function Dressers.Vault(ctx: Ctx)
	local x0, z0, x1, z1 = rect(ctx)
	for _, s in { { x0 + 1.5, z0 + 6, x0 + 1.5, z1 - 6 }, { x1 - 1.5, z0 + 6, x1 - 1.5, z1 - 6 } } do
		local len = s[4] - s[2]
		for k = 0, 2 do
			Kit.Part(ctx.Parent, {
				Name = "Shelf",
				Size = Vector3.new(2, 0.4, len),
				CFrame = CFrame.new(ctx.W(s[1], (s[2] + s[4]) / 2, 1.5 + k * 2.4)),
				Color = P.DarkBrown,
				Material = Enum.Material.WoodPlanks,
			})
		end
	end
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local glow = Kit.Part(ctx.Parent, {
		Name = "VaultGlow",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(ctx.W(cx, cz, 8)),
		Transparency = 1,
		CanCollide = false,
	})
	Kit.PointLight(glow, P.Gold, 16, 0.7, true)
end

function Dressers.Camp(ctx: Ctx)
	local x0, z0, x1, z1 = rect(ctx)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	Kit.Deco(ctx.Parent, {
		Name = "Bedroll",
		Size = Vector3.new(3, 0.5, 6.5),
		CFrame = CFrame.new(ctx.W(cx - 4, cz, 0.25)) * CFrame.Angles(0, 0.2, 0),
		Color = P.Burgundy,
		Material = Enum.Material.Fabric,
	})
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		Kit.Deco(ctx.Parent, {
			Name = "FireStone",
			Size = Vector3.new(0.9, 0.6, 0.9),
			CFrame = CFrame.new(ctx.W(cx + 2 + math.cos(a) * 1.8, cz + math.sin(a) * 1.8, 0.3)),
			Color = P.DarkStone,
			Material = Enum.Material.Slate,
		})
	end
	local ember = Kit.Deco(ctx.Parent, {
		Name = "Embers",
		Size = Vector3.new(1.6, 0.3, 1.6),
		CFrame = CFrame.new(ctx.W(cx + 2, cz, 0.15)),
		Color = Color3.fromRGB(110, 46, 20),
		Material = Enum.Material.Neon,
	})
	Kit.PointLight(ember, P.Amber, 9, 0.6, false)
	local note = Kit.Part(ctx.Parent, {
		Name = "Note",
		Size = Vector3.new(1.2, 0.1, 1.6),
		CFrame = CFrame.new(ctx.W(cx - 4, cz - 4, 0.6)) * CFrame.Angles(0, 0.4, 0),
		Color = P.Parchment,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	local text = ""
	for _, n in ctx.Floor.Notes do
		if n.RoomId == ctx.Room.Id then
			text = n.Text
		end
	end
	local prompt = Fixtures.Prompt(note, "Read", "Note", nil, 7)
	ctx.Built.Camp = { Prompt = prompt, Text = text, RoomId = ctx.Room.Id }
end

function Dressers.Secret(ctx: Ctx)
	local x0, z0, x1, z1 = rect(ctx)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	-- A shaft of cold light from somewhere far above.
	local high = Kit.Part(ctx.Parent, {
		Name = "Shaft",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.lookAt(ctx.W(cx, cz, 22), ctx.W(cx, cz, 0)),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	})
	local spot = Instance.new("SpotLight")
	spot.Color = P.Moon
	spot.Brightness = 3
	spot.Range = 30
	spot.Angle = 28
	spot.Face = Enum.NormalId.Front
	spot.Shadows = true
	spot.Parent = high
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(P.Moon)
	motes.Size = NumberSequence.new(0.1)
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 1) })
	motes.Lifetime = NumberRange.new(4, 6)
	motes.Rate = 4
	motes.Speed = NumberRange.new(0.3, 0.8)
	motes.SpreadAngle = Vector2.new(6, 6)
	motes.EmissionDirection = Enum.NormalId.Front
	motes.Parent = high
end

function Dressers.Dress(ctx: Ctx)
	local fn = (Dressers :: any)[ctx.Room.Archetype]
	if fn then
		fn(ctx)
	end
end

return Dressers
