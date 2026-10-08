--!strict
-- Player-facing description of each floor rule. Behaviour lives in
-- ServerScriptService.Server.Rules; this module is safe to replicate.
--
-- Glyph strokes are line segments in a unit square (x right, y down). They
-- are drawn both on the in-world plaque and in the UI so the player can
-- learn to associate the symbol with the rule.

export type RuleInfo = {
	Id: string,
	Name: string,
	Plaque: string, -- shown on the start-room plaque before the rule is known
	Known: string, -- journal text once the rule has been learned
	Glyph: { { number } },
	Reverb: Enum.ReverbType,
}

local FloorRules: { [string]: RuleInfo } = {
	Echoes = {
		Id = "Echoes",
		Name = "Echoing Halls",
		Plaque = "Sounds carry much farther on this level.",
		Known = "Every sound travels almost twice as far on this level. Sneak (hold Shift), or make noise on purpose to pull monsters away.",
		Glyph = {
			{ 0.18, 0.5, 0.3, 0.5 },
			{ 0.42, 0.32, 0.54, 0.5 },
			{ 0.54, 0.5, 0.42, 0.68 },
			{ 0.62, 0.14, 0.8, 0.5 },
			{ 0.8, 0.5, 0.62, 0.86 },
		},
		Reverb = Enum.ReverbType.Arena,
	},
	HungryDark = {
		Id = "HungryDark",
		Name = "Hungry Dark",
		Plaque = "Listeners are drawn to fire on this level.",
		Known = "Listeners are drawn to fire on this level: lit braziers, burning oil and your lantern when it isn't dimmed. Dim your lantern (F), or light a fire somewhere else as bait.",
		Glyph = {
			{ 0.5, 0.1, 0.24, 0.86 },
			{ 0.5, 0.1, 0.76, 0.86 },
			{ 0.24, 0.86, 0.76, 0.86 },
			{ 0.5, 0.46, 0.5, 0.86 },
		},
		Reverb = Enum.ReverbType.StoneCorridor,
	},
	Tolling = {
		Id = "Tolling",
		Name = "Tolling Bell",
		Plaque = "A great bell rings on this level, and the marked gates open and close with it.",
		Known = "A great bell rings every 24 seconds. Each time, the marked gates swap between open and closed, and Watchers jerk forward even if you are looking at them. Ringing a tin bell next to a marked gate makes it swap early.",
		Glyph = {
			{ 0.5, 0.1, 0.5, 0.28 },
			{ 0.3, 0.28, 0.7, 0.28 },
			{ 0.3, 0.28, 0.2, 0.74 },
			{ 0.7, 0.28, 0.8, 0.74 },
			{ 0.16, 0.74, 0.84, 0.74 },
			{ 0.5, 0.74, 0.5, 0.9 },
		},
		Reverb = Enum.ReverbType.Hallway,
	},
}

return FloorRules
