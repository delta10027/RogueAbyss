--!strict
-- Procedural attack animations for the explorer. Instead of uploaded
-- animation assets, swings are keyframed offsets applied to the R15
-- shoulder, wrist and waist joints (Motor6D.C0) on top of the walk cycle.
--
-- Styles (from the weapon definition):
--   Slash   wide horizontal cuts, alternating direction; 3rd hit is a spin
--   Thrust  quick stabs straight ahead
--   Smash   overhead blows that come down hard
--   Staff   two-handed sweeps
-- Plus a held "charge" pose for heavy attacks and a spell-cast gesture.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Animator = {}

type Key = { t: number, rs: CFrame?, ls: CFrame?, rw: CFrame?, waist: CFrame? }

local rad = math.rad
local A = CFrame.Angles
local I = CFrame.identity

-- Arm raised to `pitch` degrees and swung to `yaw` degrees (positive = left).
local function arm(pitch: number, yaw: number, roll: number?): CFrame
	return A(0, rad(yaw), 0) * A(rad(pitch), 0, rad(roll or 0))
end

-- Wrist bent so the blade continues the line of the arm.
local BLADE = A(rad(-90), 0, 0)

local ANIMS: { [string]: { Key } } = {
	Slash1 = {
		{ t = 0, rs = arm(70, -80), rw = BLADE, waist = A(0, rad(-30), 0) },
		{ t = 0.25, rs = arm(80, -85), rw = BLADE, waist = A(0, rad(-35), 0) },
		{ t = 0.6, rs = arm(80, 80), rw = BLADE, waist = A(0, rad(30), 0) },
		{ t = 1, rs = I, rw = I, waist = I },
	},
	Slash2 = {
		{ t = 0, rs = arm(75, 70), rw = BLADE, waist = A(0, rad(25), 0) },
		{ t = 0.25, rs = arm(80, 80), rw = BLADE, waist = A(0, rad(30), 0) },
		{ t = 0.6, rs = arm(70, -85), rw = BLADE, waist = A(0, rad(-35), 0) },
		{ t = 1, rs = I, rw = I, waist = I },
	},
	Slash3 = { -- spinning finisher
		{ t = 0, rs = arm(85, -90), rw = BLADE, waist = A(0, rad(-60), 0) },
		{ t = 0.2, rs = arm(90, -95), rw = BLADE, waist = A(0, rad(-80), 0) },
		{ t = 0.45, rs = arm(90, 40), rw = BLADE, waist = A(0, rad(90), 0) },
		{ t = 0.7, rs = arm(85, 95), rw = BLADE, waist = A(0, rad(200), 0) },
		{ t = 1, rs = I, rw = I, waist = I },
	},
	Thrust1 = {
		{ t = 0, rs = arm(70, 0) * CFrame.new(0, 0, 0.4), rw = BLADE, waist = A(0, rad(-15), 0) },
		{ t = 0.3, rs = arm(75, 0) * CFrame.new(0, 0, 0.6), rw = BLADE, waist = A(0, rad(-20), 0) },
		{ t = 0.5, rs = arm(92, 5) * CFrame.new(0, -0.3, -0.8), rw = BLADE, waist = A(0, rad(20), 0) },
		{ t = 1, rs = I, rw = I, waist = I },
	},
	Thrust2 = {
		{ t = 0, rs = arm(80, 15) * CFrame.new(0, 0, 0.4), rw = BLADE, waist = A(0, rad(-10), 0) },
		{ t = 0.3, rs = arm(80, 20) * CFrame.new(0, 0, 0.6), rw = BLADE, waist = A(0, rad(-15), 0) },
		{ t = 0.5, rs = arm(90, -5) * CFrame.new(0, -0.3, -0.8), rw = BLADE, waist = A(0, rad(25), 0) },
		{ t = 1, rs = I, rw = I, waist = I },
	},
	Thrust3 = { -- lunging double-hand stab
		{ t = 0, rs = arm(60, 0) * CFrame.new(0, 0, 0.8), ls = arm(60, 20), rw = BLADE, waist = A(0, rad(-25), 0) },
		{ t = 0.35, rs = arm(65, 0) * CFrame.new(0, 0, 1), ls = arm(65, 25), rw = BLADE, waist = A(0, rad(-30), 0) },
		{ t = 0.55, rs = arm(95, 0) * CFrame.new(0, -0.4, -1.2), ls = arm(90, 30), rw = BLADE, waist = A(0, rad(15), 0) },
		{ t = 1, rs = I, ls = I, rw = I, waist = I },
	},
	Smash1 = {
		{ t = 0, rs = arm(165, -10), rw = BLADE, waist = A(rad(10), rad(-15), 0) },
		{ t = 0.3, rs = arm(175, -10), rw = BLADE, waist = A(rad(15), rad(-15), 0) },
		{ t = 0.55, rs = arm(45, 10), rw = BLADE, waist = A(rad(-15), rad(10), 0) },
		{ t = 1, rs = I, rw = I, waist = I },
	},
	Smash2 = {
		{ t = 0, rs = arm(150, 50), rw = BLADE, waist = A(0, rad(25), 0) },
		{ t = 0.3, rs = arm(160, 55), rw = BLADE, waist = A(0, rad(30), 0) },
		{ t = 0.55, rs = arm(50, -50), rw = BLADE, waist = A(rad(-10), rad(-25), 0) },
		{ t = 1, rs = I, rw = I, waist = I },
	},
	Smash3 = { -- leaping overhead with both hands
		{ t = 0, rs = arm(180, 0), ls = arm(170, 10), rw = BLADE, waist = A(rad(20), 0, 0) },
		{ t = 0.35, rs = arm(185, 0), ls = arm(175, 10), rw = BLADE, waist = A(rad(25), 0, 0) },
		{ t = 0.55, rs = arm(30, 0), ls = arm(35, 15), rw = BLADE, waist = A(rad(-25), 0, 0) },
		{ t = 1, rs = I, ls = I, rw = I, waist = I },
	},
	Staff1 = {
		{ t = 0, rs = arm(60, -70), ls = arm(50, -40), rw = BLADE, waist = A(0, rad(-30), 0) },
		{ t = 0.3, rs = arm(65, -75), ls = arm(55, -45), rw = BLADE, waist = A(0, rad(-35), 0) },
		{ t = 0.6, rs = arm(75, 70), ls = arm(60, 60), rw = BLADE, waist = A(0, rad(30), 0) },
		{ t = 1, rs = I, ls = I, rw = I, waist = I },
	},
	Staff2 = {
		{ t = 0, rs = arm(70, 60), ls = arm(60, 50), rw = BLADE, waist = A(0, rad(25), 0) },
		{ t = 0.3, rs = arm(75, 70), ls = arm(60, 55), rw = BLADE, waist = A(0, rad(30), 0) },
		{ t = 0.6, rs = arm(65, -75), ls = arm(55, -50), rw = BLADE, waist = A(0, rad(-30), 0) },
		{ t = 1, rs = I, ls = I, rw = I, waist = I },
	},
	Staff3 = {
		{ t = 0, rs = arm(170, 0), ls = arm(165, 0), rw = BLADE, waist = A(rad(15), 0, 0) },
		{ t = 0.35, rs = arm(175, 0), ls = arm(170, 0), rw = BLADE, waist = A(rad(20), 0, 0) },
		{ t = 0.55, rs = arm(40, 0), ls = arm(40, 0), rw = BLADE, waist = A(rad(-20), 0, 0) },
		{ t = 1, rs = I, ls = I, rw = I, waist = I },
	},
	Charge = { -- held pose: weapon drawn far back
		{ t = 0, rs = arm(150, -60), ls = arm(40, -30), rw = BLADE, waist = A(rad(8), rad(-45), 0) },
		{ t = 1, rs = arm(160, -65), ls = arm(45, -35), rw = BLADE, waist = A(rad(10), rad(-50), 0) },
	},
	Heavy = {
		{ t = 0, rs = arm(160, -65), ls = arm(45, -35), rw = BLADE, waist = A(rad(10), rad(-50), 0) },
		{ t = 0.4, rs = arm(70, 70), ls = arm(60, 40), rw = BLADE, waist = A(rad(-15), rad(45), 0) },
		{ t = 1, rs = I, ls = I, rw = I, waist = I },
	},
	Spin = { -- whirlwinds and sweeps
		{ t = 0, rs = arm(85, -90), rw = BLADE, waist = A(0, 0, 0) },
		{ t = 0.33, rs = arm(85, -90), rw = BLADE, waist = A(0, rad(120), 0) },
		{ t = 0.66, rs = arm(85, -90), rw = BLADE, waist = A(0, rad(240), 0) },
		{ t = 0.95, rs = arm(85, -90), rw = BLADE, waist = A(0, rad(355), 0) },
		{ t = 1, rs = I, rw = I, waist = I },
	},
	Cast = {
		{ t = 0, ls = arm(40, 10) },
		{ t = 0.3, ls = arm(95, -10) * CFrame.new(0, 0, -0.3) },
		{ t = 0.75, ls = arm(95, -10) * CFrame.new(0, 0, -0.3) },
		{ t = 1, ls = I },
	},
	CastBoth = {
		{ t = 0, rs = arm(40, 0), ls = arm(40, 0) },
		{ t = 0.3, rs = arm(150, 20), ls = arm(150, -20), waist = A(rad(12), 0, 0) },
		{ t = 0.6, rs = arm(70, -20), ls = arm(70, 20), waist = A(rad(-10), 0, 0) },
		{ t = 1, rs = I, ls = I, waist = I },
	},
}

type Joint = { Motor: Motor6D, Base: CFrame }

local joints: { rs: Joint?, ls: Joint?, rw: Joint?, waist: Joint? } = {}
local playing: { Keys: { Key }, Start: number, Duration: number, Hold: boolean }? = nil
local frozenUntil = 0
local frozenAt = 0
local current: { [string]: CFrame } = {}

local function find(character: Model, partName: string, motorName: string): Joint?
	local part = character:FindFirstChild(partName)
	local m = part and part:FindFirstChild(motorName)
	if m and m:IsA("Motor6D") then
		return { Motor = m, Base = m.C0 }
	end
	return nil
end

local function bind(character: Model)
	joints = {}
	playing = nil
	current = {}
	task.wait(0.5)
	joints.rs = find(character, "RightUpperArm", "RightShoulder")
	joints.ls = find(character, "LeftUpperArm", "LeftShoulder")
	joints.rw = find(character, "RightHand", "RightWrist")
	joints.waist = find(character, "UpperTorso", "Waist")
end

local function trail(on: boolean)
	local character = Players.LocalPlayer.Character
	local w = character and character:FindFirstChild("WeaponModel")
	local grip = w and (w :: Model).PrimaryPart
	local t = grip and grip:FindFirstChild("SwingTrail")
	if t and t:IsA("Trail") then
		t.Enabled = on
	end
end

local function sample(keys: { Key }, alpha: number, field: string): CFrame?
	local prev: Key? = nil
	for _, k in keys do
		local v = (k :: any)[field]
		if v then
			if k.t >= alpha then
				if not prev then
					return v
				end
				local span = k.t - prev.t
				local f = if span > 0 then (alpha - prev.t) / span else 1
				-- Ease in-out so blows have weight.
				f = f * f * (3 - 2 * f)
				return ((prev :: any)[field] :: CFrame):Lerp(v, f)
			end
			prev = k
		end
	end
	return if prev then (prev :: any)[field] else nil
end

-- Plays an animation over `duration` seconds. `hold` keeps the last pose.
function Animator.Play(name: string, duration: number, hold: boolean?)
	local keys = ANIMS[name]
	if not keys then
		return
	end
	playing = { Keys = keys, Start = os.clock(), Duration = math.max(0.08, duration), Hold = hold == true }
	if name ~= "Cast" and name ~= "Charge" and name ~= "CastBoth" then
		trail(true)
		task.delay(duration * 0.75, function()
			if not playing or playing.Keys == keys then
				trail(false)
			end
		end)
	end
end

-- The swing animation for a weapon style and combo step.
function Animator.Swing(style: string, step: number, duration: number)
	local s = if style == "Thrust" or style == "Smash" or style == "Staff" then style else "Slash"
	Animator.Play(s .. math.clamp(step, 1, 3), duration)
end

function Animator.Stop()
	playing = nil
	trail(false)
end

-- Hit-stop: freeze the swing for a few frames when it connects.
function Animator.HitStop(seconds: number)
	local now = os.clock()
	if now > frozenUntil then
		frozenAt = now
	end
	frozenUntil = math.max(frozenUntil, now + seconds)
end

function Animator.Start()
	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(bind, player.Character)
	end
	player.CharacterAdded:Connect(bind)

	RunService.Stepped:Connect(function()
		local now = os.clock()
		if now < frozenUntil then
			return
		end
		if frozenAt > 0 and playing then
			-- Shift the animation by the time spent frozen.
			playing.Start += math.max(0, frozenUntil - frozenAt)
			frozenAt = 0
		end
		local p = playing
		local alpha = 1
		if p then
			alpha = (now - p.Start) / p.Duration
			if alpha >= 1 and not p.Hold then
				playing = nil
				p = nil
			end
		end
		for field, j in joints :: any do
			if j and j.Motor.Parent then
				local off = if p then sample(p.Keys, math.min(alpha, 1), field) else nil
				local target = off or I
				-- Blend back to rest smoothly when nothing is playing.
				local cur = current[field] or I
				local blended = if p then target else cur:Lerp(I, 0.25)
				current[field] = blended
				j.Motor.C0 = j.Base * blended
			end
		end
	end)
end

return Animator
