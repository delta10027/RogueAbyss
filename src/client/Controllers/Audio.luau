--!strict
-- Local audio. Sound is gameplay information (GAME_DESIGN §22): every cue
-- here corresponds to something a creature can also hear, a hit landing,
-- or a rule change. Ambience and music are layered by Atmosphere.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local FloorRules = require(ReplicatedStorage:WaitForChild("Shared").Definitions.FloorRules)

local Audio = {}

-- Pro Sound Effects library and other public Creator Store sounds
-- (all verified to load in this experience).
local IDS: { [string]: string | { string } } = {
	Toll = "rbxassetid://87058958593472",
	Bell = "rbxassetid://9113420778",
	Shatter = "rbxassetid://9114591515",
	Ambience = "rbxassetid://9125351901",
	Grind = "rbxassetid://9113807250",
	Door = "rbxassetid://9114496277",
	Rubble = "rbxassetid://9118588165",
	Clank = "rbxassetid://9116891075",
	Hiss = "rbxassetid://9113418775",
	Swing = { "rbxassetid://9120972321", "rbxassetid://9120972444", "rbxassetid://123796710194563" },
	SwingHeavy = "rbxassetid://5789211405",
	HitFlesh = { "rbxassetid://101309544882556", "rbxassetid://121642440688650", "rbxassetid://128314503038887" },
	HitHeavy = { "rbxassetid://117450689659233", "rbxassetid://9083787050" },
	Clang = "rbxassetid://131225030650313",
	Crate = "rbxassetid://9120957636",
	Pot = "rbxassetid://88867327986977",
	Glass = "rbxassetid://9114615293",
	FireWhoosh = "rbxassetid://113831670560719",
	Explosion = { "rbxassetid://130565967505452", "rbxassetid://139148990073887" },
	Whisper = { "rbxassetid://9126213744", "rbxassetid://9126213995", "rbxassetid://9126214611" },
	Growl = { "rbxassetid://2184044761", "rbxassetid://129162115855106" },
	Thunder = "rbxassetid://91289467382888",
	Heartbeat = "rbxassetid://72495845036245",
	Shimmer = "rbxassetid://1841209502",
	Sting = "rbxassetid://9042321568",
	Flutter = "rbxassetid://9113975182",
	Magic = "rbxassetid://113964966358375",
	-- Long beds for Atmosphere.
	Cave = "rbxassetid://137658646948907",
	Drip = "rbxassetid://86604842687155",
	Catacombs = "rbxassetid://119370493144159",
	Burial = "rbxassetid://79559833217506",
	BlackVault = "rbxassetid://128319223242340",
	MineShaft = "rbxassetid://94018702571147",
}

function Audio.Id(name: string): string?
	local v = IDS[name]
	if type(v) == "table" then
		return v[math.random(1, #v)]
	end
	return v
end

-- Plays a sound at a world position (3D) or flat when pos is nil.
function Audio.Play(name: string, pos: Vector3?, volume: number?, pitch: number?, maxSeconds: number?): Sound?
	local id = Audio.Id(name)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = (pitch or 1) * (0.94 + math.random() * 0.12)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 160
	local holder: Instance
	if pos then
		local att = Instance.new("Attachment")
		att.WorldPosition = pos
		att.Parent = Workspace.Terrain
		holder = att
		sound.Parent = att
	else
		holder = sound
		sound.Parent = SoundService
	end
	sound:Play()
	local life = maxSeconds or 8
	if maxSeconds then
		task.delay(maxSeconds, function()
			if sound.Parent then
				local fadeStep = sound.Volume / 6
				for _ = 1, 6 do
					sound.Volume -= fadeStep
					task.wait(0.05)
				end
				sound:Stop()
			end
		end)
	end
	task.delay(life + 1, function()
		holder:Destroy()
	end)
	return sound
end

-- A looping sound owned by the caller.
function Audio.Loop(name: string, volume: number, parent: Instance?): Sound
	local s = Instance.new("Sound")
	s.Name = "Loop_" .. name
	s.SoundId = Audio.Id(name) or ""
	s.Looped = true
	s.Volume = volume
	s.Parent = parent or SoundService
	s:Play()
	return s
end

function Audio.SetFloor(ruleId: string)
	local rule = FloorRules[ruleId]
	if rule then
		SoundService.AmbientReverb = rule.Reverb
	end
end

return Audio
