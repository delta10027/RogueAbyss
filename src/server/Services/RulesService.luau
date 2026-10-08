--!strict
-- Selects and drives the active floor rule for each run through a common
-- interface: Configure / OnTick / Cleanup (+ optional OnBell).
-- Rules communicate only through run flags and other services.

local Rules = script.Parent.Parent.Rules

local RulesService = {}

local modules: { [string]: any } = {
	Echoes = require(Rules.Echoes),
	HungryDark = require(Rules.HungryDark),
	Tolling = require(Rules.Tolling),
}

function RulesService.Init(registry)
	for _, m in modules do
		if m.Bind then
			m.Bind(registry)
		end
	end
end

function RulesService.Begin(run)
	run.RuleFlags = {}
	local rule = modules[run.Floor.RuleId]
	run.Rule = rule
	if rule then
		rule.Configure(run)
	else
		warn("[RulesService] unknown rule " .. tostring(run.Floor.RuleId))
	end
end

function RulesService.Tick(run, dt: number)
	if run.Rule then
		local ok, err = pcall(run.Rule.OnTick, run, dt)
		if not ok then
			warn("[RulesService] tick error: " .. tostring(err))
		end
	end
end

function RulesService.OnBell(run, pos: Vector3)
	if run.Rule and run.Rule.OnBell then
		run.Rule.OnBell(run, pos)
	end
end

function RulesService.End(run)
	if run.Rule then
		pcall(run.Rule.Cleanup, run)
	end
	run.Rule = nil
	run.RuleFlags = {}
end

function RulesService.Module(id: string)
	return modules[id]
end

return RulesService
