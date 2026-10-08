--!strict
-- THE ECHOING HALLS: every sound carries almost twice as far.
-- Discovered when a creature reacts to a sound from beyond its normal reach.

return {
	Id = "Echoes",
	Configure = function(run)
		run.RuleFlags.NoiseMultiplier = 1.8
	end,
	OnTick = function(_run, _dt) end,
	Cleanup = function(run)
		run.RuleFlags.NoiseMultiplier = nil
	end,
}
