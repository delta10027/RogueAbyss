--!strict
-- Room archetype definitions. GenerationService chooses archetypes from this
-- data; FloorBuilder dresses them. Nothing here touches Instances.

export type RoomDef = {
	Id: string,
	Family: "OldStone" | "ImpossibleRepair" | "BuriedMachine" | "ForgottenShrine" | "LivingPassage",
	Tags: { string },
	Weight: number, -- weight in the general filler pool (0 = only placed explicitly)
	MinDepth: number,
	MinSize: number?, -- override of Config.Grid.MinRoom
	CanHoldCreature: boolean,
	CanHoldItems: boolean,
}

local Rooms: { [string]: RoomDef } = {
	Antechamber = { Id = "Antechamber", Family = "ForgottenShrine", Tags = { "Start", "Safe" },
		Weight = 0, MinDepth = 1, MinSize = 32, CanHoldCreature = false, CanHoldItems = true },
	Stairwell = { Id = "Stairwell", Family = "OldStone", Tags = { "Descent" },
		Weight = 0, MinDepth = 1, MinSize = 28, CanHoldCreature = false, CanHoldItems = false },
	Hall = { Id = "Hall", Family = "OldStone", Tags = { "Combat", "Exploration" },
		Weight = 3, MinDepth = 1, MinSize = 32, CanHoldCreature = true, CanHoldItems = true },
	Storeroom = { Id = "Storeroom", Family = "ImpossibleRepair", Tags = { "Exploration" },
		Weight = 2, MinDepth = 1, CanHoldCreature = true, CanHoldItems = true },
	Gallery = { Id = "Gallery", Family = "OldStone", Tags = { "Exploration" },
		Weight = 2, MinDepth = 1, MinSize = 28, CanHoldCreature = true, CanHoldItems = true },
	Overgrown = { Id = "Overgrown", Family = "LivingPassage", Tags = { "Exploration" },
		Weight = 1.2, MinDepth = 2, CanHoldCreature = true, CanHoldItems = true },
	Junction = { Id = "Junction", Family = "OldStone", Tags = { "Corridor" },
		Weight = 1.2, MinDepth = 1, CanHoldCreature = false, CanHoldItems = false },
	Shrine = { Id = "Shrine", Family = "ForgottenShrine", Tags = { "Safe", "Rest" },
		Weight = 0, MinDepth = 1, MinSize = 28, CanHoldCreature = false, CanHoldItems = false },
	Machine = { Id = "Machine", Family = "BuriedMachine", Tags = { "Landmark" },
		Weight = 0, MinDepth = 1, MinSize = 40, CanHoldCreature = true, CanHoldItems = true },
	Cistern = { Id = "Cistern", Family = "OldStone", Tags = { "Landmark" },
		Weight = 0, MinDepth = 1, MinSize = 40, CanHoldCreature = true, CanHoldItems = true },
	Vault = { Id = "Vault", Family = "BuriedMachine", Tags = { "Vault" },
		Weight = 0, MinDepth = 1, CanHoldCreature = false, CanHoldItems = true },
	Camp = { Id = "Camp", Family = "ImpossibleRepair", Tags = { "Rare", "Story" },
		Weight = 0, MinDepth = 2, CanHoldCreature = false, CanHoldItems = true },
	Secret = { Id = "Secret", Family = "ForgottenShrine", Tags = { "Secret" },
		Weight = 0, MinDepth = 1, CanHoldCreature = false, CanHoldItems = true },
}

return Rooms
