--!strict
-- Builds floors and walls for a logical floor.
--
-- Walls are derived by rasterising rooms and corridors onto a 2-stud grid:
-- any empty cell touching a floor cell becomes wall. Wall cells are then
-- greedily merged into large parts per architectural style, which keeps the
-- part count low and handles every corridor bend without special cases.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local RoomDefs = require(ReplicatedStorage.Shared.Definitions.Rooms)
local Validator = require(script.Parent.Parent.Generation.Validator)
local Kit = require(script.Parent.Kit)

local Grid = Config.Grid
local P = Kit.Palette

local CELL = 2

local Shell = {}

type Style = { Material: Enum.Material, Color: Color3, Alt: { Material: Enum.Material, Color: Color3 }? }

local WALL_STYLES: { [string]: Style } = {
	OldStone = { Material = Enum.Material.Slate, Color = P.AgedStone },
	ImpossibleRepair = {
		Material = Enum.Material.Brick,
		Color = P.Brick,
		Alt = { Material = Enum.Material.WoodPlanks, Color = P.DarkBrown },
	},
	BuriedMachine = { Material = Enum.Material.CorrodedMetal, Color = P.OldIron },
	ForgottenShrine = { Material = Enum.Material.Limestone, Color = P.PaleStone },
	LivingPassage = { Material = Enum.Material.Slate, Color = P.Moss },
	Corridor = { Material = Enum.Material.Cobblestone, Color = P.DarkStone },
}

local FLOOR_STYLES: { [string]: Style } = {
	OldStone = { Material = Enum.Material.Slate, Color = P.DarkStone },
	ImpossibleRepair = { Material = Enum.Material.Cobblestone, Color = P.DarkStone },
	BuriedMachine = { Material = Enum.Material.DiamondPlate, Color = P.Charcoal },
	ForgottenShrine = { Material = Enum.Material.Marble, Color = Color3.fromRGB(96, 92, 86) },
	LivingPassage = { Material = Enum.Material.Ground, Color = Color3.fromRGB(46, 50, 38) },
	Corridor = { Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(50, 47, 44) },
}

export type ShellResult = {
	Cols: number,
	Rows: number,
	IsFloor: (number, number) -> boolean,
	Owner: (number, number) -> string?,
}

function Shell.Build(floor, origin: Vector3, parent: Instance): ShellResult
	local floorsFolder = Kit.Folder(parent, "Floors")
	local wallsFolder = Kit.Folder(parent, "Walls")

	local width = floor.Cols * Grid.SlotSize
	local depth = floor.Rows * Grid.SlotSize
	local nx, nz = math.ceil(width / CELL) + 2, math.ceil(depth / CELL) + 2

	-- owner[ix][iz] = room id, "C" (corridor) or nil. Index offset by 1 so the
	-- outermost ring is always empty and can hold walls.
	local owner: { { string? } } = table.create(nx + 2)
	for ix = 0, nx + 1 do
		owner[ix] = {}
	end
	local function mark(x0: number, z0: number, x1: number, z1: number, id: string, overwrite: boolean)
		for ix = math.floor(x0 / CELL), math.ceil(x1 / CELL) - 1 do
			for iz = math.floor(z0 / CELL), math.ceil(z1 / CELL) - 1 do
				local col = owner[ix + 1]
				if col and (overwrite or col[iz + 1] == nil) then
					col[iz + 1] = id
				end
			end
		end
	end

	-- Corridors first so rooms overwrite overlaps at their doorsteps.
	for _, c in floor.Connections do
		for _, box in Validator.CorridorBoxes(c) do
			mark(box.X0, box.Z0, box.X1, box.Z1, "C", true)
		end
	end
	for _, id in floor.RoomOrder do
		local r = floor.Rooms[id].Rect
		mark(r.X0, r.Z0, r.X1, r.Z1, id, true)
	end

	local function isFloor(ix: number, iz: number): boolean
		local col = owner[ix]
		return col ~= nil and col[iz] ~= nil
	end

	-- Floor slabs ---------------------------------------------------------
	local y = origin.Y
	for _, id in floor.RoomOrder do
		local room = floor.Rooms[id]
		local r = room.Rect
		local family = RoomDefs[room.Archetype].Family
		local st = FLOOR_STYLES[family]
		local w, d = r.X1 - r.X0, r.Z1 - r.Z0
		local cx, cz = origin.X + r.X0 + w / 2, origin.Z + r.Z0 + d / 2
		local slab = Kit.Part(floorsFolder, {
			Name = id .. "_Floor",
			Size = Vector3.new(w, 2, d),
			CFrame = CFrame.new(cx, y - 1, cz),
			Color = st.Color,
			Material = st.Material,
			CastShadow = false,
		})
		slab:SetAttribute("RoomId", id)
		-- A darker worn border reads as deliberate masonry from above.
		if w >= 16 and d >= 16 then
			local trimColor = Color3.new(st.Color.R * 0.72, st.Color.G * 0.72, st.Color.B * 0.72)
			for _, t in {
				{ Vector3.new(w, 0.2, 2), Vector3.new(0, 0, -d / 2 + 1) },
				{ Vector3.new(w, 0.2, 2), Vector3.new(0, 0, d / 2 - 1) },
				{ Vector3.new(2, 0.2, d - 4), Vector3.new(-w / 2 + 1, 0, 0) },
				{ Vector3.new(2, 0.2, d - 4), Vector3.new(w / 2 - 1, 0, 0) },
			} do
				Kit.Deco(floorsFolder, {
					Size = t[1],
					CFrame = CFrame.new(cx, y + 0.02, cz) * CFrame.new(t[2]),
					Color = trimColor,
					Material = Enum.Material.Slate,
					CastShadow = false,
				})
			end
		end
	end
	local cst = FLOOR_STYLES.Corridor
	for _, c in floor.Connections do
		for i, box in Validator.CorridorBoxes(c) do
			local w, d = box.X1 - box.X0, box.Z1 - box.Z0
			Kit.Part(floorsFolder, {
				Name = c.Id .. "_Floor" .. i,
				Size = Vector3.new(w, 2, d),
				CFrame = CFrame.new(origin.X + box.X0 + w / 2, y - 1.04, origin.Z + box.Z0 + d / 2),
				Color = cst.Color,
				Material = cst.Material,
				CastShadow = false,
			})
		end
	end

	-- Wall cells ----------------------------------------------------------
	local wallStyle: { [number]: { [number]: string } } = {}
	for ix = 0, nx + 1 do
		wallStyle[ix] = {}
		for iz = 0, nz + 1 do
			if not isFloor(ix, iz) then
				local styleKey: string? = nil
				for dx = -1, 1 do
					for dz = -1, 1 do
						local col = owner[ix + dx]
						local o = col and col[iz + dz]
						if o then
							if o ~= "C" then
								styleKey = RoomDefs[floor.Rooms[o].Archetype].Family
							elseif styleKey == nil then
								styleKey = "Corridor"
							end
						end
					end
				end
				if styleKey then
					wallStyle[ix][iz] = styleKey
				end
			end
		end
	end

	-- Greedy merge into rectangles of identical style.
	local used: { [number]: { [number]: boolean } } = {}
	for ix = 0, nx + 1 do
		used[ix] = {}
	end
	local H = Grid.WallHeight
	local partIndex = 0
	for iz = 0, nz + 1 do
		for ix = 0, nx + 1 do
			local s = wallStyle[ix][iz]
			if s and not used[ix][iz] then
				local w = 1
				while ix + w <= nx + 1 and wallStyle[ix + w][iz] == s and not used[ix + w][iz] do
					w += 1
				end
				local d = 1
				local grow = true
				while grow and iz + d <= nz + 1 do
					for k = 0, w - 1 do
						if wallStyle[ix + k][iz + d] ~= s or used[ix + k][iz + d] then
							grow = false
							break
						end
					end
					if grow then
						d += 1
					end
				end
				for a = 0, w - 1 do
					for b = 0, d - 1 do
						used[ix + a][iz + b] = true
					end
				end
				partIndex += 1
				local style = WALL_STYLES[s]
				if style.Alt and partIndex % 3 == 0 then
					style = style.Alt :: Style
				end
				-- Cell (ix, iz) spans [(ix-1)*CELL, ix*CELL] in floor space.
				local x0, z0 = (ix - 1) * CELL, (iz - 1) * CELL
				local sx, sz = w * CELL, d * CELL
				local cf = CFrame.new(origin.X + x0 + sx / 2, y + H / 2, origin.Z + z0 + sz / 2)
				local wall = Kit.Part(wallsFolder, {
					Name = "Wall",
					Size = Vector3.new(sx, H, sz),
					CFrame = cf,
					Color = Kit.Vary(style.Color, 0.08, partIndex),
					Material = style.Material,
				})
				CollectionService:AddTag(wall, "Occluder")
				local cap = Kit.Deco(wallsFolder, {
					Name = "WallCap",
					Size = Vector3.new(sx, 0.6, sz),
					CFrame = cf * CFrame.new(0, H / 2 + 0.3, 0),
					Color = P.Soot,
					Material = Enum.Material.Slate,
					CastShadow = false,
				})
				CollectionService:AddTag(cap, "Occluder")
			end
		end
	end

	return {
		Cols = nx,
		Rows = nz,
		IsFloor = isFloor,
		Owner = function(ix: number, iz: number): string?
			local col = owner[ix]
			return col and col[iz]
		end,
	}
end

return Shell
