--!strict
-- THE HUNGRY DARK: Listeners are drawn to flame. Lit braziers, burning oil
-- and an undimmed lantern all pull them. Clue: braziers are mostly cold.

return {
	Id = "HungryDark",
	Configure = function(run)
		run.RuleFlags.LightLure = true
	end,
	OnTick = function(_run, _dt) end,
	Cleanup = function(run)
		run.RuleFlags.LightLure = nil
	end,
}
