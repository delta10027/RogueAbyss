--!strict
-- Item use, thrown objects and their consequences. Every outcome is decided
-- here on the server; the client only sends an intent and an aim point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Parent.Builder.Kit)
local Fixtures = require(script.Parent.Parent.Builder.Fixtures)

local ItemService = {}

local S: any

local THROW_TIME = 0.5
local lastUse: { [Player]: number } = {}

local function rootOf(run): BasePart?
	local character = run.Player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Where a throw toward `target` actually lands: clamped to range and
-- stopped short of the first wall in the way.
function ItemService.LandingPoint(run, target: Vector3): Vector3?
	local root = rootOf(run)
	if not root then
		return nil
	end
	local from = root.Position + Vector3.new(0, 1.5, 0)
	local flatDelta = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	if flatDelta.Magnitude < 0.5 then
		flatDelta = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) * 6
	end
	if flatDelta.Magnitude > Config.Combat.ThrowRange then
		flatDelta = flatDelta.Unit * Config.Combat.ThrowRange
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { run.Player.Character, run.CreatureFolder }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(from, flatDelta, params)
	local landing = if hit then hit.Position - flatDelta.Unit * 1.2 else from + flatDelta
	-- Drop to the floor.
	local down = Workspace:Raycast(landing + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), params)
	local y = if down then down.Position.Y else run.Built.Origin.Y
	return Vector3.new(landing.X, y, landing.Z)
end

local function oilFire(run, pos: Vector3)
	local folder = run.Built.Folder
	local patch = Kit.Part(folder, {
		Name = "OilFire",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, Config.OilFire.Radius * 2, Config.OilFire.Radius * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(40, 26, 18),
		Material = Enum.Material.Slate,
		CanCollide = false,
		CastShadow = false,
	})
	patch.CanQuery = false
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		local at = Kit.Attachment(patch, Vector3.new(0, math.cos(a) * Config.OilFire.Radius * 0.5, math.sin(a) * Config.OilFire.Radius * 0.5))
		local f = Kit.Flame(at, 1.6)
		f.EmissionDirection = Enum.NormalId.Right
	end
	local center = Kit.Attachment(patch, Vector3.new(2, 0, 0))
	Kit.PointLight(center, Kit.Palette.Amber, Config.OilFire.LightRange, 1.8, true)
	Kit.Embers(center)
	local fire = { Pos = pos, Part = patch, Until = os.clock() + Config.OilFire.Duration, NextBurn = 0 }
	table.insert(run.Fires, fire)

	-- Kindles any cold brazier it splashes.
	for _, b in run.Built.Braziers do
		if not b.IsLit() and (b.Pos - pos).Magnitude <= Config.OilFire.Radius + 2 then
			ItemService.Kindle(run, b, "Oil")
		end
	end
end

function ItemService.Kindle(run, brazier, how: string)
	brazier.SetLit(true)
	if brazier.Prompt then
		brazier.Prompt.Enabled = false
	end
	if how == "Oil" then
		S.DiscoveryService.Discover(run.Player, "OilBrazier")
	end
	Remotes.Effect:FireClient(run.Player, { Kind = "Kindle", Pos = brazier.Pos })
end

local function ringingBell(run, pos: Vector3)
	local folder = run.Built.Folder:FindFirstChild("Items") or run.Built.Folder
	local model = Fixtures.ItemModel(folder, pos, "TinBell", Items.TinBell.Color)
	model:SetAttribute("Thrown", true)
	local idx = #run.Built.Items + 1
	local prompt = Fixtures.Prompt(model.PrimaryPart :: BasePart, "Take", Items.TinBell.Name, tostring(idx), 7)
	prompt.Enabled = false
	run.Built.Items[idx] = { ItemId = "TinBell", Name = Items.TinBell.Name, Model = model, Prompt = prompt, Pos = pos, Taken = false }
	task.spawn(function()
		for _ = 1, 3 do
			if run.State ~= "Active" or not model.Parent then
				break
			end
			S.NoiseService.Emit(run, pos, Config.Noise.BellRadius, "Bell", false)
			Remotes.Effect:FireClient(run.Player, { Kind = "Bell", Pos = pos })
			S.RulesService.OnBell(run, pos)
			task.wait(1.6)
		end
		if model.Parent then
			prompt.Enabled = true
		end
	end)
end

function ItemService.Use(run, slot: number, target: Vector3?)
	local itemId = run.PS.Inventory[slot]
	if not itemId then
		return
	end
	local def = Items[itemId]
	if not def then
		return
	end
	local now = os.clock()
	if now - (lastUse[run.Player] or 0) < 0.4 then
		return
	end
	lastUse[run.Player] = now

	if def.Use == "Drink" then
		if run.PS.Vigor >= Config.Player.MaxVigor then
			Remotes.Notice:FireClient(run.Player, { Kind = "Info", Text = "You are not hurt." })
			return
		end
		S.PlayerStateService.RemoveSlot(run, slot)
		S.PlayerStateService.Heal(run, 2)
		Remotes.Effect:FireClient(run.Player, { Kind = "Drink" })
		return
	elseif def.Use == "Passive" then
		Remotes.Notice:FireClient(run.Player, { Kind = "Info", Text = def.Description })
		return
	end

	-- Throw.
	if typeof(target) ~= "Vector3" then
		return
	end
	local landing = ItemService.LandingPoint(run, target :: Vector3)
	local root = rootOf(run)
	if not landing or not root then
		return
	end
	S.PlayerStateService.RemoveSlot(run, slot)
	run.Stats.ItemsUsed += 1
	Remotes.Effect:FireClient(run.Player, { Kind = "Throw", From = root.Position + Vector3.new(0, 2, 0), To = landing, Item = itemId, Time = THROW_TIME })
	task.delay(THROW_TIME, function()
		if run.State ~= "Active" or not run.Built then
			return
		end
		if itemId == "OilFlask" then
			S.NoiseService.Emit(run, landing, Config.Noise.ShatterRadius, "Shatter", false)
			Remotes.Effect:FireClient(run.Player, { Kind = "Shatter", Pos = landing })
			oilFire(run, landing)
		elseif itemId == "TinBell" then
			ringingBell(run, landing)
		end
	end)
end

function ItemService.Refill(run)
	local slot = S.PlayerStateService.FindItem(run, "OilFlask")
	if not slot then
		Remotes.Notice:FireClient(run.Player, { Kind = "Info", Text = "No oil to spare." })
		return
	end
	if run.PS.Fuel >= Config.Lantern.MaxFuel - 1 then
		Remotes.Notice:FireClient(run.Player, { Kind = "Info", Text = "The lantern is full." })
		return
	end
	S.PlayerStateService.RemoveSlot(run, slot)
	S.PlayerStateService.AddFuel(run, Config.Lantern.RefillAmount)
	Remotes.Effect:FireClient(run.Player, { Kind = "Refill" })
end

-- Picks up a floor item by index. Returns true on success.
function ItemService.Pickup(run, idx: number): boolean
	local entry = run.Built.Items[idx]
	if not entry or entry.Taken then
		return false
	end
	if entry.ItemId == "Curio" then
		entry.Taken = true
		entry.Model:Destroy()
		table.insert(run.Stats.Curios, entry.Name)
		Remotes.Notice:FireClient(run.Player, { Kind = "Curio", Text = "You keep " .. entry.Name .. "." })
		S.RunDirector.RecordEvent(run, "Curio", "Found " .. entry.Name .. ".")
		return true
	end
	if not S.PlayerStateService.AddItem(run, entry.ItemId) then
		Remotes.Notice:FireClient(run.Player, { Kind = "Info", Text = "Your satchel is full." })
		return false
	end
	entry.Taken = true
	entry.Model:Destroy()
	Remotes.Effect:FireClient(run.Player, { Kind = "Pickup", Item = entry.ItemId })
	return true
end

-- Fires burn out; while lit they hurt whatever stands in them.
function ItemService.Tick(run, _dt: number)
	local now = os.clock()
	for i = #run.Fires, 1, -1 do
		local f = run.Fires[i]
		if now >= f.Until then
			if f.Part then
				f.Part:Destroy()
			end
			table.remove(run.Fires, i)
		elseif now >= f.NextBurn then
			f.NextBurn = now + 1.5
			S.CreatureService.BurnAt(run, f.Pos, Config.OilFire.Radius)
			local root = rootOf(run)
			if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(f.Pos.X, 0, f.Pos.Z)).Magnitude <= Config.OilFire.Radius - 1 then
				S.PlayerStateService.Damage(run, 1, "Fire", f.Pos)
			end
		end
	end
end

function ItemService.ClearRun(run)
	for _, f in run.Fires do
		if f.Part then
			f.Part:Destroy()
		end
	end
	run.Fires = {}
end

function ItemService.Init(registry)
	S = registry
	Remotes.RequestUseItem.OnServerEvent:Connect(function(player, slot, target, mode)
		local run = S.RunDirector.GetRun(player)
		if not run or run.State ~= "Active" then
			return
		end
		if mode == "Refill" then
			ItemService.Refill(run)
			return
		end
		if type(slot) ~= "number" or slot ~= slot or slot < 1 or slot > Config.Player.InventorySlots or slot % 1 ~= 0 then
			return
		end
		if target ~= nil and typeof(target) ~= "Vector3" then
			return
		end
		if typeof(target) == "Vector3" and (target.X ~= target.X or target.Z ~= target.Z) then
			return
		end
		ItemService.Use(run, slot, target)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return ItemService
