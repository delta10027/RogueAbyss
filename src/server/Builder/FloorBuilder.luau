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
			local prompt = Fixtures.Prompt(slab, "Unlock", "Iron door", c.Id, 8)
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
		local prompt = Fixtures.Prompt(handle.Bowl, "Kindle", "Cold brazier", b.Id, 7)
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
		local model = Fixtures.ItemModel(itemsFolder, pos, it.ItemId, color)
		local name = if def then def.Name else "Curio"
		local prompt = Fixtures.Prompt(model.PrimaryPart :: BasePart, "Take", name, tostring(idx), 7)
		built.Items[idx] = { ItemId = it.ItemId, Name = it.Name or name, Model = model, Prompt = prompt, Pos = pos, Taken = false }
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
