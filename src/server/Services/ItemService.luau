--!strict
-- Item use, thrown objects, pickups, dropping and chests. Every outcome is
-- decided here on the server; the client only sends an intent, a pack slot
-- and an aim point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local Loot = require(Shared.Definitions.Loot)
local RNG = require(Shared.RNG)
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

local function msg(run, text: string)
	S.PlayerStateService.Message(run, text)
end

local function aOrAn(name: string): string
	if string.match(name, "^%d") or string.match(name, "^%+") then
		return name
	end
	return (if string.match(string.lower(name), "^[aeiou]") then "an " else "a ") .. name
end

-- Where a throw toward `target` actually lands: clamped to range and
-- stopped short of the first wall in the way.
function ItemService.LandingPoint(run, target: Vector3, maxRange: number?): Vector3?
	local root = rootOf(run)
	if not root then
		return nil
	end
	local range = maxRange or Config.Combat.ThrowRange
	local from = root.Position + Vector3.new(0, 1.5, 0)
	local flatDelta = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	if flatDelta.Magnitude < 0.5 then
		flatDelta = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) * 6
	end
	if flatDelta.Magnitude > range then
		flatDelta = flatDelta.Unit * range
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

	-- Lights any unlit brazier it splashes.
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

-- Puts an item on the ground as a pickup. Returns the pickup entry.
function ItemService.SpawnPickup(run, pos: Vector3, itemId: string, count: number?, bonus: number?, name: string?)
	local def = Items[itemId]
	local folder = run.Built.Folder:FindFirstChild("Items") or run.Built.Folder
	local model = Fixtures.ItemModel(folder, pos, itemId, if def then def.Color else Kit.Palette.Gold, if def then def.Category else nil)
	local idx = #run.Built.Items + 1
	local e = { ItemId = itemId, Count = count or 1, Bonus = bonus or 0, Name = name, Model = model, Pos = pos, Taken = false, Prompt = nil :: any }
	local label = if itemId == "Gold" then (e.Count .. " gold") else (name or Items.EntryName({ Id = itemId, Count = e.Count, Bonus = e.Bonus }))
	e.Prompt = Fixtures.Prompt(model.PrimaryPart :: BasePart, "Take", label, tostring(idx), 7)
	run.Built.Items[idx] = e
	return e
end

local function ringingBell(run, pos: Vector3)
	local e = ItemService.SpawnPickup(run, pos, "TinBell")
	e.Model:SetAttribute("Thrown", true)
	e.Prompt.Enabled = false
	local model = e.Model
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
			e.Prompt.Enabled = true
		end
	end)
end

-- A random room the player can safely land in (not secret, vault or shrine).
local function randomRoom(run): Vector3?
	local floor, built = run.Floor, run.Built
	local options = {}
	local root = rootOf(run)
	for _, id in floor.RoomOrder do
		local r = floor.Rooms[id]
		if id ~= floor.SecretId and id ~= floor.VaultId and r.Archetype ~= "Junction" then
			local rect = built.RoomRects[id]
			local c = (rect.Min + rect.Max) / 2
			if not root or (c - root.Position).Magnitude > 30 then
				table.insert(options, c)
			end
		end
	end
	if #options == 0 then
		return nil
	end
	return options[math.random(1, #options)]
end

local function readScroll(run, itemId: string): boolean
	local ps = run.PS
	if itemId == "EnchantWeapon" then
		ps.Weapon.Bonus += 1
		msg(run, "Your " .. Items[ps.Weapon.Id].Name .. " glows blue for a moment. (+1 damage)")
	elseif itemId == "EnchantArmor" then
		if not ps.Armor then
			msg(run, "You are not wearing any armor.")
			return false
		end
		ps.Armor.Bonus += 1
		msg(run, "Your armor glows silver for a moment. (+1 armor)")
	elseif itemId == "MagicMapping" then
		local d = run.Built.Descent
		if d and d.Pos then
			Remotes.Effect:FireClient(run.Player, { Kind = "Reveal", Pos = d.Pos, Seconds = 45 })
		end
		msg(run, "A map of this level forms in your mind. An arrow now points to the stairs down.")
	elseif itemId == "Teleportation" then
		local to = randomRoom(run)
		local character = run.Player.Character
		if not to or not character then
			msg(run, "Nothing happens.")
			return true
		end
		character:PivotTo(CFrame.new(to + Vector3.new(0, 3, 0)))
		Remotes.Effect:FireClient(run.Player, { Kind = "Teleport" })
		msg(run, "You feel a wrenching sensation, and you are somewhere else.")
	end
	return true
end

local function drinkPotion(run, def): boolean
	local ps = run.PS
	if def.Id == "Tincture" then
		if ps.HP >= ps.MaxHP then
			msg(run, "You are already at full health.")
			return false
		end
		S.PlayerStateService.Heal(run, def.Heal or 8)
		msg(run, "You begin to feel better.")
	elseif def.Id == "ExtraHealing" then
		ps.MaxHP += 2
		ps.HP = ps.MaxHP
		msg(run, "You feel much better. (Max health +2)")
	elseif def.Id == "StrengthPotion" then
		ps.Str += 1
		msg(run, "You feel stronger. What bulging muscles! (Strength " .. ps.Str .. ")")
	end
	Remotes.Effect:FireClient(run.Player, { Kind = "Drink" })
	return true
end

function ItemService.Use(run, slot: number, target: Vector3?)
	local it = run.PS.Pack[slot]
	if not it then
		return
	end
	local itemId = it.Id
	local def = Items[itemId]
	if not def then
		return
	end
	local now = os.clock()
	if now - (lastUse[run.Player] or 0) < 0.4 then
		return
	end
	lastUse[run.Player] = now

	if def.Use == "Equip" then
		S.PlayerStateService.Equip(run, slot)
		return
	elseif def.Use == "Drink" then
		if drinkPotion(run, def) then
			S.PlayerStateService.TakeOne(run, slot)
			run.Stats.ItemsUsed += 1
		end
		return
	elseif def.Use == "Eat" then
		if run.PS.HP >= run.PS.MaxHP then
			msg(run, "You are not hungry.")
			return
		end
		S.PlayerStateService.TakeOne(run, slot)
		S.PlayerStateService.Heal(run, def.Heal or 4)
		msg(run, "Yum, that tasted good.")
		return
	elseif def.Use == "Read" then
		if readScroll(run, itemId) then
			S.PlayerStateService.TakeOne(run, slot)
			run.Stats.ItemsUsed += 1
			S.PlayerStateService.Push(run.Player)
		end
		return
	elseif def.Use == "Passive" then
		msg(run, def.Description)
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
	S.PlayerStateService.TakeOne(run, slot)
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
		msg(run, "You have no oil flasks.")
		return
	end
	if run.PS.Fuel >= Config.Lantern.MaxFuel - 1 then
		msg(run, "Your lantern is already full.")
		return
	end
	S.PlayerStateService.TakeOne(run, slot)
	S.PlayerStateService.AddFuel(run, Config.Lantern.RefillAmount)
	msg(run, "You refill your lantern.")
	Remotes.Effect:FireClient(run.Player, { Kind = "Refill" })
end

function ItemService.Drop(run, slot: number)
	local it = run.PS.Pack[slot]
	local root = rootOf(run)
	if not it or not root then
		return
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local pos = ItemService.LandingPoint(run, root.Position + look * 3, 3) or root.Position
	run.PS.Pack[slot] = false
	ItemService.SpawnPickup(run, pos, it.Id, it.Count, it.Bonus)
	msg(run, "You drop " .. aOrAn(Items.EntryName(it)) .. ".")
	S.PlayerStateService.Push(run.Player)
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
		local value = math.random(20, 40) + run.Depth * 10
		table.insert(run.Stats.Curios, entry.Name or "a treasure")
		S.PlayerStateService.AddGold(run, value)
		msg(run, string.format("You found %s, worth %d gold!", entry.Name or "a treasure", value))
		S.RunDirector.RecordEvent(run, "Curio", "Found " .. (entry.Name or "a treasure") .. ".")
		return true
	elseif entry.ItemId == "Gold" then
		entry.Taken = true
		entry.Model:Destroy()
		S.PlayerStateService.AddGold(run, entry.Count or 1)
		msg(run, string.format("You found %d gold pieces.", entry.Count or 1))
		return true
	end
	if not S.PlayerStateService.AddItem(run, entry.ItemId, entry.Count, entry.Bonus) then
		msg(run, "Your pack is full. Drop something first (I to open your inventory).")
		return false
	end
	entry.Taken = true
	entry.Model:Destroy()
	local name = Items.EntryName({ Id = entry.ItemId, Count = entry.Count or 1, Bonus = entry.Bonus or 0 })
	local slot = S.PlayerStateService.FindItem(run, entry.ItemId)
	local hint = ""
	local def = Items[entry.ItemId]
	if def and (def.Category == "Weapon" or def.Category == "Armor") then
		hint = " Open your inventory (I) to equip it."
	end
	msg(run, "You now have " .. aOrAn(name) .. (if slot and slot <= Config.Player.HotbarSlots then " (slot " .. slot .. ")." else ".") .. hint)
	Remotes.Effect:FireClient(run.Player, { Kind = "Pickup", Item = entry.ItemId })
	return true
end

-- Chests: rolled when opened, deterministic per seed. Contents spill out in
-- front of the chest so a full pack never destroys loot.
function ItemService.OpenChest(run, chest)
	if chest.Opened then
		return
	end
	chest.Opened = true
	chest.Open()
	local stream = RNG.Stream(run.Seed, run.Depth, "chest:" .. chest.Id)
	local q = chest.Quality
	local gold = Loot.Gold(stream, run.Depth, q)
	S.PlayerStateService.AddGold(run, gold)
	local found = { gold .. " gold" }
	local count = if q >= 3 then 3 elseif stream:Chance(0.45) then 2 else 1
	for i = 1, count do
		local roll = Loot.Roll(stream, run.Depth, q)
		local a = (i - (count + 1) / 2) * 2.4
		local spot = chest.Pos + chest.Front * 3.2 + chest.Right * a
		ItemService.SpawnPickup(run, spot, roll.ItemId, roll.Count, roll.Bonus)
		table.insert(found, aOrAn(Items.EntryName({ Id = roll.ItemId, Count = roll.Count, Bonus = roll.Bonus })))
	end
	S.NoiseService.Emit(run, chest.Pos, Config.Chest.Noise, "Door", true)
	Remotes.Effect:FireClient(run.Player, { Kind = "Chest", Pos = chest.Pos })
	msg(run, "You open the chest: " .. table.concat(found, ", ") .. ".")
	run.Stats.ChestsOpened = (run.Stats.ChestsOpened or 0) + 1
	S.RunDirector.RecordEvent(run, "Chest", "Opened a chest.")
end

-- A monster's dropped gold.
function ItemService.DropGold(run, pos: Vector3, amount: number)
	if amount > 0 and run.Built then
		ItemService.SpawnPickup(run, pos, "Gold", amount)
	end
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
				S.PlayerStateService.Damage(run, Config.OilFire.Damage, "Fire", f.Pos)
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

local function validSlot(slot: any): boolean
	return type(slot) == "number" and slot == slot and slot >= 1 and slot <= Config.Player.PackSlots and slot % 1 == 0
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
		if not validSlot(slot) then
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
	-- Inventory screen actions: Equip / Drop / Swap.
	Remotes.RequestInventory.OnServerEvent:Connect(function(player, action, slot, other)
		local run = S.RunDirector.GetRun(player)
		if not run or run.State ~= "Active" or not validSlot(slot) then
			return
		end
		local now = os.clock()
		if now - (lastUse[player] or 0) < 0.15 then
			return
		end
		lastUse[player] = now
		if action == "Equip" then
			S.PlayerStateService.Equip(run, slot)
		elseif action == "Drop" then
			ItemService.Drop(run, slot)
		elseif action == "Swap" and validSlot(other) and other ~= slot then
			S.PlayerStateService.SwapSlots(run, slot, other)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return ItemService
