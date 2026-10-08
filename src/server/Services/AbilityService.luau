--!strict
-- Abilities and spells unlocked by experience level (Definitions/Abilities).
-- The client asks with an ability id and an aim point; the server checks
-- the player's level and the cooldown, then decides every outcome.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Definitions.Abilities)
local Monsters = require(Shared.Definitions.Monsters)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Parent.Builder.Kit)

local AbilityService = {}

local S: any

local MISSILE_RANGE = 40
local MISSILE_DAMAGE = 7
local LIGHT_RANGE = 34
local LIGHT_SECONDS = 20
local LIGHT_RADIUS = 18
local SLOW_RADIUS = 16
local SLOW_SECONDS = 6
local BLINK_RANGE = 20

local function rootOf(run): BasePart?
	local character = run.Player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function msg(run, text: string)
	S.PlayerStateService.Message(run, text)
end

local handlers: { [string]: (any, Vector3?) -> boolean } = {}

handlers.Dash = function(run, _aim)
	-- The client moves its own character; the server grants the brief
	-- invulnerability and makes the noise.
	run.PS.InvulnUntil = math.max(run.PS.InvulnUntil, os.clock() + 0.4)
	local root = rootOf(run)
	if root then
		S.NoiseService.Emit(run, root.Position, 14, "Step", true)
	end
	return true
end

handlers.MagicMissile = function(run, aim)
	local root = rootOf(run)
	if not root or not aim then
		return false
	end
	local from = root.Position
	local to = S.ItemService.LandingPoint(run, aim, MISSILE_RANGE) or from
	local seg = flat(to - from)
	local len = seg.Magnitude
	local dir = if len > 0.1 then seg.Unit else flat(root.CFrame.LookVector).Unit
	-- First creature along the line, before any wall.
	local best, bestT = nil, math.huge
	for _, cr in run.Creatures do
		local rel = flat(cr.Root.Position - from)
		local t = rel:Dot(dir)
		if t > 0 and t <= len + 1.5 then
			local side = (rel - dir * t).Magnitude
			if side <= 2.8 and t < bestT then
				best, bestT = cr, t
			end
		end
	end
	local hitPos = if best then best.Root.Position else to + Vector3.new(0, 2, 0)
	Remotes.Effect:FireClient(run.Player, { Kind = "Missile", From = from + Vector3.new(0, 2, 0), To = hitPos })
	S.NoiseService.Emit(run, from, 10, "Strike", true)
	if best then
		local info = Monsters[best.Kind]
		local name = if info then info.Name else best.Kind
		if S.CreatureService.Hurt(run, best, MISSILE_DAMAGE, from) then
			if best.State ~= "Dead" then
				msg(run, string.format("The missile hits the %s for %d.", name, MISSILE_DAMAGE))
			end
		else
			msg(run, "The missile splashes harmlessly off the " .. name .. ".")
		end
	else
		msg(run, "The missile vanishes with a puff of smoke.")
	end
	return true
end

handlers.Light = function(run, aim)
	if not aim then
		return false
	end
	local pos = S.ItemService.LandingPoint(run, aim, LIGHT_RANGE)
	if not pos then
		return false
	end
	local orb = Kit.Part(run.Built.Folder, {
		Name = "LightSpell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.4, 1.4, 1.4),
		CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)),
		Color = Color3.fromRGB(255, 226, 170),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		CanQuery = false,
	})
	orb.Transparency = 0.2
	Kit.PointLight(orb, Color3.fromRGB(255, 220, 160), LIGHT_RADIUS + 6, 2, true)
	table.insert(run.Lights, { Pos = pos, Part = orb, Until = os.clock() + LIGHT_SECONDS })
	msg(run, "A ball of light appears.")
	return true
end

handlers.SlowMonster = function(run, _aim)
	local root = rootOf(run)
	if not root then
		return false
	end
	local n = S.CreatureService.Slow(run, root.Position, SLOW_RADIUS, SLOW_SECONDS)
	Remotes.Effect:FireClient(run.Player, { Kind = "SlowWave", Pos = root.Position, Radius = SLOW_RADIUS })
	msg(run, if n > 0 then string.format("%d monster%s slow down.", n, if n == 1 then "" else "s") else "Nothing nearby is affected.")
	return true
end

handlers.Teleport = function(run, aim)
	local root = rootOf(run)
	local character = run.Player.Character
	if not root or not character or not aim then
		return false
	end
	local to = S.ItemService.LandingPoint(run, aim, BLINK_RANGE)
	if not to then
		return false
	end
	local look = flat(to - root.Position)
	local cf = if look.Magnitude > 0.1 then CFrame.lookAt(to + Vector3.new(0, 3, 0), to + Vector3.new(0, 3, 0) + look) else CFrame.new(to + Vector3.new(0, 3, 0))
	Remotes.Effect:FireClient(run.Player, { Kind = "Blink", From = root.Position, To = to })
	character:PivotTo(cf)
	return true
end

function AbilityService.Use(run, id: string, aim: Vector3?)
	local def = Abilities.ById[id]
	if not def then
		return
	end
	if run.PS.Level < def.Level then
		msg(run, string.format("You haven't learned %s yet (unlocks at level %d).", def.Name, def.Level))
		return
	end
	local now = os.clock()
	local readyAt = run.PS.Cooldowns[id] or 0
	if now < readyAt - 0.15 then
		return
	end
	local ok, result = pcall(handlers[id], run, aim)
	if not ok then
		warn("[Ability] " .. id .. " failed: " .. tostring(result))
		return
	end
	if result then
		run.PS.Cooldowns[id] = now + def.Cooldown
		run.Stats.SpellsCast = (run.Stats.SpellsCast or 0) + 1
		S.PlayerStateService.Push(run.Player)
	end
end

-- Spell lights burn out.
function AbilityService.Tick(run, _dt: number)
	local now = os.clock()
	for i = #run.Lights, 1, -1 do
		local l = run.Lights[i]
		if now >= l.Until then
			if l.Part then
				l.Part:Destroy()
			end
			table.remove(run.Lights, i)
		end
	end
end

function AbilityService.ClearRun(run)
	for _, l in run.Lights or {} do
		if l.Part then
			l.Part:Destroy()
		end
	end
	run.Lights = {}
end

AbilityService.LightRadius = LIGHT_RADIUS

function AbilityService.Init(registry)
	S = registry
	Remotes.RequestAbility.OnServerEvent:Connect(function(player, id, aim)
		if type(id) ~= "string" then
			return
		end
		if aim ~= nil and (typeof(aim) ~= "Vector3" or aim.X ~= aim.X or aim.Z ~= aim.Z) then
			return
		end
		local run = S.RunDirector.GetRun(player)
		if not run or run.State ~= "Active" or not run.Built then
			return
		end
		AbilityService.Use(run, id, aim)
	end)
end

return AbilityService
