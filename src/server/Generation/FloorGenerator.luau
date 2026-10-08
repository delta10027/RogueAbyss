--!strict
-- Produces a LogicalFloor from (runSeed, depth). Pure data: no Instances.
--
-- Pipeline (TECH_ARCHITECTURE §8):
--   rule -> macro graph -> start -> descent -> secret -> vault/key ->
--   landmark/shrine/camp -> filler archetypes -> gates -> geometry ->
--   encounters -> items -> braziers -> draft -> validate (repair/regenerate)
--
-- Coordinates are in studs relative to the floor origin. X grows east,
-- Z grows south. Each macro-grid slot holds exactly one room.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)
local RoomDefs = require(Shared.Definitions.Rooms)

local Graph = require(script.Parent.Graph)
local Validator = require(script.Parent.Validator)

local Grid = Config.Grid

local FloorGenerator = {}

local RULE_POOL = { "Echoes", "HungryDark", "Tolling" }

local CURIOS = {
	"a brass astrolabe shard",
	"a wax-sealed letter, unopened",
	"a carved ivory fish",
	"a key with no teeth",
	"a lens that shows the room darker",
	"a child's tin soldier, painted black",
	"a compass needle that points down",
	"a page of a map of this floor, wrong",
}

local CAMP_NOTES = {
	"Third night. The tall ones cannot see. I have stopped wearing boots.",
	"The bell on the lower floor is not rung by anyone. I checked.",
	"Statues moved again while I slept. I keep the lamp facing them now.",
	"Follow the dust. The air knows the way down. I wish I had noticed sooner.",
	"Left the spare oil. Whoever you are, go further than I did.",
}

export type Rect = { X0: number, Z0: number, X1: number, Z1: number }

local function roomId(gx: number, gy: number): string
	return string.format("r%d_%d", gx, gy)
end

local function gridSize(depth: number): (number, number)
	if depth <= 1 then
		return 3, 3
	elseif depth <= 3 then
		return 4, 3
	end
	return 4, 4
end

function FloorGenerator.RuleFor(runSeed: number, depth: number): string
	local prev = "Echoes"
	if depth <= 1 then
		return prev
	end
	for d = 2, depth do
		local stream = RNG.Stream(runSeed, d, "rule")
		local options = {}
		for _, r in RULE_POOL do
			if r ~= prev then
				table.insert(options, r)
			end
		end
		prev = stream:Pick(options)
	end
	return prev
end

-- Union-find for the random spanning tree.
local function makeSets(ids: { string })
	local parent: { [string]: string } = {}
	for _, id in ids do
		parent[id] = id
	end
	local function find(x: string): string
		while parent[x] ~= x do
			parent[x] = parent[parent[x]]
			x = parent[x]
		end
		return x
	end
	local function union(a: string, b: string): boolean
		local ra, rb = find(a), find(b)
		if ra == rb then
			return false
		end
		parent[ra] = rb
		return true
	end
	return union
end

local function sizeFor(stream, archetype: string): number
	local def = RoomDefs[archetype]
	if archetype == "Junction" then
		return Grid.JunctionSize
	elseif archetype == "Secret" then
		return 4 * stream:Int(5, 7)
	elseif archetype == "Vault" then
		return 4 * stream:Int(6, 7)
	elseif archetype == "Stairwell" then
		return 4 * stream:Int(7, 9)
	end
	local lo = math.max(Grid.MinRoom, def.MinSize or Grid.MinRoom)
	return 4 * stream:Int(math.ceil(lo / 4), math.floor(Grid.MaxRoom / 4))
end

-- Door centre must stay this far from a room corner.
local DOOR_INSET = Grid.DoorWidth / 2 + 3

local function pickInRange(stream, lo: number, hi: number): number
	-- Results are even so corridor edges land on the 2-stud build grid.
	if hi <= lo then
		return 2 * math.floor((lo + hi) / 4)
	end
	local a, b = math.ceil(lo / 2), math.floor(hi / 2)
	if b < a then
		return 2 * math.floor((lo + hi) / 4)
	end
	return 2 * stream:Int(a, b)
end

-- Computes corridor polyline and door placements between two grid-adjacent rooms.
local function buildCorridor(stream, conn, a, b)
	local horizontal = a.Gy == b.Gy
	-- Ensure `a` is west (horizontal) or north (vertical) of `b`.
	if (horizontal and a.Gx > b.Gx) or (not horizontal and a.Gy > b.Gy) then
		a, b = b, a
		conn.A, conn.B = conn.B, conn.A
	end
	local ra: Rect, rb: Rect = a.Rect, b.Rect
	local points: { Vector2 }
	if horizontal then
		local lo = math.max(ra.Z0, rb.Z0) + DOOR_INSET
		local hi = math.min(ra.Z1, rb.Z1) - DOOR_INSET
		if hi >= lo then
			local z = pickInRange(stream, lo, hi)
			points = { Vector2.new(ra.X1, z), Vector2.new(rb.X0, z) }
		else
			local za = pickInRange(stream, ra.Z0 + DOOR_INSET, ra.Z1 - DOOR_INSET)
			local zb = pickInRange(stream, rb.Z0 + DOOR_INSET, rb.Z1 - DOOR_INSET)
			local mx = 2 * math.floor((ra.X1 + rb.X0) / 4)
			points = { Vector2.new(ra.X1, za), Vector2.new(mx, za), Vector2.new(mx, zb), Vector2.new(rb.X0, zb) }
		end
		conn.DoorA = { Pos = points[1], Side = "E" }
		conn.DoorB = { Pos = points[#points], Side = "W" }
	else
		local lo = math.max(ra.X0, rb.X0) + DOOR_INSET
		local hi = math.min(ra.X1, rb.X1) - DOOR_INSET
		if hi >= lo then
			local x = pickInRange(stream, lo, hi)
			points = { Vector2.new(x, ra.Z1), Vector2.new(x, rb.Z0) }
		else
			local xa = pickInRange(stream, ra.X0 + DOOR_INSET, ra.X1 - DOOR_INSET)
			local xb = pickInRange(stream, rb.X0 + DOOR_INSET, rb.X1 - DOOR_INSET)
			local mz = 2 * math.floor((ra.Z1 + rb.Z0) / 4)
			points = { Vector2.new(xa, ra.Z1), Vector2.new(xa, mz), Vector2.new(xb, mz), Vector2.new(xb, rb.Z0) }
		end
		conn.DoorA = { Pos = points[1], Side = "S" }
		conn.DoorB = { Pos = points[#points], Side = "N" }
	end
	conn.Points = points
	a.Doors[conn.DoorA.Side] = conn.Id
	b.Doors[conn.DoorB.Side] = conn.Id
end

-- A spot along a random wall, `inset` studs in from it.
local function wallSpot(stream, rect: Rect, inset: number): Vector2
	local side = stream:Int(1, 4)
	local w, d = rect.X1 - rect.X0, rect.Z1 - rect.Z0
	if side == 1 then
		return Vector2.new(rect.X0 + inset, rect.Z0 + stream:Float(inset, d - inset))
	elseif side == 2 then
		return Vector2.new(rect.X1 - inset, rect.Z0 + stream:Float(inset, d - inset))
	elseif side == 3 then
		return Vector2.new(rect.X0 + stream:Float(inset, w - inset), rect.Z0 + inset)
	end
	return Vector2.new(rect.X0 + stream:Float(inset, w - inset), rect.Z1 - inset)
end

local function generateOnce(runSeed: number, depth: number, attempt: number)
	local salt = if attempt > 0 then ("#" .. attempt) else ""
	local layout = RNG.Stream(runSeed, depth, "layout" .. salt)
	local roles = RNG.Stream(runSeed, depth, "roles" .. salt)
	local encounters = RNG.Stream(runSeed, depth, "encounters" .. salt)
	local itemStream = RNG.Stream(runSeed, depth, "items" .. salt)
	local secretStream = RNG.Stream(runSeed, depth, "secrets" .. salt)

	local ruleId = FloorGenerator.RuleFor(runSeed, depth)
	local cols, rows = gridSize(depth)

	local floor = {
		Seed = runSeed,
		Depth = depth,
		Attempt = attempt,
		RuleId = ruleId,
		Cols = cols,
		Rows = rows,
		Rooms = {} :: { [string]: any },
		RoomOrder = {} :: { string },
		Connections = {} :: { any },
		Encounters = {} :: { any },
		Items = {} :: { any },
		Braziers = {} :: { any },
		Notes = {} :: { any },
		Events = {} :: { string },
		MainPath = {} :: { string },
	}

	-- Layer 1: macro structure -------------------------------------------
	for gy = 0, rows - 1 do
		for gx = 0, cols - 1 do
			local id = roomId(gx, gy)
			floor.Rooms[id] = { Id = id, Gx = gx, Gy = gy, Archetype = "", Doors = {}, Tags = {} }
			table.insert(floor.RoomOrder, id)
		end
	end

	local startId = if depth == 1 then roomId(1, 1) else roles:Pick(floor.RoomOrder)

	-- Secret slot: a border slot that is not the start.
	local border = {}
	for _, id in floor.RoomOrder do
		local r = floor.Rooms[id]
		local onBorder = r.Gx == 0 or r.Gy == 0 or r.Gx == cols - 1 or r.Gy == rows - 1
		if onBorder and id ~= startId then
			table.insert(border, id)
		end
	end
	local secretId = secretStream:Pick(border)

	-- All grid-adjacent pairs (sorted deterministic order).
	local pairsList = {}
	for _, id in floor.RoomOrder do
		local r = floor.Rooms[id]
		if r.Gx < cols - 1 then
			table.insert(pairsList, { id, roomId(r.Gx + 1, r.Gy) })
		end
		if r.Gy < rows - 1 then
			table.insert(pairsList, { id, roomId(r.Gx, r.Gy + 1) })
		end
	end

	local mainIds = {}
	for _, id in floor.RoomOrder do
		if id ~= secretId then
			table.insert(mainIds, id)
		end
	end
	local union = makeSets(mainIds)
	local candidates = {}
	for _, p in pairsList do
		if p[1] ~= secretId and p[2] ~= secretId then
			table.insert(candidates, p)
		end
	end
	layout:Shuffle(candidates)

	local connCount = 0
	local used: { [string]: boolean } = {}
	local function addConn(a: string, b: string, kind: string)
		connCount += 1
		local c = { Id = "c" .. connCount, A = a, B = b, Kind = kind, OpenInPhase = nil, Points = {} }
		table.insert(floor.Connections, c)
		used[a .. "|" .. b] = true
		used[b .. "|" .. a] = true
		return c
	end

	local spares = {}
	for _, p in candidates do
		if union(p[1], p[2]) then
			addConn(p[1], p[2], "Open")
		else
			table.insert(spares, p)
		end
	end

	-- Floor one: the antechamber offers three ways out.
	if depth == 1 then
		for _, p in spares do
			if Graph.Degree(floor.Connections, startId) >= 3 then
				break
			end
			if (p[1] == startId or p[2] == startId) and not used[p[1] .. "|" .. p[2]] then
				addConn(p[1], p[2], "Open")
			end
		end
	end

	local loops = 1 + (if depth >= 2 then 1 else 0) + (if ruleId == "Tolling" then 2 else 0)
	for _, p in spares do
		if loops <= 0 then
			break
		end
		if not used[p[1] .. "|" .. p[2]] then
			addConn(p[1], p[2], "Open")
			loops -= 1
		end
	end

	-- Descent: farthest room from the start.
	local adjAll = Graph.Adjacency(floor.Connections)
	local dist = Graph.BFS(adjAll, startId)
	local best, far = -1, {}
	for _, id in mainIds do
		local d = dist[id]
		if d and d > best then
			best, far = d, { id }
		elseif d and d == best then
			table.insert(far, id)
		end
	end
	local descentId = roles:Pick(far)

	-- Secret connection to a neighbour that is neither start nor descent if possible.
	local sr = floor.Rooms[secretId]
	local neigh = {}
	for _, off in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local nx, ny = sr.Gx + off[1], sr.Gy + off[2]
		if nx >= 0 and ny >= 0 and nx < cols and ny < rows then
			local nid = roomId(nx, ny)
			if nid ~= descentId then
				table.insert(neigh, nid)
			end
		end
	end
	local secretHost = secretStream:Pick(neigh)
	addConn(secretHost, secretId, "Secret")

	floor.StartId = startId
	floor.DescentId = descentId
	floor.SecretId = secretId

	local mainPath = Graph.Path(adjAll, startId, descentId) or { startId, descentId }
	floor.MainPath = mainPath
	local onMain: { [string]: number } = {}
	for i, id in mainPath do
		onMain[id] = i
	end

	-- Layer 2: room composition ------------------------------------------
	local assigned: { [string]: string } = {
		[startId] = "Antechamber",
		[descentId] = "Stairwell",
		[secretId] = "Secret",
	}
	local function free(id: string): boolean
		return assigned[id] == nil
	end

	local nonSecret = function(e)
		return e.Kind ~= "Secret"
	end

	-- Vault: a leaf of the non-secret graph.
	local leaves = {}
	for _, id in mainIds do
		if free(id) and Graph.Degree(floor.Connections, id, nonSecret) == 1 and id ~= secretHost then
			table.insert(leaves, id)
		end
	end
	local vaultId: string? = nil
	if #leaves > 0 then
		vaultId = roles:Pick(leaves)
		assigned[vaultId :: string] = "Vault"
		for _, c in floor.Connections do
			if c.Kind == "Open" and (c.A == vaultId or c.B == vaultId) then
				c.Kind = "VaultDoor"
			end
		end
	end
	floor.VaultId = vaultId

	-- Key: far from the vault, never on the start room.
	local keyId: string? = nil
	if vaultId then
		local adjNoVault = Graph.Adjacency(floor.Connections, nonSecret)
		local dv = Graph.BFS(adjNoVault, vaultId)
		local bestD, opts = -1, {}
		for _, id in mainIds do
			if id ~= vaultId and id ~= startId and id ~= descentId and dv[id] then
				if dv[id] > bestD then
					bestD, opts = dv[id], { id }
				elseif dv[id] == bestD then
					table.insert(opts, id)
				end
			end
		end
		if #opts > 0 then
			keyId = roles:Pick(opts)
		end
	end
	floor.KeyRoomId = keyId

	-- Landmark: middle of the main route when possible.
	local landmarkId: string? = nil
	local mid = mainPath[math.max(2, math.ceil(#mainPath / 2))]
	if mid and free(mid) then
		landmarkId = mid
	else
		local opts = {}
		for _, id in mainIds do
			if free(id) then
				table.insert(opts, id)
			end
		end
		if #opts > 0 then
			landmarkId = roles:Pick(opts)
		end
	end
	if landmarkId then
		assigned[landmarkId] = roles:Pick({ "Machine", "Cistern" })
	end
	floor.LandmarkId = landmarkId

	-- Shrine: off the main route if possible.
	do
		local branch, any = {}, {}
		for _, id in mainIds do
			if free(id) then
				table.insert(any, id)
				if not onMain[id] then
					table.insert(branch, id)
				end
			end
		end
		local pool = if #branch > 0 then branch else any
		if #pool > 0 then
			local sid = roles:Pick(pool)
			assigned[sid] = "Shrine"
			floor.ShrineId = sid
		end
	end

	-- Camp: rare evidence of another explorer.
	if depth >= 2 and roles:Chance(0.45) then
		local pool = {}
		for _, id in mainIds do
			if free(id) and not onMain[id] then
				table.insert(pool, id)
			end
		end
		if #pool > 0 then
			local cid = roles:Pick(pool)
			assigned[cid] = "Camp"
			floor.CampId = cid
		end
	end

	-- Floor one teaching beats on the main route: bell room, then listener hall.
	if depth == 1 then
		local hallIdx = math.min(#mainPath - 1, 3)
		local hall = mainPath[hallIdx]
		if hall and free(hall) then
			assigned[hall] = "Hall"
		end
	end

	-- Filler archetypes.
	local filler: { [string]: number } = {}
	for id, def in RoomDefs do
		if def.Weight > 0 and def.MinDepth <= depth then
			filler[id] = def.Weight
		end
	end
	for _, id in floor.RoomOrder do
		if free(id) then
			local pick = roles:Weighted(filler) or "Hall"
			-- Keep junctions off the floor-one start's doorstep: the first rooms should read.
			if pick == "Junction" and depth == 1 and onMain[id] and onMain[id] <= 2 then
				pick = "Gallery"
			end
			assigned[id] = pick
		end
	end
	for id, arch in assigned do
		floor.Rooms[id].Archetype = arch
		floor.Rooms[id].Tags = table.clone(RoomDefs[arch].Tags)
	end

	-- Gates for the Tolling rule: only on loop edges, alternating phases,
	-- validated so every room stays reachable in both phases.
	if ruleId == "Tolling" then
		local gateCandidates = {}
		for _, c in floor.Connections do
			if c.Kind == "Open" and c.A ~= startId and c.B ~= startId and not Graph.IsBridge(floor.Connections, c, nonSecret) then
				table.insert(gateCandidates, c)
			end
		end
		layout:Shuffle(gateCandidates)
		local phase = 0
		local placed = 0
		for _, c in gateCandidates do
			if placed >= 3 then
				break
			end
			c.Kind = "Gate"
			c.OpenInPhase = phase
			if Validator.AllReachableInPhases(floor) then
				placed += 1
				phase = 1 - phase
			else
				c.Kind = "Open"
				c.OpenInPhase = nil
			end
		end
	end

	-- Geometry: room rectangles inside their slots, then corridors.
	for _, id in floor.RoomOrder do
		local r = floor.Rooms[id]
		local w = sizeFor(layout, r.Archetype)
		local d = if r.Archetype == "Junction" then w else sizeFor(layout, r.Archetype)
		local margin = 8
		local slotX, slotZ = r.Gx * Grid.SlotSize, r.Gy * Grid.SlotSize
		local x0 = slotX + margin + 2 * layout:Int(0, math.floor((Grid.SlotSize - 2 * margin - w) / 2))
		local z0 = slotZ + margin + 2 * layout:Int(0, math.floor((Grid.SlotSize - 2 * margin - d) / 2))
		r.Rect = { X0 = x0, Z0 = z0, X1 = x0 + w, Z1 = z0 + d }
		r.Center = Vector2.new(x0 + w / 2, z0 + d / 2)
	end
	for _, c in floor.Connections do
		buildCorridor(layout, c, floor.Rooms[c.A], floor.Rooms[c.B])
	end

	-- Layer 3: encounters -------------------------------------------------
	local startDist = Graph.BFS(Graph.Adjacency(floor.Connections, nonSecret), startId)
	local listeners = if depth == 1 then 1 elseif depth <= 3 then 2 else 3
	if depth >= 5 and #mainIds >= 15 then
		listeners += 1
	end
	local watchers = if depth == 1 then 0 elseif depth <= 3 then 1 else 2

	local creatureRooms: { [string]: boolean } = {}
	local function eligible(id: string): boolean
		local r = floor.Rooms[id]
		return RoomDefs[r.Archetype].CanHoldCreature and not creatureRooms[id] and (startDist[id] or 0) >= 2
	end
	local function placeCreature(kind: string, id: string)
		creatureRooms[id] = true
		local r = floor.Rooms[id]
		local pos = r.Center
		if kind == "Watcher" then
			local rect = r.Rect
			pos = Vector2.new(
				encounters:Float(rect.X0 + 5, rect.X1 - 5),
				encounters:Float(rect.Z0 + 5, rect.Z1 - 5)
			)
		end
		table.insert(floor.Encounters, { Kind = kind, RoomId = id, Pos = pos })
	end

	if depth == 1 then
		local hall = mainPath[math.min(#mainPath - 1, 3)]
		if hall and floor.Rooms[hall].Archetype == "Hall" then
			placeCreature("Listener", hall)
			listeners -= 1
		end
	end
	local pool = {}
	for _, id in floor.RoomOrder do
		table.insert(pool, id)
	end
	encounters:Shuffle(pool)
	for _, id in pool do
		if listeners <= 0 then
			break
		end
		if eligible(id) then
			placeCreature("Listener", id)
			listeners -= 1
		end
	end
	creatureRooms = {} -- watchers may share rooms with listeners
	for _, e in floor.Encounters do
		if e.Kind == "Watcher" then
			creatureRooms[e.RoomId] = true
		end
	end
	encounters:Shuffle(pool)
	for _, id in pool do
		if watchers <= 0 then
			break
		end
		if eligible(id) then
			placeCreature("Watcher", id)
			watchers -= 1
		end
	end

	-- Items ---------------------------------------------------------------
	local function placeItem(itemId: string, id: string, pos: Vector2?)
		local r = floor.Rooms[id]
		table.insert(floor.Items, {
			ItemId = itemId,
			RoomId = id,
			Pos = pos or wallSpot(itemStream, r.Rect, 4),
		})
	end

	local itemRooms = {}
	for _, id in floor.RoomOrder do
		local r = floor.Rooms[id]
		local def = RoomDefs[r.Archetype]
		if def.CanHoldItems and id ~= startId and id ~= vaultId and id ~= secretId and id ~= floor.CampId then
			table.insert(itemRooms, id)
		end
	end
	itemStream:Shuffle(itemRooms)
	local nextRoom = 0
	local function anyRoom(): string
		nextRoom = (nextRoom % #itemRooms) + 1
		return itemRooms[nextRoom]
	end

	if depth == 1 then
		local sr0 = floor.Rooms[startId].Rect
		placeItem("OilFlask", startId, Vector2.new(sr0.X0 + 6, sr0.Z1 - 6))
		local bellRoom = mainPath[2]
		if bellRoom == descentId then
			bellRoom = startId
		end
		placeItem("TinBell", bellRoom)
	elseif itemStream:Chance(0.5) then
		placeItem("TinBell", anyRoom())
	end

	local flasks = 2 + (if depth >= 3 then 1 else 0)
	for _ = 1, flasks do
		placeItem("OilFlask", anyRoom())
	end
	placeItem("Tincture", anyRoom())

	if keyId then
		placeItem("RustedKey", keyId)
	end
	if vaultId then
		local vr = floor.Rooms[vaultId]
		placeItem("Tincture", vaultId)
		placeItem("OilFlask", vaultId)
		placeItem("Curio", vaultId, vr.Center)
	end
	do
		local srr = floor.Rooms[secretId]
		placeItem("Curio", secretId, srr.Center)
		placeItem(if itemStream:Chance(0.5) then "Tincture" else "OilFlask", secretId)
	end
	if floor.CampId then
		placeItem("OilFlask", floor.CampId)
		table.insert(floor.Notes, { RoomId = floor.CampId, Text = itemStream:Pick(CAMP_NOTES) })
	end
	for _, it in floor.Items do
		if it.ItemId == "Curio" then
			it.Name = itemStream:Pick(CURIOS)
		end
	end

	-- Braziers ------------------------------------------------------------
	local litChance = if ruleId == "HungryDark" then 0.15 else 0.5
	for _, id in floor.RoomOrder do
		local r = floor.Rooms[id]
		local rect = r.Rect
		local count = 0
		local arch = r.Archetype
		if arch == "Hall" or arch == "Machine" or arch == "Cistern" then
			count = 2
		elseif arch == "Gallery" or arch == "Storeroom" or arch == "Overgrown" then
			count = if layout:Chance(0.6) then 1 else 0
		elseif arch == "Antechamber" then
			count = 2
		end
		local corners = {
			Vector2.new(rect.X0 + 4, rect.Z0 + 4),
			Vector2.new(rect.X1 - 4, rect.Z1 - 4),
			Vector2.new(rect.X1 - 4, rect.Z0 + 4),
			Vector2.new(rect.X0 + 4, rect.Z1 - 4),
		}
		for i = 1, count do
			local lit = layout:Chance(litChance)
			if arch == "Antechamber" then
				lit = true
			end
			table.insert(floor.Braziers, { RoomId = id, Pos = corners[i], Lit = lit, Id = id .. "_b" .. i })
		end
	end

	-- Draft: every room knows which of its doors leads toward the descent.
	do
		local adj = Graph.Adjacency(floor.Connections, nonSecret)
		local _, parentEdge = Graph.BFS(adj, descentId)
		for id, e in parentEdge do
			floor.Rooms[id].DraftConn = e.Id
		end
		for _, c in floor.Connections do
			if c.Kind == "Secret" then
				floor.SecretConn = c.Id
			end
		end
	end

	return floor
end

-- Generates, validates and (deterministically) regenerates on failure.
function FloorGenerator.Generate(runSeed: number, depth: number)
	local lastReason = "unknown"
	for attempt = 0, 12 do
		local ok, floorOrErr = pcall(generateOnce, runSeed, depth, attempt)
		if ok then
			local valid, reason = Validator.Validate(floorOrErr)
			if valid then
				return floorOrErr
			end
			lastReason = reason or "invalid"
		else
			lastReason = tostring(floorOrErr)
		end
		warn(string.format("[Generation] seed=%d depth=%d attempt=%d rejected: %s", runSeed, depth, attempt, lastReason))
	end
	error(string.format("[Generation] seed=%d depth=%d could not produce a valid floor: %s", runSeed, depth, lastReason))
end

return FloorGenerator
