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
		Name = "The Echoing Halls",
		Plaque = "HERE EVERY STEP IS CARRIED FARTHER THAN IT SHOULD BE",
		Known = "Sound travels almost twice as far. Creep, or make the noise somewhere useful.",
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
		Name = "The Hungry Dark",
		Plaque = "THE BLIND ONES REMEMBER WARMTH",
		Known = "Listeners are drawn to flame - braziers, burning oil and an undimmed lantern.",
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
		Name = "The Tolling Floor",
		Plaque = "WHEN THE GREAT BELL SPEAKS THE MARKED GATES ANSWER",
		Known = "A bell tolls on a rhythm. Marked gates swap, and Watchers lurch. A bell of your own can answer a gate.",
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
