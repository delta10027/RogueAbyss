--!strict
-- Small pure graph helpers over the logical floor (rooms + connections).

local Graph = {}

export type Edge = { Id: string, A: string, B: string, Kind: string, OpenInPhase: number? }

-- Builds an adjacency list. `passable(edge)` decides whether an edge counts.
function Graph.Adjacency(edges: { Edge }, passable: ((Edge) -> boolean)?): { [string]: { { To: string, Edge: Edge } } }
	local adj: { [string]: { { To: string, Edge: Edge } } } = {}
	for _, e in edges do
		if passable == nil or passable(e) then
			adj[e.A] = adj[e.A] or {}
			adj[e.B] = adj[e.B] or {}
			table.insert(adj[e.A], { To = e.B, Edge = e })
			table.insert(adj[e.B], { To = e.A, Edge = e })
		end
	end
	return adj
end

-- Breadth-first distances from `from`. Returns dist map and parent-edge map.
function Graph.BFS(adj: { [string]: { { To: string, Edge: Edge } } }, from: string)
	local dist: { [string]: number } = { [from] = 0 }
	local parentEdge: { [string]: Edge } = {}
	local queue = { from }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		local list = adj[cur]
		if list then
			for _, link in list do
				if dist[link.To] == nil then
					dist[link.To] = dist[cur] + 1
					parentEdge[link.To] = link.Edge
					table.insert(queue, link.To)
				end
			end
		end
	end
	return dist, parentEdge
end

-- Returns the list of room ids on the shortest path from `from` to `to`.
function Graph.Path(adj: { [string]: { { To: string, Edge: Edge } } }, from: string, to: string): { string }?
	local dist, parentEdge = Graph.BFS(adj, from)
	if dist[to] == nil then
		return nil
	end
	local path = { to }
	local cur = to
	while cur ~= from do
		local e = parentEdge[cur]
		cur = if e.A == cur then e.B else e.A
		table.insert(path, 1, cur)
	end
	return path
end

function Graph.Degree(edges: { Edge }, id: string, passable: ((Edge) -> boolean)?): number
	local n = 0
	for _, e in edges do
		if (e.A == id or e.B == id) and (passable == nil or passable(e)) then
			n += 1
		end
	end
	return n
end

-- True if removing `edge` disconnects its endpoints (within the passable set).
function Graph.IsBridge(edges: { Edge }, edge: Edge, passable: ((Edge) -> boolean)?): boolean
	local adj = Graph.Adjacency(edges, function(e)
		return e ~= edge and (passable == nil or passable(e))
	end)
	local dist = Graph.BFS(adj, edge.A)
	return dist[edge.B] == nil
end

return Graph
