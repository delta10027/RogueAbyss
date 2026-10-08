--!strict
-- Owns active floors: generation calls, building, unloading, and the
-- per-player world slot each run occupies. Contains no generation logic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Server = script.Parent.Parent
local FloorGenerator = require(Server.Generation.FloorGenerator)
local FloorBuilder = require(Server.Builder.FloorBuilder)

local DungeonService = {}

local root: Folder
local slotsInUse: { [number]: boolean } = {}

function DungeonService.Init(_registry)
	root = Instance.new("Folder")
	root.Name = "Dungeon"
	root.Parent = Workspace
end

function DungeonService.AcquireSlot(): number
	local i = 0
	while slotsInUse[i] do
		i += 1
	end
	slotsInUse[i] = true
	return i
end

function DungeonService.ReleaseSlot(slot: number)
	slotsInUse[slot] = nil
end

function DungeonService.OriginFor(slot: number): Vector3
	return Vector3.new(slot * Config.Grid.RunSpacing, Config.Grid.FloorY, 0)
end

-- Generates and builds a floor. Returns (logicalFloor, built).
function DungeonService.CreateFloor(seed: number, depth: number, slot: number, owner: Player)
	local floor = FloorGenerator.Generate(seed, depth)
	local holder = Instance.new("Folder")
	holder.Name = string.format("Run_%s", owner.Name)
	holder.Parent = root
	local built = FloorBuilder.Build(floor, DungeonService.OriginFor(slot), holder)
	built.Holder = holder
	if Config.Debug then
		print(string.format("[Dungeon] %s depth %d seed %d rule %s rooms %d (attempt %d)",
			owner.Name, depth, seed, floor.RuleId, #floor.RoomOrder, floor.Attempt))
	end
	return floor, built
end

-- Old floors never stay in Workspace (TECH_ARCHITECTURE §21).
function DungeonService.Unload(built)
	if built and built.Holder then
		built.Holder:Destroy()
	end
end

DungeonService.RoomAt = FloorBuilder.RoomAt

return DungeonService
