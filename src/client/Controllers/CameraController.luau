--!strict
-- Elevated, fixed-angle camera that looks into the dungeon like a physical
-- miniature (GAME_DESIGN §23). Short, small shakes punctuate heavy hits.
-- Walls that block the view of the explorer fade locally. While the menu
-- scene runs (ClientState.CameraOverride) this controller stays out of it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent.ClientState)

local CameraController = {}

local PITCH = math.rad(58)
local MIN_DIST, MAX_DIST = 34, 78
local FOLLOW = 9
local YAW_SPEED = 7

local distance = 54
local targetYaw = 0
local yaw = 0
local focus: Vector3? = nil
local faded: { [BasePart]: boolean } = {}
local occluders: { Instance } = {}

local function rebuildOccluders()
	occluders = CollectionService:GetTagged("Occluder")
end

function CameraController.Rotate(steps: number)
	targetYaw += steps * math.rad(90)
end

local shakeUntil = 0
local shakeStart = 0
local shakeMag = 0

-- A brief jolt. `magnitude` is in studs.
function CameraController.Shake(magnitude: number, seconds: number)
	local now = os.clock()
	if now > shakeUntil or magnitude >= shakeMag then
		shakeMag = magnitude
		shakeStart = now
		shakeUntil = now + seconds
	end
end

function CameraController.Zoom(delta: number)
	distance = math.clamp(distance + delta, MIN_DIST, MAX_DIST)
end

local function updateFade(camPos: Vector3, target: Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = occluders
	local nowFaded: { [BasePart]: boolean } = {}
	local origin = target
	local dir = camPos - target
	for _ = 1, 4 do
		local hit = Workspace:Raycast(origin, dir, params)
		if not hit then
			break
		end
		local part = hit.Instance :: BasePart
		nowFaded[part] = true
		origin = hit.Position + dir.Unit * 0.3
		dir = camPos - origin
	end
	for part in nowFaded do
		part.LocalTransparencyModifier = 0.72
	end
	for part in faded do
		if not nowFaded[part] and part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	faded = nowFaded
end

function CameraController.Start()
	local camera = Workspace.CurrentCamera
	rebuildOccluders()
	CollectionService:GetInstanceAddedSignal("Occluder"):Connect(rebuildOccluders)
	CollectionService:GetInstanceRemovedSignal("Occluder"):Connect(rebuildOccluders)

	UserInputService.InputChanged:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			CameraController.Zoom(-input.Position.Z * 4)
		end
	end)

	local occluderTimer = 0
	RunService:BindToRenderStep("RogueAbyssCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		camera.CameraType = Enum.CameraType.Scriptable
		if ClientState.CameraOverride then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local want = root.Position + Vector3.new(0, 1.5, 0)
		if not focus or (focus - want).Magnitude > 60 then
			focus = want -- snap on teleports (floor transitions)
		else
			focus = focus:Lerp(want, 1 - math.exp(-FOLLOW * dt))
		end
		yaw += (targetYaw - yaw) * (1 - math.exp(-YAW_SPEED * dt))
		ClientState.CameraYaw = yaw
		local offset = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(0, math.sin(PITCH), math.cos(PITCH)) * distance)
		local f = focus :: Vector3
		local camPos = f + offset
		local cf = CFrame.lookAt(camPos, f)
		local now = os.clock()
		if now < shakeUntil then
			local k = 1 - (now - shakeStart) / math.max(0.01, shakeUntil - shakeStart)
			local m = shakeMag * k * k
			cf *= CFrame.new((math.noise(now * 40, 1) * 2) * m, (math.noise(now * 40, 2) * 2) * m, 0)
		end
		camera.CFrame = cf
		camera.FieldOfView = 50
		occluderTimer += dt
		if occluderTimer > 0.05 then
			occluderTimer = 0
			updateFade(camPos, f)
		end
	end)
end

return CameraController
