--!strict
-- Local audio. Sound is gameplay information (GAME_DESIGN §22): every cue
-- here corresponds to something a creature can also hear or a rule change.
-- No constant music; a low ambience bed and intentional silence.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local FloorRules = require(ReplicatedStorage:WaitForChild("Shared").Definitions.FloorRules)

local Audio = {}

-- Free Creator Store sound effects (mostly Pro Sound Effects library).
local IDS = {
	Toll = "rbxassetid://87058958593472",
	Bell = "rbxassetid://9113420778",
	Shatter = "rbxassetid://9114591515",
	Ambience = "rbxassetid://9125351901",
	Grind = "rbxassetid://9113807250",
	Door = "rbxassetid://9114496277",
	Rubble = "rbxassetid://9118588165",
	Clank = "rbxassetid://9116891075",
	Hiss = "rbxassetid://9113418775",
	Swing = "rbxassetid://2795036553",
}

local ambience: Sound? = nil

-- Plays a sound at a world position (3D) or flat when pos is nil.
function Audio.Play(name: string, pos: Vector3?, volume: number?, pitch: number?, maxSeconds: number?)
	local id = IDS[name]
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = pitch or 1
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
end

function Audio.SetFloor(ruleId: string)
	local rule = FloorRules[ruleId]
	if rule then
		SoundService.AmbientReverb = rule.Reverb
	end
	if not ambience then
		local s = Instance.new("Sound")
		s.Name = "Ambience"
		s.SoundId = IDS.Ambience
		s.Looped = true
		s.Volume = 0.12
		s.PlaybackSpeed = 0.8
		s.Parent = SoundService
		s:Play()
		ambience = s
	end
end

return Audio
