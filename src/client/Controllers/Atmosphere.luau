--!strict
-- Mood: colour grading, layered ambience, music that rises when something
-- hunts you, distant sounds in the dark, dust drifting through the lantern
-- light, flickering torches and a heartbeat when you are close to death.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Audio = require(script.Parent.Audio)
local ClientState = require(script.Parent.ClientState)

local Atmosphere = {}

local mode = "Menu"
local beds: { [string]: Sound } = {}
local grading: ColorCorrectionEffect
local motes: Part
local combatLevel = 0

local HUNTING = { Chase = true, Windup = true, Charge = true, Dive = true, Recover = true, Stagger = true, Retreat = true, Pursue = true, Attack = true, Moving = true }

local function bed(name: string, volume: number): Sound
	local s = beds[name]
	if not s then
		s = Audio.Loop(name, 0)
		beds[name] = s
	end
	TweenService:Create(s, TweenInfo.new(2.5), { Volume = volume }):Play()
	return s
end

local function silence(except: { [string]: boolean })
	for name, s in beds do
		if not except[name] then
			TweenService:Create(s, TweenInfo.new(2), { Volume = 0 }):Play()
		end
	end
end

function Atmosphere.SetMode(m: string)
	mode = m
	if m == "Menu" then
		silence({ Catacombs = true })
		bed("Catacombs", 0.4)
	else
		silence({ Cave = true, Drip = true, Burial = true, BlackVault = true })
		bed("Cave", 0.28)
		bed("Drip", 0.12)
		bed("Burial", 0.16)
		bed("BlackVault", 0)
	end
end

local function setupGrading()
	grading = Instance.new("ColorCorrectionEffect")
	grading.Name = "RA_Grade"
	grading.Contrast = 0.14
	grading.Saturation = -0.12
	grading.TintColor = Color3.fromRGB(255, 240, 222)
	grading.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "RA_Bloom"
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 0.92
	bloom.Parent = Lighting
end

local function setupMotes()
	motes = Instance.new("Part")
	motes.Name = "DustMotes"
	motes.Anchored = true
	motes.CanCollide = false
	motes.CanQuery = false
	motes.CanTouch = false
	motes.Transparency = 1
	motes.Size = Vector3.new(40, 8, 40)
	motes.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 230, 190))
	e.LightEmission = 0
	e.LightInfluence = 1 -- only visible where something lights it
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(0.5, 0.14), NumberSequenceKeypoint.new(1, 0.05) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(5, 8)
	e.Rate = 30
	e.Speed = NumberRange.new(0.1, 0.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -0.05, 0)
	e.Parent = motes
end

-- A sound somewhere out in the dark.
local function distantSound()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local a = math.random() * math.pi * 2
	local pos = root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random(30, 55)
	local roll = math.random()
	if roll < 0.35 then
		Audio.Play("Whisper", pos, 0.22, 0.85, 3.5)
	elseif roll < 0.6 then
		Audio.Play("Growl", pos, 0.18, 0.7, 4)
	elseif roll < 0.8 then
		Audio.Play("Rubble", pos, 0.25, 0.7, 2)
	else
		Audio.Play("Grind", pos, 0.15, 0.5, 2.5)
	end
end

function Atmosphere.Start()
	setupGrading()
	setupMotes()
	SoundService.AmbientReverb = Enum.ReverbType.StoneCorridor
	Atmosphere.SetMode("Menu")

	local heartbeat = Audio.Loop("Heartbeat", 0)
	local nextDistant = os.clock() + 15
	local lastCheck = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and mode == "Dungeon" then
			motes.CFrame = CFrame.new(root.Position + Vector3.new(0, 3, 0))
		end
		-- Torches flicker.
		for _, l in CollectionService:GetTagged("Flicker") do
			if l:IsA("Light") then
				local base = (l:GetAttribute("Base") :: number?) or l.Brightness
				local seed = (l:GetAttribute("Seed") :: number?) or 0
				if l:GetAttribute("Base") == nil then
					l:SetAttribute("Base", base)
					seed = math.random() * 100
					l:SetAttribute("Seed", seed)
				end
				l.Brightness = base * (0.82 + math.noise(now * 5, seed) * 0.35)
			end
		end
		if mode ~= "Dungeon" then
			heartbeat.Volume = 0
			return
		end
		-- Combat music follows whatever is hunting you nearby.
		if now - lastCheck > 0.4 and root then
			lastCheck = now
			local hunting = 0
			for _, m in CollectionService:GetTagged("RA_Creature") do
				if m:IsA("Model") and HUNTING[(m:GetAttribute("State") :: string?) or ""] and m.PrimaryPart then
					if (m.PrimaryPart.Position - root.Position).Magnitude < 55 then
						hunting += 1
					end
				end
			end
			local target = math.clamp(hunting / 2, 0, 1)
			combatLevel += (target - combatLevel) * 0.35
			local vault = beds.BlackVault
			local burial = beds.Burial
			if vault then
				vault.Volume = 0.34 * combatLevel
			end
			if burial then
				burial.Volume = 0.16 * (1 - combatLevel)
			end
		end
		-- Close to death: heartbeat and the colour drains away.
		local snap = ClientState.Snapshot
		local low = 0
		if snap and snap.MaxHP and snap.MaxHP > 0 and ClientState.InRun then
			local frac = snap.HP / snap.MaxHP
			low = math.clamp((0.35 - frac) / 0.25, 0, 1)
		end
		heartbeat.Volume = 0.6 * low
		grading.Saturation = -0.12 - 0.55 * low
		grading.TintColor = Color3.fromRGB(255, 240, 222):Lerp(Color3.fromRGB(255, 200, 200), low)
		if now > nextDistant then
			nextDistant = now + 14 + math.random() * 18
			distantSound()
		end
		local _ = dt
	end)
end

return Atmosphere
