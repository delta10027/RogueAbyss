--!strict
-- ServerMain: requires every service, wires them through a shared registry,
-- then starts them. Services reference each other through the registry at
-- call time, which avoids circular requires.

local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")

local Services = script:WaitForChild("Services")

pcall(function()
	PhysicsService:RegisterCollisionGroup("Debris")
	PhysicsService:RegisterCollisionGroup("Creature")
	PhysicsService:RegisterCollisionGroup("Player")
	PhysicsService:CollisionGroupSetCollidable("Debris", "Player", false)
	PhysicsService:CollisionGroupSetCollidable("Debris", "Creature", false)
	PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)
end)

-- The dungeon is the only ground. Remove template leftovers.
for _, name in { "Baseplate", "SpawnLocation" } do
	local leftover = Workspace:FindFirstChild(name)
	if leftover then
		leftover:Destroy()
	end
end

local order = {
	"PersistenceService",
	"DiscoveryService",
	"DungeonService",
	"PlayerStateService",
	"LightService",
	"NoiseService",
	"CreatureService",
	"RulesService",
	"ItemService",
	"CombatService",
	"ProgressionService",
	"SpellService",
	"InteractionService",
	"RunDirector",
	"DebugService",
}

local registry: { [string]: any } = {}
for _, name in order do
	registry[name] = require(Services:WaitForChild(name)) :: any
end
for _, name in order do
	local svc = registry[name]
	if svc.Init then
		svc.Init(registry)
	end
end
for _, name in order do
	local svc = registry[name]
	if svc.Start then
		task.spawn(svc.Start)
	end
end

print("[RogueAbyss] server ready")
