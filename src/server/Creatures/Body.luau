--!strict
-- Shared creature body construction and movement helpers.
-- Creatures are Humanoid-driven so client replication is smooth, but their
-- bodies are custom silhouettes (ART_BIBLE §14), never default avatars.

local Body = {}

export type Parts = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
}

function Body.Root(name: string, parent: Instance, pos: Vector3, size: Vector3, hipHeight: number): Parts
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = size
	root.Transparency = 1
	root.CanCollide = true
	root.CollisionGroup = "Creature"
	root.CFrame = CFrame.new(pos + Vector3.new(0, hipHeight + size.Y / 2, 0))
	root.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = hipHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 0
	humanoid.MaxSlopeAngle = 60
	for _, st in {
		Enum.HumanoidStateType.Jumping,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Dead,
	} do
		humanoid:SetStateEnabled(st, false)
	end
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = parent
	return { Model = model, Root = root, Humanoid = humanoid }
end

-- Attaches a decorative body part rigidly to the root with an adjustable weld.
function Body.Piece(parts: Parts, props: { [string]: any }, offset: CFrame): (BasePart, Weld)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = true
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CollisionGroup = "Creature"
	for k, v in props do
		(p :: any)[k] = v
	end
	p.CFrame = parts.Root.CFrame * offset
	p.Parent = parts.Model
	local weld = Instance.new("Weld")
	weld.Part0 = parts.Root
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	return p, weld
end

function Body.ServerOwn(root: BasePart)
	if root.Anchored then
		return
	end
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
end

-- Fades a body out with a puff of dust; no gore (GAME_DESIGN §18).
function Body.Dissolve(model: Model)
	local root = model.PrimaryPart
	if root then
		root.Anchored = true
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Color = ColorSequence.new(Color3.fromRGB(120, 112, 100))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(1.2, 2)
		dust.Speed = NumberRange.new(2, 5)
		dust.SpreadAngle = Vector2.new(180, 180)
		dust.Rate = 0
		dust.Parent = root
		dust:Emit(30)
	end
	local TweenService = game:GetService("TweenService")
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.CanCollide = false
			TweenService:Create(p, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		end
	end
	task.delay(2.2, function()
		model:Destroy()
	end)
end

return Body
