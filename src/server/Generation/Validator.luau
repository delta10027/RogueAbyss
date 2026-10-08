--!strict
-- Validation of a LogicalFloor (TECH_ARCHITECTURE §9).
-- Returns (ok, reason). Never mutates the floor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Graph = require(script.Parent.Graph)

local Grid = Config.Grid

local Validator = {}

-- Edge passability for a given gate phase. Vault doors count as passable
-- here because reachability of the vault itself is checked separately.
local function passableIn(phase: number)
	return function(e): boolean
		if e.Kind == "Secret" then
			return false
		elseif e.Kind == "Gate" then
			return e.OpenInPhase == phase
		end
		return true
	end
end

function Validator.AllReachableInPhases(floor): boolean
	for phase = 0, 1 do
		local adj = Graph.Adjacency(floor.Connections, passableIn(phase))
		local dist = Graph.BFS(adj, floor.StartId)
		for _, id in floor.RoomOrder do
			if id ~= floor.SecretId and dist[id] == nil then
				return false
			end
		end
	end
	return true
end

type Box = { X0: number, Z0: number, X1: number, Z1: number }

local function overlaps(a: Box, b: Box): boolean
	return a.X0 < b.X1 and b.X0 < a.X1 and a.Z0 < b.Z1 and b.Z0 < a.Z1
end

local function shrink(b: Box, by: number): Box
	return { X0 = b.X0 + by, Z0 = b.Z0 + by, X1 = b.X1 - by, Z1 = b.Z1 - by }
end

-- Axis-aligned boxes covering each corridor segment.
function Validator.CorridorBoxes(conn): { Box }
	local boxes = {}
	local hw = Grid.CorridorWidth / 2
	for i = 1, #conn.Points - 1 do
		local p, q = conn.Points[i], conn.Points[i + 1]
		table.insert(boxes, {
			X0 = math.min(p.X, q.X) - hw,
			Z0 = math.min(p.Y, q.Y) - hw,
			X1 = math.max(p.X, q.X) + hw,
			Z1 = math.max(p.Y, q.Y) + hw,
		})
	end
	return boxes
end

function Validator.Validate(floor): (boolean, string?)
	local rooms = floor.Rooms
	if not rooms[floor.StartId] or not rooms[floor.DescentId] then
		return false, "missing start or descent"
	end
	if floor.StartId == floor.DescentId then
		return false, "start equals descent"
	end

	local adj = Graph.Adjacency(floor.Connections, passableIn(0))
	local dist = Graph.BFS(adj, floor.StartId)
	if (dist[floor.DescentId] or 0) < 2 then
		return false, "descent too close to start"
	end
	if not Validator.AllReachableInPhases(floor) then
		return false, "unreachable room in a gate phase"
	end

	-- The secret room must be reachable through its secret connection only.
	local secretLinks = 0
	for _, c in floor.Connections do
		if c.A == floor.SecretId or c.B == floor.SecretId then
			if c.Kind ~= "Secret" then
				return false, "secret room has a non-secret connection"
			end
			secretLinks += 1
		end
	end
	if secretLinks ~= 1 then
		return false, "secret room link count " .. secretLinks
	end

	if floor.VaultId and Graph.Degree(floor.Connections, floor.VaultId) ~= 1 then
		return false, "vault is not a leaf"
	end
	if floor.VaultId and not floor.KeyRoomId then
		return false, "vault without key"
	end
	if floor.KeyRoomId and floor.KeyRoomId == floor.VaultId then
		return false, "key inside its own vault"
	end

	if floor.Depth == 1 and Graph.Degree(floor.Connections, floor.StartId, passableIn(0)) < 3 then
		return false, "floor-one antechamber needs three exits"
	end

	-- Geometry.
	local S = Grid.SlotSize
	for _, id in floor.RoomOrder do
		local r = rooms[id]
		if not r.Rect then
			return false, "room without rect " .. id
		end
		local slot = { X0 = r.Gx * S, Z0 = r.Gy * S, X1 = (r.Gx + 1) * S, Z1 = (r.Gy + 1) * S }
		if r.Rect.X0 < slot.X0 or r.Rect.Z0 < slot.Z0 or r.Rect.X1 > slot.X1 or r.Rect.Z1 > slot.Z1 then
			return false, "room outside slot " .. id
		end
		if r.Archetype == "" then
			return false, "room without archetype " .. id
		end
	end

	local allBoxes = {}
	for _, c in floor.Connections do
		if #c.Points < 2 then
			return false, "corridor without points " .. c.Id
		end
		for _, box in Validator.CorridorBoxes(c) do
			for _, id in floor.RoomOrder do
				if id ~= c.A and id ~= c.B and overlaps(shrink(box, 0.5), rooms[id].Rect) then
					return false, string.format("corridor %s crosses room %s", c.Id, id)
				end
			end
			table.insert(allBoxes, { Box = box, Conn = c.Id })
		end
	end
	for i = 1, #allBoxes do
		for j = i + 1, #allBoxes do
			local a, b = allBoxes[i], allBoxes[j]
			if a.Conn ~= b.Conn and overlaps(shrink(a.Box, 0.5), shrink(b.Box, 0.5)) then
				return false, string.format("corridors %s and %s overlap", a.Conn, b.Conn)
			end
		end
	end

	for _, it in floor.Items do
		local rect = rooms[it.RoomId].Rect
		if it.Pos.X < rect.X0 or it.Pos.X > rect.X1 or it.Pos.Y < rect.Z0 or it.Pos.Y > rect.Z1 then
			return false, "item outside its room"
		end
	end

	local listeners = 0
	for _, e in floor.Encounters do
		if e.RoomId == floor.StartId or e.RoomId == floor.ShrineId then
			return false, "creature in a safe room"
		end
		if e.Kind == "Listener" then
			listeners += 1
		end
	end
	if listeners == 0 then
		return false, "no listener placed"
	end

	return true, nil
end

return Validator
