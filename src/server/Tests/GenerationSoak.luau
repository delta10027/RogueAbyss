--!strict
-- Procedural soak test: generates many floors, validates each, and checks
-- that generation is deterministic. Run from the command bar / MCP:
--   require(game.ServerScriptService.Server.Tests.GenerationSoak)(200)

local FloorGenerator = require(script.Parent.Parent.Generation.FloorGenerator)
local Validator = require(script.Parent.Parent.Generation.Validator)

local function fingerprint(floor): string
	local parts = { floor.RuleId, floor.StartId, floor.DescentId, tostring(floor.SecretId), tostring(floor.VaultId) }
	for _, id in floor.RoomOrder do
		local r = floor.Rooms[id]
		table.insert(parts, string.format("%s:%s:%d,%d,%d,%d", id, r.Archetype, r.Rect.X0, r.Rect.Z0, r.Rect.X1, r.Rect.Z1))
	end
	for _, c in floor.Connections do
		table.insert(parts, c.Id .. c.Kind .. #c.Points)
	end
	for _, e in floor.Encounters do
		table.insert(parts, e.Kind .. e.RoomId)
	end
	for _, it in floor.Items do
		table.insert(parts, it.ItemId .. it.RoomId)
	end
	return table.concat(parts, "|")
end

return function(seedCount: number?, maxDepth: number?)
	local n = seedCount or 100
	local depthLimit = maxDepth or 7
	local stats = { Floors = 0, Failures = 0, Retries = 0, NonDeterministic = 0, Rules = {} :: { [string]: number }, Archetypes = {} :: { [string]: number } }
	local failures = {}
	for seed = 1, n do
		for depth = 1, depthLimit do
			local ok, floor = pcall(FloorGenerator.Generate, seed * 7919, depth)
			stats.Floors += 1
			if not ok then
				stats.Failures += 1
				table.insert(failures, string.format("seed=%d depth=%d %s", seed * 7919, depth, tostring(floor)))
			else
				local valid, reason = Validator.Validate(floor)
				if not valid then
					stats.Failures += 1
					table.insert(failures, string.format("seed=%d depth=%d post-validate %s", seed * 7919, depth, tostring(reason)))
				end
				if floor.Attempt > 0 then
					stats.Retries += 1
				end
				local again = FloorGenerator.Generate(seed * 7919, depth)
				if fingerprint(again) ~= fingerprint(floor) then
					stats.NonDeterministic += 1
				end
				stats.Rules[floor.RuleId] = (stats.Rules[floor.RuleId] or 0) + 1
				for _, id in floor.RoomOrder do
					local a = floor.Rooms[id].Archetype
					stats.Archetypes[a] = (stats.Archetypes[a] or 0) + 1
				end
			end
		end
	end
	return stats, failures
end
