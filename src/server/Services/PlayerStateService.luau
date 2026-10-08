--!strict
-- Authoritative per-run player state: vigor, lantern fuel, inventory,
-- creeping. Also dresses the character so it reads as a small cloaked
-- explorer with a lantern instead of a default avatar (ART_BIBLE §13).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local FloorRules = require(Shared.Definitions.FloorRules)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerStateService = {}

local S: any

local L = Config.Lantern

export type State = {
	Vigor: number,
	Fuel: number,
	Dim: boolean,
	Creep: boolean,
	Inventory: { string | false },
	InvulnUntil: number,
	LastNoiseAt: number,
	LastStepAt: number,
	Light: PointLight?,
	LanternPart: BasePart?,
}

function PlayerStateService.NewState(): State
	local inv = {}
	for i = 1, Config.Player.InventorySlots do
		inv[i] = false
	end
	return {
		Vigor = Config.Player.MaxVigor,
		Fuel = L.MaxFuel,
		Dim = false,
		Creep = false,
		Inventory = inv,
		InvulnUntil = 0,
		LastNoiseAt = 0,
		LastStepAt = 0,
		Light = nil,
		LanternPart = nil,
	}
end

local function weldTo(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = to
	weld.Parent = part
end

local function gear(character: Model, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = character
	return p
end

function PlayerStateService.DressCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = Config.Player.WalkSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	local regen = character:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end

	-- Strip loud avatar items; keep the silhouette simple and muted.
	for _, d in character:GetChildren() do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
	local cloth = Color3.fromRGB(62, 50, 42)
	local dark = Color3.fromRGB(40, 34, 30)
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Player"
			if part.Name ~= "Head" and part.Name ~= "HumanoidRootPart" then
				part.Color = if string.find(part.Name, "Leg") or string.find(part.Name, "Foot") then dark else cloth
				part.Material = Enum.Material.Fabric
			end
		end
	end
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy()
	end

	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local hand = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if head then
		local hood = gear(character, "Hood", head.Size * Vector3.new(1.35, 1.25, 1.35), Color3.fromRGB(54, 40, 34), Enum.Material.Fabric)
		weldTo(hood, head, CFrame.new(0, 0.12, 0.08))
	end
	if torso then
		local cloak = gear(character, "Cloak", Vector3.new(torso.Size.X * 1.15, 3.6, 0.3), Color3.fromRGB(70, 36, 34), Enum.Material.Fabric)
		weldTo(cloak, torso, CFrame.new(0, -0.9, torso.Size.Z / 2 + 0.2) * CFrame.Angles(math.rad(-6), 0, 0))
		local pack = gear(character, "Satchel", Vector3.new(1.2, 1, 0.6), Color3.fromRGB(84, 62, 44), Enum.Material.Fabric)
		weldTo(pack, torso, CFrame.new(-0.9, -0.8, -0.3))
	end
	if hand then
		local lantern = gear(character, "Lantern", Vector3.new(0.7, 0.9, 0.7), Color3.fromRGB(60, 52, 40), Enum.Material.CorrodedMetal)
		weldTo(lantern, hand, CFrame.new(0, -0.9, -0.25))
		local glass = gear(character, "LanternGlass", Vector3.new(0.5, 0.55, 0.5), Color3.fromRGB(255, 190, 120), Enum.Material.Neon)
		glass.Transparency = 0.3
		weldTo(glass, lantern, CFrame.new())
		local light = Instance.new("PointLight")
		light.Name = "LanternLight"
		light.Color = L.Color
		light.Range = L.LitRange
		light.Brightness = L.LitBrightness
		light.Shadows = true
		light.Parent = glass
	end
end

function PlayerStateService.AttachLantern(run)
	local character = run.Player.Character
	local glass = character and character:FindFirstChild("LanternGlass")
	run.PS.LanternPart = glass
	run.PS.Light = glass and glass:FindFirstChild("LanternLight") :: PointLight?
	PlayerStateService.UpdateLantern(run)
end

-- Current light radius of the player's lantern.
function PlayerStateService.LanternRange(run): number
	local ps: State = run.PS
	if ps.Fuel <= 0 then
		return L.EmptyRange
	end
	return if ps.Dim then L.DimRange else L.LitRange
end

function PlayerStateService.UpdateLantern(run)
	local ps: State = run.PS
	local light = ps.Light
	if not light or not light.Parent then
		return
	end
	light.Range = PlayerStateService.LanternRange(run)
	if ps.Fuel <= 0 then
		light.Brightness = 0.5
	else
		light.Brightness = if ps.Dim then L.DimBrightness else L.LitBrightness
	end
	local glass = ps.LanternPart
	if glass then
		glass.Transparency = if ps.Fuel <= 0 then 0.8 elseif ps.Dim then 0.6 else 0.3
	end
end

function PlayerStateService.Push(player: Player)
	local run = S.RunDirector.GetRun(player)
	if not run then
		return
	end
	local ps: State = run.PS
	local known = S.DiscoveryService.Knows(player, "Rule" .. run.Floor.RuleId)
	Remotes.StateUpdate:FireClient(player, {
		Vigor = ps.Vigor,
		MaxVigor = Config.Player.MaxVigor,
		Fuel = math.floor(ps.Fuel + 0.5),
		MaxFuel = L.MaxFuel,
		Dim = ps.Dim,
		Creep = ps.Creep,
		Inventory = ps.Inventory,
		Depth = run.Depth,
		RuleId = run.Floor.RuleId,
		RuleName = if known then FloorRules[run.Floor.RuleId].Name else nil,
		Known = S.DiscoveryService.KnownList(player),
		HasKey = PlayerStateService.FindItem(run, "RustedKey") ~= nil,
	})
end

function PlayerStateService.FindItem(run, itemId: string): number?
	for i, it in run.PS.Inventory do
		if it == itemId then
			return i
		end
	end
	return nil
end

function PlayerStateService.AddItem(run, itemId: string): boolean
	if not Items[itemId] then
		return false
	end
	for i, it in run.PS.Inventory do
		if it == false then
			run.PS.Inventory[i] = itemId
			PlayerStateService.Push(run.Player)
			return true
		end
	end
	return false
end

function PlayerStateService.RemoveSlot(run, slot: number)
	run.PS.Inventory[slot] = false
	PlayerStateService.Push(run.Player)
end

function PlayerStateService.Heal(run, amount: number)
	local ps: State = run.PS
	ps.Vigor = math.min(Config.Player.MaxVigor, ps.Vigor + amount)
	PlayerStateService.Push(run.Player)
end

function PlayerStateService.AddFuel(run, amount: number)
	run.PS.Fuel = math.min(L.MaxFuel, run.PS.Fuel + amount)
	PlayerStateService.UpdateLantern(run)
	PlayerStateService.Push(run.Player)
end

-- `cause` is a short id used for the failure explanation.
function PlayerStateService.Damage(run, amount: number, cause: string, fromPos: Vector3?)
	if run.State ~= "Active" then
		return
	end
	local ps: State = run.PS
	local now = os.clock()
	if now < ps.InvulnUntil then
		return
	end
	ps.InvulnUntil = now + Config.Player.InvulnerableAfterHit
	ps.Vigor = math.max(0, ps.Vigor - amount)
	run.Stats.LastHitBy = cause
	Remotes.Effect:FireClient(run.Player, { Kind = "Hurt", Amount = amount, From = fromPos })
	-- A small shove away from the source keeps hits readable.
	local root = run.Player.Character and run.Player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and fromPos then
		local away = root.Position - fromPos
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude > 0.1 then
			root.AssemblyLinearVelocity = away.Unit * 28 + Vector3.new(0, 4, 0)
		end
	end
	PlayerStateService.Push(run.Player)
	if ps.Vigor <= 0 then
		S.RunDirector.Fail(run, cause)
	end
end

function PlayerStateService.SetCreep(run, creep: boolean)
	run.PS.Creep = creep
	local humanoid = run.Player.Character and run.Player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if creep then Config.Player.CreepSpeed else Config.Player.WalkSpeed
	end
	PlayerStateService.Push(run.Player)
end

function PlayerStateService.Tick(run, dt: number)
	local ps: State = run.PS
	if ps.Fuel > 0 then
		local drain = L.DrainPerSecond * dt * (if ps.Dim then L.DimDrainMultiplier else 1)
		local before = ps.Fuel
		ps.Fuel = math.max(0, ps.Fuel - drain)
		if ps.Fuel <= 0 then
			PlayerStateService.UpdateLantern(run)
			Remotes.Notice:FireClient(run.Player, { Kind = "Info", Text = "The lantern gutters out. Oil would revive it (R)." })
		end
		-- Push in coarse steps; the client interpolates.
		if math.floor(before / 5) ~= math.floor(ps.Fuel / 5) then
			PlayerStateService.Push(run.Player)
		end
	end
end

function PlayerStateService.Init(registry)
	S = registry
	Remotes.RequestLantern.OnServerEvent:Connect(function(player)
		local run = S.RunDirector.GetRun(player)
		if not run or run.State ~= "Active" then
			return
		end
		run.PS.Dim = not run.PS.Dim
		PlayerStateService.UpdateLantern(run)
		PlayerStateService.Push(player)
	end)
	Remotes.RequestCreep.OnServerEvent:Connect(function(player, creep)
		if type(creep) ~= "boolean" then
			return
		end
		local run = S.RunDirector.GetRun(player)
		if not run or run.State ~= "Active" then
			return
		end
		PlayerStateService.SetCreep(run, creep)
	end)
end

return PlayerStateService
