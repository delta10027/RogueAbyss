--!strict
-- Grants knowledge. A discovery is recorded once per player forever, and
-- also once per run for the run summary.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Discoveries = require(ReplicatedStorage:WaitForChild("Shared").Definitions.Discoveries)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DiscoveryService = {}

local S: any

function DiscoveryService.Init(registry)
	S = registry
end

function DiscoveryService.Knows(player: Player, id: string): boolean
	return S.PersistenceService.Get(player).Discoveries[id] == true
end

-- Returns true if this was new knowledge for the player.
function DiscoveryService.Discover(player: Player, id: string): boolean
	local def = Discoveries.ById[id]
	if not def then
		warn("[Discovery] unknown id " .. id)
		return false
	end
	local run = S.RunDirector.GetRun(player)
	if run and not run.Stats.Discovered[id] then
		run.Stats.Discovered[id] = true
		table.insert(run.Stats.DiscoveryOrder, id)
	end
	local data = S.PersistenceService.Get(player)
	if data.Discoveries[id] then
		return false
	end
	data.Discoveries[id] = true
	S.PersistenceService.MarkDirty(player)
	Remotes.Notice:FireClient(player, { Kind = "Discovery", Id = id, Title = def.Title, Text = def.Text })
	S.PlayerStateService.Push(player)
	return true
end

function DiscoveryService.KnownList(player: Player): { string }
	local list = {}
	for id in S.PersistenceService.Get(player).Discoveries do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

return DiscoveryService
