--!strict
-- Imported creature meshes (made in Blender, see blender/RogueAbyss_Art.blend).
--
-- Studio's 3D importer cannot be driven by script, so imported models live
-- in the place at ServerStorage.Assets.Creatures.<Kind>. Each is a Model of
-- MeshParts named "<Kind>_<Piece>" (e.g. Listener_EarL). If a model is
-- missing, creatures fall back to their part-built bodies.
--
-- Materials and colours are applied here, not in Blender, so every creature
-- uses the same restrained Roblox material palette as the dungeon.

local ServerStorage = game:GetService("ServerStorage")

local Meshes = {}

export type Look = { Material: Enum.Material, Color: Color3 }

local function template(kind: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local creatures = assets and assets:FindFirstChild("Creatures")
	local m = creatures and creatures:FindFirstChild(kind)
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

function Meshes.Has(kind: string): boolean
	return template(kind) ~= nil
end

-- Clones the imported model, scales it to `height`, stands it on the ground
-- beneath `root` facing the root's look direction, and welds every piece to
-- the root. Returns { [pieceName] = { Part, Weld } } or nil.
function Meshes.Attach(kind: string, root: BasePart, groundY: number, height: number, looks: { [string]: Look }, yawDegrees: number?)
	local src = template(kind)
	if not src then
		return nil
	end
	local model = src:Clone()
	local _, size = model:GetBoundingBox()
	if size.Y <= 0 then
		return nil
	end
	model:ScaleTo(model:GetScale() * height / size.Y)

	-- Align the model's bounding box under the root.
	local bbCf, bbSize = model:GetBoundingBox()
	local yaw = CFrame.Angles(0, math.rad(yawDegrees or 0), 0)
	local rootFlat = CFrame.new(root.Position.X, groundY + bbSize.Y / 2, root.Position.Z)
		* (root.CFrame - root.CFrame.Position)
		* yaw
	local delta = rootFlat * bbCf:Inverse()

	local pieces = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local piece = string.gsub(d.Name, "^" .. kind .. "_", "")
			local cf = delta * d.CFrame
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = true
			d.Massless = true
			d.CollisionGroup = "Creature"
			d.CastShadow = true
			local look = looks[piece]
			if look then
				d.Material = look.Material
				d.Color = look.Color
			end
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
			d.CFrame = cf
			d.Name = piece
			local weld = Instance.new("Weld")
			weld.Part0 = root
			weld.Part1 = d
			weld.C0 = root.CFrame:ToObjectSpace(cf)
			weld.Parent = d
			d.Parent = root.Parent
			pieces[piece] = { Part = d, Weld = weld }
		end
	end
	model:Destroy()
	return pieces
end

return Meshes
