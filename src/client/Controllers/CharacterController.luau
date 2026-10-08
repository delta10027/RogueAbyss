--!strict
-- Facing. With a mouse the explorer faces the cursor, which matters: the
-- lantern lights what you face, and Watchers only freeze in your gaze.
-- On gamepad the right stick aims; on touch the explorer faces where they walk.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent.ClientState)

local CharacterController = {}

local align: AlignOrientation? = nil
local attachment: Attachment? = nil

local function setupCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	attachment = Instance.new("Attachment")
	attachment.Name = "FacingAttachment"
	attachment.Parent = root
	local a = Instance.new("AlignOrientation")
	a.Mode = Enum.OrientationAlignmentMode.OneAttachment
	a.Attachment0 = attachment
	a.MaxTorque = 1e6
	a.Responsiveness = 45
	a.Enabled = false
	a.Parent = root
	align = a
end

local function groundAim(root: BasePart): Vector3?
	local mouse = UserInputService:GetMouseLocation()
	local ray = Workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
	local planeY = root.Position.Y - 2
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

function CharacterController.Start()
	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)

	UserInputService.LastInputTypeChanged:Connect(function(t)
		if t == Enum.UserInputType.Touch then
			ClientState.InputMode = "Touch"
		elseif string.find(t.Name, "Gamepad") then
			ClientState.InputMode = "Gamepad"
		elseif t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Keyboard then
			ClientState.InputMode = "Mouse"
		end
	end)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		ClientState.InputMode = "Touch"
	end

	local stick = Vector3.zero
	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = input.Position
		end
	end)

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or not align or not attachment then
			return
		end
		local facing: Vector3? = nil
		if ClientState.InputMode == "Mouse" and not ClientState.UIBlocking then
			local aim = groundAim(root)
			if aim then
				ClientState.AimPoint = aim
				local d = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
				if d.Magnitude > 1 then
					facing = d.Unit
				end
			end
		elseif ClientState.InputMode == "Gamepad" and Vector2.new(stick.X, stick.Y).Magnitude > 0.35 then
			local yawCf = CFrame.Angles(0, ClientState.CameraYaw, 0)
			facing = yawCf:VectorToWorldSpace(Vector3.new(stick.X, 0, -stick.Y)).Unit
			ClientState.AimPoint = root.Position + facing * 18
		else
			ClientState.AimPoint = root.Position + Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) * 18
		end
		if facing then
			humanoid.AutoRotate = false
			align.Enabled = true
			align.CFrame = CFrame.lookAt(Vector3.zero, facing)
		else
			humanoid.AutoRotate = true
			align.Enabled = false
		end
	end)
end

return CharacterController
