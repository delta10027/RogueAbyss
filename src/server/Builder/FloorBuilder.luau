--!strict
-- Layer 5 (presentation): converts a validated LogicalFloor into Instances.
-- Returns a `Built` table of handles that gameplay services use. The builder
-- never decides gameplay outcomes; it only constructs and exposes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)
local Items = require(Shared.Definitions.Items)
local FloorRules = require(Shared.Definitions.FloorRules)
local RoomDefs = require(Shared.Definitions.Rooms)

local Kit = require(script.Parent.Kit)
local Shell = require(script.Parent.Shell)
local Fixtures = require(script.Parent.Fixtures)
local Dressers = require(script.Parent.Dressers)

local P = Kit.Palette

local FloorBuilder = {}

local OUTWARD = {
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
	S = Vector3.new(0, 0, 1),
	N = Vector3.new(0, 0, -1),
}

local FRAME_STYLE: { [string]: { Color3 | Enum.Material } } = {
	OldStone = { P.DarkStone, Enum.Material.Slate },
	ImpossibleRepair = { P.DarkBrown, Enum.Material.WoodPlanks },
	BuriedMachine = { P.OldIron, Enum.Material.CorrodedMetal },
	ForgottenShrine = { P.PaleStone, Enum.Material.Limestone },
	LivingPassage = { P.Moss, Enum.Material.Slate },
}

local WALL_LOOK: { [string]: { Color3 | Enum.Material } } = {
	OldStone = { P.AgedStone, Enum.Material.Slate },
	ImpossibleRepair = { P.Brick, Enum.Material.Brick },
	BuriedMachine = { P.OldIron, Enum.Material.CorrodedMetal },
	ForgottenShrine = { P.PaleStone, Enum.Material.Limestone },
	LivingPassage = { P.Moss, Enum.Material.Slate },
}

function FloorBuilder.Build(floor, origin: Vector3, parent: Instance)
	local folder = Kit.Folder(parent, string.format("Floor%d", floor.Depth))
	folder:SetAttribute("Seed", floor.Seed)
	folder:SetAttribute("Depth", floor.Depth)
	folder:SetAttribute("Rule", floor.RuleId)

	local function W(x: number, z: number, y: number?): Vector3
		return origin + Vector3.new(x, y or 0, z)
	end

	local built = {
		Folder = folder,
		Origin = origin,
		Floor = floor,
		Spawn = CFrame.new(W(0, 0, 3)),
		DoorPositions = {} :: { [string]: any },
		Gates = {} :: { [string]: any },
		VaultDoors = {} :: { [string]: any },
		Cracked = {} :: { [string]: any },
		WoodDoors = {} :: { [string]: any },
		Braziers = {} :: { [string]: any },
		Items = {} :: { [number]: any },
		Chests = {} :: { [string]: any },
		Breakables = {} :: { any },
		Water = {} :: { any },
		RoomRects = {} :: { [string]: { Min: Vector3, Max: Vector3 } },
		Descent = nil :: any,
		Shrine = nil :: any,
		Machine = nil :: any,
		Camp = nil :: any,
		StelePrompt = nil :: any,
	}

	Shell.Build(floor, origin, folder)

	for id, room in floor.Rooms do
		local r = room.Rect
		built.RoomRects[id] = { Min = W(r.X0, r.Z0), Max = W(r.X1, r.Z1) }
	end

	-- Door positions (both ends of every connection).
	for _, c in floor.Connections do
		for _, e in { { c.A, c.DoorA }, { c.B, c.DoorB } } do
			local roomId, door = e[1], e[2]
			local out = OUTWARD[door.Side]
			local p = W(door.Pos.X, door.Pos.Y)
			built.DoorPositions[roomId .. ":" .. c.Id] = {
				Band = p + out * 1,
				Inside = p - out * 1.5,
				Outward = out,
				Axis = if door.Side == "E" or door.Side == "W" then "Z" else "X",
				Conn = c.Id,
				Room = roomId,
			}
		end
	end

	local fixtures = Kit.Folder(folder, "Fixtures")
	local rule = FloorRules[floor.RuleId]

	for _, c in floor.Connections do
		local endA = built.DoorPositions[c.A .. ":" .. c.Id]
		local endB = built.DoorPositions[c.B .. ":" .. c.Id]
		for _, e in { endA, endB } do
			local fam = RoomDefs[floor.Rooms[e.Room].Archetype].Family
			local hideFrame = c.Kind == "Secret" and e.Room ~= floor.SecretId
			if not hideFrame then
				local st = FRAME_STYLE[fam]
				Fixtures.DoorFrame(fixtures, e.Band, e.Axis, st[1] :: Color3, st[2] :: Enum.Material)
			end
		end

		if c.Kind == "Gate" then
			local model, setOpen, isOpen = Fixtures.Gate(fixtures, endA.Band, endA.Axis)
			setOpen(c.OpenInPhase == 0, true)
			built.Gates[c.Id] = { Model = model, SetOpen = setOpen, IsOpen = isOpen, OpenInPhase = c.OpenInPhase, Pos = endA.Band }
			for _, e in { endA, endB } do
				Fixtures.FloorGlyph(fixtures, e.Inside - e.Outward * 2.5, 2.6, rule.Glyph, Color3.fromRGB(150, 128, 92))
			end
		elseif c.Kind == "VaultDoor" then
			local vaultEnd = if c.A == floor.VaultId then endA else endB
			local model, open, slab = Fixtures.IronDoor(fixtures, vaultEnd.Band, vaultEnd.Axis)
			local prompt = Fixtures.Prompt(slab, "Unlock", "Iron vault door", c.Id, 8)
			built.VaultDoors[c.Id] = { Model = model, Open = open, Prompt = prompt, Pos = vaultEnd.Band, Opened = false }
		elseif c.Kind == "Secret" then
			local hostEnd = if c.A == floor.SecretId then endB else endA
			local fam = RoomDefs[floor.Rooms[hostEnd.Room].Archetype].Family
			local look = WALL_LOOK[fam]
			local model, block, shatter = Fixtures.CrackedWall(fixtures, hostEnd.Band, hostEnd.Axis, look[1] :: Color3, look[2] :: Enum.Material, hostEnd.Outward)
			block:SetAttribute("Breakable", c.Id)
			built.Cracked[c.Id] = { Model = model, Block = block, Shatter = shatter, Hits = 0, Broken = false, Pos = hostEnd.Band }
		elseif floor.Depth == 1 and (c.A == floor.StartId or c.B == floor.StartId) then
			-- Floor one: three identical wooden doors out of the antechamber.
			local startEnd = if c.A == floor.StartId then endA else endB
			local model, open = Fixtures.WoodDoor(fixtures, startEnd.Band, startEnd.Axis, 1)
			local prompt = Fixtures.Prompt(model.PrimaryPart :: BasePart, "Open", "Door", c.Id, 8)
			built.WoodDoors[c.Id] = { Model = model, Open = open, Prompt = prompt, Pos = startEnd.Band, Opened = false }
		end
	end

	-- Room dressing.
	for _, id in floor.RoomOrder do
		local room = floor.Rooms[id]
		local roomFolder = Kit.Folder(folder, id .. "_" .. room.Archetype)
		local doors = {}
		for _, connId in room.Doors do
			local d = built.DoorPositions[id .. ":" .. connId]
			if d then
				table.insert(doors, d)
			end
		end
		local ctx = {
			Floor = floor,
			Room = room,
			Origin = origin,
			Parent = roomFolder,
			Built = built,
			Rng = Random.new(RNG.Derive(floor.Seed, floor.Depth, "dress:" .. id)),
			W = W,
			ClearOfDoors = function(x: number, z: number, radius: number): boolean
				local p = W(x, z)
				for _, d in doors do
					local q = d.Inside - d.Outward * 3
					if (Vector3.new(p.X, 0, p.Z) - Vector3.new(q.X, 0, q.Z)).Magnitude < radius + 4 then
						return false
					end
				end
				return true
			end,
		}
		local ok, err = pcall(Dressers.Dress, ctx)
		if not ok then
			-- Dressing is optional: a failed prop must never break the floor.
			warn(string.format("[FloorBuilder] dressing %s (%s) failed: %s", id, room.Archetype, tostring(err)))
		end
	end

	-- Braziers.
	for _, b in floor.Braziers do
		local handle = Fixtures.Brazier(fixtures, W(b.Pos.X, b.Pos.Y), b.Lit)
		local prompt = Fixtures.Prompt(handle.Bowl, "Kindle", "Brazier (costs lantern oil)", b.Id, 7)
		prompt.Enabled = not b.Lit
		handle.Prompt = prompt
		handle.Pos = W(b.Pos.X, b.Pos.Y)
		handle.RoomId = b.RoomId
		handle.Model:SetAttribute("BrazierId", b.Id)
		built.Braziers[b.Id] = handle
	end

	-- Items.
	local itemsFolder = Kit.Folder(folder, "Items")
	for idx, it in floor.Items do
		local def = Items[it.ItemId]
		local color = if def then def.Color else P.Gold
		local pos = W(it.Pos.X, it.Pos.Y)
		local model = Fixtures.ItemModel(itemsFolder, pos, it.ItemId, color, if def then def.Category else nil)
		local count, bonus = it.Count or 1, it.Bonus or 0
		local label = if it.ItemId == "Gold" then (count .. " gold")
			elseif it.ItemId == "Curio" then "Treasure"
			else Items.EntryName({ Id = it.ItemId, Count = count, Bonus = bonus })
		local prompt = Fixtures.Prompt(model.PrimaryPart :: BasePart, "Take", label, tostring(idx), 7)
		built.Items[idx] = { ItemId = it.ItemId, Name = it.Name, Count = count, Bonus = bonus, Model = model, Prompt = prompt, Pos = pos, Taken = false }
	end

	-- Breakable props.
	local breakFolder = Kit.Folder(folder, "Breakables")
	for _, b in floor.Breakables or {} do
		local handle = Fixtures.Breakable(breakFolder, W(b.Pos.X, b.Pos.Y), b.Kind, b.Yaw, b.Id)
		table.insert(built.Breakables, handle)
	end

	-- Atmosphere: wall torches, bones, cobwebs and chains, deterministic per room.
	local decor = Kit.Folder(folder, "Decor")
	for _, id in floor.RoomOrder do
		local room = floor.Rooms[id]
		local r = room.Rect
		local rng = Random.new(floor.Seed + floor.Depth * 131 + #id * 7 + math.floor(r.X0 * 3 + r.Z0))
		local arch = room.Archetype
		local wallY = Config.Grid.WallHeight * 0.62
		-- Torches on the north and south walls of larger rooms (not on Hungry Dark floors).
		if floor.RuleId ~= "HungryDark" and arch ~= "Junction" and arch ~= "Secret" and rng:NextNumber() < 0.45 then
			local cx = (r.X0 + r.X1) / 2
			for _, side in { { r.Z0 + 0.3, 1 }, { r.Z1 - 0.3, -1 } } do
				local x = cx + rng:NextNumber(-4, 4)
				local clear = true
				for _, dp in built.DoorPositions do
					if dp.Room == id and (Vector2.new(dp.Inside.X, dp.Inside.Z) - Vector2.new(origin.X + x, origin.Z + side[1])).Magnitude < 7 then
						clear = false
					end
				end
				if clear then
					Fixtures.WallTorch(decor, W(x, side[1], wallY), Vector3.new(0, 0, side[2]))
				end
			end
		end
		if arch ~= "Junction" then
			-- Cobwebs in two corners.
			for _, c in { { r.X0, r.Z0, 1, 1 }, { r.X1, r.Z1, -1, -1 } } do
				if rng:NextNumber() < 0.6 then
					local web = Kit.Deco(decor, {
						Name = "Cobweb",
						Size = Vector3.new(0.05, 3.2, 3.2),
						CFrame = CFrame.new(W(c[1] + c[3] * 1.1, c[2] + c[4] * 1.1, Config.Grid.WallHeight - 1.6)) * CFrame.Angles(0, math.rad(if c[3] > 0 then 45 else 225), math.rad(-35)),
						Color = Color3.fromRGB(200, 196, 186),
						Material = Enum.Material.Fabric,
						CastShadow = false,
					})
					web.Transparency = 0.72
				end
			end
			-- Bones and a skull or two.
			for _ = 1, rng:NextInteger(0, 3) do
				local bx = rng:NextNumber(r.X0 + 3, r.X1 - 3)
				local bz = rng:NextNumber(r.Z0 + 3, r.Z1 - 3)
				local bone = Kit.Deco(decor, {
					Name = "Bone",
					Size = Vector3.new(0.25, 0.25, rng:NextNumber(1, 1.8)),
					CFrame = CFrame.new(W(bx, bz, 0.15)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
					Color = P.Bone,
					Material = Enum.Material.SmoothPlastic,
					CastShadow = false,
				})
				bone.Name = "Bone"
				if rng:NextNumber() < 0.4 then
					Kit.Deco(decor, {
						Name = "Skull",
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(0.75, 0.75, 0.75),
						CFrame = CFrame.new(W(bx + 0.7, bz + 0.4, 0.37)),
						Color = P.Bone,
						Material = Enum.Material.SmoothPlastic,
					})
				end
			end
			-- A hanging chain.
			if rng:NextNumber() < 0.3 then
				local hx = rng:NextNumber(r.X0 + 4, r.X1 - 4)
				local hz = rng:NextNumber(r.Z0 + 4, r.Z1 - 4)
				for i = 0, 4 do
					Kit.Deco(decor, {
						Name = "Chain",
						Size = Vector3.new(0.18, 0.6, 0.35),
						CFrame = CFrame.new(W(hx, hz, Config.Grid.WallHeight - 0.4 - i * 0.55)) * CFrame.Angles(0, if i % 2 == 0 then 0 else math.rad(90), 0),
						Color = P.OldIron,
						Material = Enum.Material.Metal,
						CastShadow = false,
					})
				end
			end
		end
	end

	-- Chests: contents are rolled by ItemService when opened.
	local chestFolder = Kit.Folder(folder, "Chests")
	for _, ch in floor.Chests or {} do
		local pos = W(ch.Pos.X, ch.Pos.Y)
		local rr = built.RoomRects[ch.RoomId]
		local center = (rr.Min + rr.Max) / 2
		local toCenter = Vector3.new(center.X - pos.X, 0, center.Z - pos.Z)
		-- Face the room along the nearest axis.
		local facing = if math.abs(toCenter.X) > math.abs(toCenter.Z)
			then Vector3.new(math.sign(toCenter.X), 0, 0)
			else Vector3.new(0, 0, if toCenter.Z == 0 then 1 else math.sign(toCenter.Z))
		local model, body, open = Fixtures.Chest(chestFolder, pos, facing, ch.Quality)
		local prompt = Fixtures.Prompt(body, "OpenChest", if ch.Quality >= 3 then "Ornate chest" else "Chest", ch.Id, 8)
		built.Chests[ch.Id] = {
			Id = ch.Id,
			Model = model,
			Prompt = prompt,
			Pos = pos,
			Front = facing,
			Right = facing:Cross(Vector3.yAxis),
			Quality = ch.Quality,
			Opened = false,
			Open = open,
		}
	end

	-- The draft: dust drifts toward the way down.
	local draftFolder = Kit.Folder(folder, "Draft")
	local function dustAt(pos: Vector3, dir: Vector3, rate: number)
		local holder = Kit.Part(draftFolder, {
			Name = "DustSource",
			Size = Vector3.new(4, 0.2, 4),
			CFrame = CFrame.new(pos),
			Transparency = 1,
			CanCollide = false,
			CastShadow = false,
			CanQuery = false,
		})
		Kit.Dust(holder, dir, rate)
	end
	local connById = {}
	for _, c in floor.Connections do
		connById[c.Id] = c
	end
	for _, id in floor.RoomOrder do
		local room = floor.Rooms[id]
		local connId = room.DraftConn
		if connId then
			local d = built.DoorPositions[id .. ":" .. connId]
			if d then
				dustAt(d.Inside - d.Outward * 1.5 + Vector3.new(0, 0.5, 0), d.Outward, 8)
				-- Dust along the corridor, flowing away from this room.
				local c = connById[connId]
				local pts = table.clone(c.Points)
				if c.A ~= id then
					local rev = {}
					for i = #pts, 1, -1 do
						table.insert(rev, pts[i])
					end
					pts = rev
				end
				for i = 1, #pts - 1 do
					local a, b = pts[i], pts[i + 1]
					local mid = (a + b) / 2
					local dir = Vector3.new(b.X - a.X, 0, b.Y - a.Y)
					if dir.Magnitude > 0.1 then
						dustAt(W(mid.X, mid.Y, 0.5), dir, 5)
					end
				end
			end
		end
	end

	return built
end

-- Which room (id) contains a world position, if any.
function FloorBuilder.RoomAt(built, pos: Vector3, margin: number?): string?
	local m = margin or 0
	for id, r in built.RoomRects do
		if pos.X >= r.Min.X - m and pos.X <= r.Max.X + m and pos.Z >= r.Min.Z - m and pos.Z <= r.Max.Z + m then
			return id
		end
	end
	return nil
end

return FloorBuilder
