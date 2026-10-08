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
	{ Id = "LawDraft", Category = "Law", Order = 1, Title = "The Draft",
		Text = "Dust drifts toward the way down. Follow the moving dust." },
	{ Id = "CreatureListener", Category = "Creature", Order = 10, Title = "The Listener",
		Text = "Blind. Hunts by sound alone. Creeping makes no sound." },
	{ Id = "ListenerLured", Category = "Creature", Order = 11, Title = "A Borrowed Voice",
		Text = "A Listener will chase any sound - even one you threw." },
	{ Id = "CreatureWatcher", Category = "Creature", Order = 12, Title = "The Watcher",
		Text = "Stone while it is seen in light. Keep it in front of you." },
	{ Id = "WatcherLight", Category = "Creature", Order = 13, Title = "Held by Flame",
		Text = "A Watcher standing in firelight cannot move, seen or not." },
	{ Id = "RuleEchoes", Category = "Rule", Order = 20, Title = "The Echoing Halls",
		Text = "Sound travels almost twice as far." },
	{ Id = "RuleHungryDark", Category = "Rule", Order = 21, Title = "The Hungry Dark",
		Text = "Listeners are drawn to flame. Dim the lantern; light a brazier elsewhere." },
	{ Id = "RuleTolling", Category = "Rule", Order = 22, Title = "The Tolling Floor",
		Text = "Marked gates swap when the great bell tolls. Watchers lurch at the toll." },
	{ Id = "BellGate", Category = "Item", Order = 30, Title = "Sympathetic Bell",
		Text = "A rung bell near a marked gate makes it answer early." },
	{ Id = "OilBrazier", Category = "Item", Order = 31, Title = "Kindling",
		Text = "Thrown oil lights a cold brazier." },
	{ Id = "SecretCracks", Category = "Secret", Order = 40, Title = "Hollow Walls",
		Text = "Cracked stone that breathes in the draft can be broken through." },
	{ Id = "PlaceShrine", Category = "Place", Order = 50, Title = "Candle Shrines",
		Text = "Nothing that hunts will cross a shrine threshold. Its water mends once." },
	{ Id = "PlaceMachine", Category = "Place", Order = 51, Title = "The Buried Machine",
		Text = "Its clanking draws the blind. Its lever stills it." },
	{ Id = "PlaceCamp", Category = "Place", Order = 52, Title = "Another Explorer",
		Text = "Someone came down before you. Their lantern is still warm." },
	{ Id = "PlaceVault", Category = "Place", Order = 53, Title = "Iron Doors",
		Text = "Every vault's key lies on the same floor, never behind its own door." },
}

local byId: { [string]: DiscoveryDef } = {}
for _, d in list do
	byId[d.Id] = d
end

return {
	List = list,
	ById = byId,
}
