--!strict
-- Knowledge the player can earn. Persisted per player (PersistenceService).
-- Discoveries are the main form of progression: they are written into the
-- journal, never converted into stats.

export type DiscoveryDef = {
	Id: string,
	Category: "Rule" | "Creature" | "Law" | "Secret" | "Item" | "Place",
	Title: string,
	Text: string,
	Order: number,
}

local list: { DiscoveryDef } = {
	{ Id = "LawDraft", Category = "Law", Order = 1, Title = "Follow the Dust",
		Text = "Dust always drifts toward the stairs down. Follow it when you are lost." },
	{ Id = "CreatureListener", Category = "Creature", Order = 10, Title = "Listener",
		Text = "Blind - it hunts by sound only. Sneaking (hold Shift) makes no sound." },
	{ Id = "ListenerLured", Category = "Creature", Order = 11, Title = "Distracting a Listener",
		Text = "A Listener goes to any loud sound - including a bell you throw." },
	{ Id = "CreatureWatcher", Category = "Creature", Order = 12, Title = "Watcher",
		Text = "A stone statue that can't move while your lantern light is on it. It can't be hurt." },
	{ Id = "WatcherLight", Category = "Creature", Order = 13, Title = "Watchers and Fire",
		Text = "A Watcher standing in firelight can't move, even if you look away." },
	{ Id = "CreatureRat", Category = "Creature", Order = 14, Title = "Giant Rat",
		Text = "Fast and weak. Usually comes in packs of two or three." },
	{ Id = "CreatureKobold", Category = "Creature", Order = 15, Title = "Kobold",
		Text = "A small spear-carrier. Spots you from the edge of your lantern light - dim it to sneak by." },
	{ Id = "CreatureBat", Category = "Creature", Order = 16, Title = "Bat",
		Text = "Flies erratically and is drawn to a bright lantern." },
	{ Id = "CreatureZombie", Category = "Creature", Order = 17, Title = "Zombie",
		Text = "Slow, tough and hits very hard. Step back when it raises its arms." },
	{ Id = "RuleEchoes", Category = "Rule", Order = 20, Title = "Echoing Halls",
		Text = "Sounds travel almost twice as far on this kind of level." },
	{ Id = "RuleHungryDark", Category = "Rule", Order = 21, Title = "Hungry Dark",
		Text = "Listeners are drawn to fire. Dim your lantern, and light a fire elsewhere as bait." },
	{ Id = "RuleTolling", Category = "Rule", Order = 22, Title = "Tolling Bell",
		Text = "Marked gates swap when the great bell rings. Watchers jerk forward on each ring." },
	{ Id = "BellGate", Category = "Item", Order = 30, Title = "Bells and Gates",
		Text = "Ringing a tin bell next to a marked gate makes it swap early." },
	{ Id = "OilBrazier", Category = "Item", Order = 31, Title = "Lighting Braziers",
		Text = "A thrown oil flask lights any brazier it splashes." },
	{ Id = "SecretCracks", Category = "Secret", Order = 40, Title = "Hidden Rooms",
		Text = "A cracked wall with dust drifting into it can be broken with a few hits." },
	{ Id = "PlaceShrine", Category = "Place", Order = 50, Title = "Shrines",
		Text = "Monsters can't enter a candle shrine. Its fountain heals you once." },
	{ Id = "PlaceMachine", Category = "Place", Order = 51, Title = "The Buried Machine",
		Text = "Its clanking attracts Listeners. Pull its lever to stop it." },
	{ Id = "PlaceCamp", Category = "Place", Order = 52, Title = "Abandoned Camp",
		Text = "Another explorer camped here. They usually leave something useful." },
	{ Id = "PlaceVault", Category = "Place", Order = 53, Title = "Iron Vaults",
		Text = "Every vault's rusted key is on the same level, never inside the vault." },
}

local byId: { [string]: DiscoveryDef } = {}
for _, d in list do
	byId[d.Id] = d
end

return {
	List = list,
	ById = byId,
}
