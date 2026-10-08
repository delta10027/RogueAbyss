--!strict
-- Creature navigation over the logical floor graph. Because rooms are
-- convex and corridors are known polylines, routes are cheap to compute
-- and never need PathfindingService: room -> door -> corridor -> door -> room.

local Graph = require(script.Parent.Parent.Generation.Graph)
local FloorBuilder = require(script.Parent.Parent.Builder.FloorBuilder)

local Nav = {}

type Location = { Room: string?, Conn: any?, Seg: number?, Proj: Vector3? }

local function toWorld(built, v: Vector2, y: number?): Vector3
	return built.Origin + Vector3.new(v.X, y or 0, v.Y)
end

local function closestOnSegment(p: Vector3, a: Vector3, b: Vector3): (Vector3, number)
	local ab = b - a
	local len2 = ab:Dot(ab)
	local t = if len2 > 0 then math.clamp((p - a):Dot(ab) / len2, 0, 1) else 0
	local q = a + ab * t
	return q, (Vector3.new(p.X, 0, p.Z) - Vector3.new(q.X, 0, q.Z)).Magnitude
end

function Nav.Locate(built, pos: Vector3): Location?
	local room = FloorBuilder.RoomAt(built, pos, 0.5)
	if room then
		return { Room = room }
	end
	local best, bestD, bestSeg, bestProj = nil, 7, nil, nil
	for _, c in built.Floor.Connections do
		for i = 1, #c.Points - 1 do
			local a, b = toWorld(built, c.Points[i]), toWorld(built, c.Points[i + 1])
			local q, d = closestOnSegment(pos, a, b)
			if d < bestD then
				best, bestD, bestSeg, bestProj = c, d, i, q
			end
		end
	end
	if best then
		return { Conn = best, Seg = bestSeg, Proj = bestProj }
	end
	return nil
end

-- Whether a creature may pass through a connection right now.
function Nav.Passable(built, c): boolean
	if c.Kind == "Gate" then
		local g = built.Gates[c.Id]
		return g ~= nil and g.IsOpen()
	elseif c.Kind == "VaultDoor" then
		local v = built.VaultDoors[c.Id]
		return v ~= nil and v.Opened
	elseif c.Kind == "Secret" then
		local k = built.Cracked[c.Id]
		return k ~= nil and k.Broken
	end
	local wd = built.WoodDoors[c.Id]
	if wd and not wd.Opened then
		return false
	end
	return true
end

-- Corridor points from room `fromRoom`'s door to the other end.
local function corridorPoints(built, c, fromRoom: string): { Vector3 }
	local pts = {}
	for _, p in c.Points do
		table.insert(pts, toWorld(built, p))
	end
	if c.A ~= fromRoom then
		local rev = {}
		for i = #pts, 1, -1 do
			table.insert(rev, pts[i])
		end
		pts = rev
	end
	return pts
end

local function traverse(built, c, fromRoom: string, out: { Vector3 })
	local toRoom = if c.A == fromRoom then c.B else c.A
	local exit = built.DoorPositions[fromRoom .. ":" .. c.Id]
	local entry = built.DoorPositions[toRoom .. ":" .. c.Id]
	table.insert(out, exit.Inside - exit.Outward * 2.5)
	table.insert(out, exit.Inside)
	for _, p in corridorPoints(built, c, fromRoom) do
		table.insert(out, p)
	end
	table.insert(out, entry.Inside)
	table.insert(out, entry.Inside - entry.Outward * 2.5)
end

-- Room-level path avoiding `forbidden` rooms (e.g. shrines).
local function roomPath(built, from: string, to: string, forbidden: { [string]: boolean }?): { string }?
	local adj = Graph.Adjacency(built.Floor.Connections, function(c)
		if not Nav.Passable(built, c) then
			return false
		end
		if forbidden and ((forbidden[c.A] and c.A ~= from and c.A ~= to) or (forbidden[c.B] and c.B ~= from and c.B ~= to)) then
			return false
		end
		return true
	end)
	return Graph.Path(adj, from, to)
end

local function connBetween(built, a: string, b: string)
	for _, c in built.Floor.Connections do
		if ((c.A == a and c.B == b) or (c.A == b and c.B == a)) and Nav.Passable(built, c) then
			return c
		end
	end
	return nil
end

-- Points walking along a corridor from its `endRoom` side to a projected point.
local function corridorPartial(built, c, endRoom: string, seg: number, proj: Vector3): { Vector3 }
	local pts = corridorPoints(built, c, endRoom)
	local n = #c.Points
	-- Segment index in the direction we walk.
	local idx = if c.A == endRoom then seg else (n - seg)
	local out = {}
	for i = 1, idx do
		table.insert(out, pts[i])
	end
	table.insert(out, proj)
	return out
end

-- Returns waypoints from `fromPos` to `toPos`, or nil if unreachable.
function Nav.Route(built, fromPos: Vector3, toPos: Vector3, forbidden: { [string]: boolean }?): { Vector3 }?
	local a = Nav.Locate(built, fromPos)
	local b = Nav.Locate(built, toPos)
	if not a or not b then
		return nil
	end
	-- Same space: walk straight.
	if (a.Room and a.Room == b.Room) or (a.Conn and b.Conn and a.Conn == b.Conn) then
		return { toPos }
	end

	local startRooms: { { Room: string, Prefix: { Vector3 } } } = {}
	if a.Room then
		table.insert(startRooms, { Room = a.Room, Prefix = {} })
	else
		local c = a.Conn
		for _, endRoom in { c.A, c.B } do
			-- Walk back along the corridor toward `endRoom`.
			local partial = corridorPartial(built, c, endRoom, a.Seg :: number, a.Proj :: Vector3)
			local back = {}
			for i = #partial - 1, 1, -1 do
				table.insert(back, partial[i])
			end
			local door = built.DoorPositions[endRoom .. ":" .. c.Id]
			table.insert(back, door.Inside - door.Outward * 2.5)
			table.insert(startRooms, { Room = endRoom, Prefix = back })
		end
	end

	local endRooms: { { Room: string, Suffix: { Vector3 } } } = {}
	if b.Room then
		table.insert(endRooms, { Room = b.Room, Suffix = { toPos } })
	else
		local c = b.Conn
		for _, endRoom in { c.A, c.B } do
			local door = built.DoorPositions[endRoom .. ":" .. c.Id]
			local suffix = { door.Inside - door.Outward * 2.5 }
			for _, p in corridorPartial(built, c, endRoom, b.Seg :: number, b.Proj :: Vector3) do
				table.insert(suffix, p)
			end
			table.insert(endRooms, { Room = endRoom, Suffix = suffix })
		end
	end

	local best: { Vector3 }? = nil
	local bestLen = math.huge
	for _, s in startRooms do
		for _, e in endRooms do
			local path = if s.Room == e.Room then { s.Room } else roomPath(built, s.Room, e.Room, forbidden)
			if path and #path < bestLen then
				local out = table.clone(s.Prefix)
				for i = 1, #path - 1 do
					local c = connBetween(built, path[i], path[i + 1])
					if not c then
						out = nil :: any
						break
					end
					traverse(built, c, path[i], out)
				end
				if out then
					for _, p in e.Suffix do
						table.insert(out, p)
					end
					best, bestLen = out, #path
				end
			end
		end
	end
	return best
end

-- Room-graph distance (number of rooms) between two positions; nil if unknown.
function Nav.RoomDistance(built, a: Vector3, b: Vector3): number?
	local la, lb = Nav.Locate(built, a), Nav.Locate(built, b)
	if not la or not lb then
		return nil
	end
	local ra = la.Room or (la.Conn and la.Conn.A)
	local rb = lb.Room or (lb.Conn and lb.Conn.A)
	if not ra or not rb then
		return nil
	end
	if ra == rb then
		return 0
	end
	local path = roomPath(built, ra, rb, nil)
	return path and (#path - 1) or nil
end

return Nav
