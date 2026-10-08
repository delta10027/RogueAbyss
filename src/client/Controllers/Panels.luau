--!strict
-- Full-screen panels: main menu (over the Sanctum scene), character
-- creation, pause menu, inventory, perk choice, journal, records,
-- how-to-play and the death screen (a Rogue-style tombstone).
-- Only one panel is open at a time (ClientState.Panel); while any panel is
-- open, gameplay input is ignored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local Spells = require(Shared.Definitions.Spells)
local Boons = require(Shared.Definitions.Boons)
local Discoveries = require(Shared.Definitions.Discoveries)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClientState = require(script.Parent.ClientState)
local UiKit = require(script.Parent.UiKit)
local Audio = require(script.Parent.Audio)

local C = UiKit.Colors

local Panels = {}

local deps: any
local gui: ScreenGui
local layer: Frame
local current: Frame? = nil
local selectedPackSlot = 1

local LETTERS = "abcdefghijklmnopqrstuvwxyz"

local function clear()
	if current then
		current:Destroy()
		current = nil
	end
end

local function close()
	clear()
	ClientState.SetPanel(nil)
end

local function panelFrame(width: number, height: number, opaque: boolean?): Frame
	clear()
	local back = UiKit.Frame(layer, {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = if opaque then 0.35 else 0.4,
		ZIndex = 30,
	})
	local f = UiKit.Ornate(back, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.94, 0, 0.92, 0),
		ZIndex = 31,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(width, height)
	limit.Parent = f
	f.Size = UDim2.new(0.94, 0, 0.92, 0)
	current = back
	return f
end

local function title(parent: Instance, text: string, y: number?)
	return UiKit.Text(parent, {
		Position = UDim2.fromOffset(0, y or 14),
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = UiKit.Display,
		TextSize = 36,
		TextColor3 = C.Gold,
		Text = text,
		ZIndex = 32,
	})
end

local function button(parent: Instance, text: string, props: { [string]: any }, onClick: () -> ()): TextButton
	props.ZIndex = props.ZIndex or 33
	local b = UiKit.Button(parent, text, props)
	b.Activated:Connect(function()
		Audio.Play("Clank", nil, 0.15, 1.8, 0.4)
		onClick()
	end)
	return b
end

local function scrolling(parent: Instance, pos: UDim2, size: UDim2): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Position = pos
	s.Size = size
	s.ScrollBarThickness = 4
	s.ScrollBarImageColor3 = C.LineDim
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ZIndex = 32
	s.Parent = parent
	UiKit.List(s, 6)
	return s
end

local function line(parent: Instance, text: string, size: number, color: Color3, order: number, display: boolean?): TextLabel
	return UiKit.Text(parent, {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = if display then UiKit.Display else UiKit.Body,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		LayoutOrder = order,
		ZIndex = 32,
	})
end

local function fetchProfile(): any
	local ok, profile = pcall(function()
		return Remotes.GetProfile:InvokeServer()
	end)
	return if ok then profile else nil
end

---------------------------------------------------------------------------
-- Main menu
---------------------------------------------------------------------------

function Panels.ShowMainMenu()
	ClientState.InRun = false
	ClientState.SetPanel("Menu")
	deps.Sanctum.ShowMenu()
	deps.Atmosphere.SetMode("Menu")
	clear()
	local back = UiKit.Frame(layer, { Name = "MainMenu", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 })
	current = back
	-- Shade the left side so the menu reads over the scene.
	local shade = UiKit.Frame(back, { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 30 })
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.45, 0.5), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = shade

	local col = UiKit.Frame(back, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 70, 0.5, 0),
		Size = UDim2.fromOffset(440, 560),
		ZIndex = 31,
	})
	local t = UiKit.Text(col, {
		Size = UDim2.new(1, 0, 0, 80),
		FontFace = UiKit.Display,
		TextSize = 70,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "ROGUE ABYSS",
		TextTransparency = 1,
		ZIndex = 32,
	})
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(Color3.fromRGB(255, 226, 160), Color3.fromRGB(176, 120, 60))
	tg.Rotation = 90
	tg.Parent = t
	TweenService:Create(t, TweenInfo.new(1.6), { TextTransparency = 0 }):Play()
	local rule = UiKit.Frame(col, { Position = UDim2.fromOffset(2, 82), Size = UDim2.fromOffset(300, 2), BackgroundColor3 = C.Line, ZIndex = 32 })
	UiKit.Studs(rule, 7)
	UiKit.Text(col, {
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 18,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Go as deep as you can. Grow stronger. Don't die.",
		ZIndex = 32,
	})

	local y = 150
	local function menuButton(text: string, onClick: () -> ())
		local b = button(col, text, {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(280, 50),
			TextSize = 27,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, onClick)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 20)
		pad.Parent = b
		y += 60
		return b
	end
	menuButton("New Character", function()
		Panels.ShowCreation()
	end)
	menuButton("How to Play", function()
		Panels.ShowHowTo("Menu")
	end)
	menuButton("Journal", function()
		Panels.ShowJournal("Menu")
	end)
	menuButton("Records", function()
		Panels.ShowRecords()
	end)

	local best = UiKit.Text(col, {
		Position = UDim2.fromOffset(0, y + 16),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 16,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 32,
	})
	task.spawn(function()
		local profile = fetchProfile()
		if profile and best.Parent then
			local s = profile.Stats
			best.Text = if s.Runs > 0
				then string.format("Deepest level: %d    Most gold: %d    Runs: %d", s.BestDepth, s.BestGold or 0, s.Runs)
				else "First time here? Read How to Play, or just make a character."
		end
	end)
	deps.Hud.FadeTo(0, 1)
end

-- Character creation, then the run starts with the chosen character.
function Panels.ShowCreation()
	clear()
	ClientState.InRun = false
	ClientState.SetPanel("Create")
	deps.Atmosphere.SetMode("Menu")
	local holder = UiKit.Frame(layer, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 })
	current = holder
	deps.Hud.FadeTo(1, 0)
	deps.Hud.FadeTo(0, 1.4)
	deps.Sanctum.Create(holder, ClientState.LastConfig, function(config)
		ClientState.LastConfig = config
		Panels.StartRun(config)
	end, function()
		Panels.ShowMainMenu()
	end)
end

function Panels.StartRun(config: any)
	clear()
	ClientState.SetPanel(nil)
	deps.Hud.FadeTo(1, 0.6)
	task.delay(0.6, function()
		deps.Sanctum.Hide()
		deps.Atmosphere.SetMode("Dungeon")
		Remotes.RequestRestart:FireServer(config)
	end)
end

function Panels.ShowRecords()
	local f = panelFrame(480, 440, true)
	title(f, "Records")
	local list = scrolling(f, UDim2.fromOffset(30, 70), UDim2.new(1, -60, 1, -140))
	line(list, "Loading...", 18, C.Dim, 1)
	button(f, "Back", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(180, 40) }, function()
		Panels.ShowMainMenu()
	end)
	task.spawn(function()
		local profile = fetchProfile()
		if not profile or not list.Parent then
			return
		end
		for _, c in list:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local s = profile.Stats
		local rows = {
			{ "Runs started", s.Runs },
			{ "Deaths", s.Deaths },
			{ "Deepest dungeon level", s.BestDepth },
			{ "Most gold in one run", s.BestGold or 0 },
			{ "Levels cleared", s.FloorsCleared },
			{ "Monsters defeated", s.Kills or 0 },
			{ "Treasures found", s.Curios },
			{ "Journal entries", string.format("%d of %d", #profile.Known, #Discoveries.List) },
		}
		for i, r in rows do
			line(list, string.format("%-26s %s", r[1], tostring(r[2])), 19, C.Text, i)
		end
	end)
end

---------------------------------------------------------------------------
-- How to play
---------------------------------------------------------------------------

local HOW_TO = {
	{ "The goal", "Find the stairs down on each level and go as deep as you can. Your score is the gold you carry and the deepest level you reach. When you die the run is over - every run is a new character and a new dungeon." },
	{ "Fighting", "Click to attack. Swings cost stamina, so mashing leaves you winded and helpless - pace yourself. Quick clicks chain into a 3-hit combo whose last hit is a strong finisher. Hold the button to charge a heavy attack that breaks shields and stuns. Monsters flash and show a warning on the floor before they strike: dash away (Space) or step back, then punish them." },
	{ "Weapons", "Every weapon swings differently and has its own trick (dagger backstabs, mace stuns, spear pierces...) and its own skill on Q. Magic staffs are weak in melee but have a built-in spell and boost your magic." },
	{ "Spells", "Spells cost mana and live in spell slots (Z X C V B). Read spellbooks to learn new ones. You get more slots as you level up; forget a spell in your inventory to make room." },
	{ "Growing stronger", "Defeating monsters and going downstairs gives experience. Each level gives more health and mana and lets you choose a perk (press L). Better gear, enchant scrolls and potions of strength make you stronger still - and it shows on your character." },
	{ "Your lantern", "Your lantern lights the way and burns oil. Monsters see you at the edge of its light: dim it (F) to sneak past, refill it with an oil flask (R)." },
	{ "Sneaking", "Hold Shift to sneak. Your footsteps are silent and monsters have a harder time spotting you. Hitting an unaware monster from behind is a backstab." },
	{ "Loot", "Pick things up with E. Open chests, smash pots and crates, and watch out for red oil barrels - they explode. The ornate chest in an iron vault holds the best loot; its rusted key is on the same level." },
	{ "Level rules", "Every dungeon level has one special rule, written on the plaque in the first room. Read it." },
}

function Panels.ShowHowTo(returnTo: string?)
	local f = panelFrame(660, 660, returnTo == "Menu")
	ClientState.SetPanel(if returnTo == "Menu" then "Menu" else "HowTo")
	title(f, "How to Play")
	local list = scrolling(f, UDim2.fromOffset(30, 64), UDim2.new(1, -60, 1, -130))
	for i, h in HOW_TO do
		line(list, h[1], 23, C.Gold, i * 2 - 1, true)
		line(list, h[2], 17, C.Text, i * 2)
	end
	button(f, "Back", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(180, 40) }, function()
		if returnTo == "Menu" then
			Panels.ShowMainMenu()
		elseif returnTo == "Pause" then
			Panels.ShowPause()
		else
			close()
		end
	end)
end

---------------------------------------------------------------------------
-- Pause menu
---------------------------------------------------------------------------

function Panels.ShowPause()
	if not ClientState.InRun then
		return
	end
	local f = panelFrame(340, 400)
	ClientState.SetPanel("Pause")
	title(f, "Paused")
	local y = 70
	local function b(text: string, onClick: () -> ())
		button(f, text, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(240, 42) }, onClick)
		y += 52
	end
	b("Resume", close)
	b("Inventory", function()
		Panels.ShowInventory()
	end)
	b("Perks", function()
		Panels.ShowPerks()
	end)
	b("Journal", function()
		Panels.ShowJournal("Pause")
	end)
	b("How to Play", function()
		Panels.ShowHowTo("Pause")
	end)
	b("Quit to Main Menu", function()
		Panels.ConfirmQuit()
	end)
end

function Panels.ConfirmQuit()
	local f = panelFrame(400, 210)
	ClientState.SetPanel("Pause")
	title(f, "Quit this run?")
	UiKit.Text(f, {
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 0, 50),
		TextSize = 17,
		Text = "Your current run will end. Journal entries you've earned are kept.",
		ZIndex = 32,
	})
	button(f, "Quit", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -8, 1, -18), Size = UDim2.fromOffset(140, 40) }, function()
		Remotes.RequestMenu:FireServer()
		Panels.ShowMainMenu()
	end)
	button(f, "Cancel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 8, 1, -18), Size = UDim2.fromOffset(140, 40) }, function()
		Panels.ShowPause()
	end)
end

function Panels.TogglePause()
	local p = ClientState.Panel
	if p == "Menu" or p == "Summary" or p == "Create" then
		return
	end
	if p then
		close()
	else
		Panels.ShowPause()
	end
end

---------------------------------------------------------------------------
-- Perks (level-up choice)
---------------------------------------------------------------------------

function Panels.ShowPerks()
	local snap = ClientState.Snapshot
	if not ClientState.InRun or not snap then
		return
	end
	local f = panelFrame(860, 520)
	ClientState.SetPanel("Perks")
	local pending = snap.PendingPerks or 0
	title(f, if pending > 0 then "Choose a Perk" else "Your Perks")
	UiKit.Text(f, {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		TextColor3 = C.Dim,
		Text = if pending > 0 then string.format("You have %d perk%s to choose. Pick one of these three.", pending, if pending == 1 then "" else "s") else "You gain a perk each time you level up.",
		ZIndex = 32,
	})
	if pending > 0 and snap.PerkOffer then
		local row = UiKit.Frame(f, { BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 92), Size = UDim2.new(1, -60, 0, 220), ZIndex = 32 })
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(1 / 3, -14, 1, 0)
		grid.CellPadding = UDim2.fromOffset(20, 0)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.Parent = row
		for _, id in snap.PerkOffer do
			local p = Boons.PerkById[id]
			if p then
				local card = Instance.new("TextButton")
				card.Text = ""
				card.AutoButtonColor = false
				card.BackgroundColor3 = Color3.new(1, 1, 1)
				card.ZIndex = 33
				card.Parent = row
				local grad = UiKit.Gradient(card, Color3.fromRGB(50, 38, 28), Color3.fromRGB(14, 11, 10), 90)
				local stroke = UiKit.Stroke(card, C.Line, 1.5)
				UiKit.Studs(card, 8)
				local have = (snap.Perks and snap.Perks[id]) or 0
				UiKit.Text(card, { Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 34), FontFace = UiKit.Display, TextSize = 28, TextColor3 = C.Gold, Text = p.Name, ZIndex = 34 })
				UiKit.Text(card, { Position = UDim2.fromOffset(16, 72), Size = UDim2.new(1, -32, 0, 90), TextSize = 18, Text = p.Description, ZIndex = 34 })
				UiKit.Text(card, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -12), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = C.Dim, Text = if have > 0 then string.format("You have %d of %d", have, p.MaxStacks or 1) else "", ZIndex = 34 })
				card.MouseEnter:Connect(function()
					stroke.Color = C.Gold
					grad.Color = ColorSequence.new(Color3.fromRGB(90, 66, 40), Color3.fromRGB(20, 15, 12))
				end)
				card.MouseLeave:Connect(function()
					stroke.Color = C.Line
					grad.Color = ColorSequence.new(Color3.fromRGB(50, 38, 28), Color3.fromRGB(14, 11, 10))
				end)
				card.Activated:Connect(function()
					Remotes.RequestPerk:FireServer(id)
					Audio.Play("Shimmer", nil, 0.4, 1, 2.5)
					close()
				end)
			end
		end
	end
	local list = scrolling(f, UDim2.fromOffset(30, if pending > 0 then 330 else 92), UDim2.new(1, -60, 1, if pending > 0 then -390 else -150))
	local o = 0
	for id, n in snap.Perks or {} do
		local p = Boons.PerkById[id]
		if p then
			o += 1
			line(list, string.format("%s%s - %s", p.Name, if n > 1 then (" x" .. n) else "", p.Description), 16, C.Text, o)
		end
	end
	if o == 0 then
		line(list, "No perks yet.", 16, C.Dim, 1)
	end
	button(f, "Close", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(160, 38) }, close)
end

function Panels.TogglePerks()
	if ClientState.Panel == "Perks" then
		close()
	elseif ClientState.Panel == nil or ClientState.Panel == "Pause" then
		Panels.ShowPerks()
	end
end

---------------------------------------------------------------------------
-- Inventory
---------------------------------------------------------------------------

local function weaponLine(e): string
	local def = Items[e.Id]
	local w = def and def.Weapon
	if not w then
		return ""
	end
	return string.format("Damage %d · Reach %d · %.1f swings/s · %d stamina", w.Damage + (e.Bonus or 0), w.Range, 1 / w.Cooldown, w.Stamina)
end

local function useVerb(def): string
	if def.Use == "Equip" then
		return if def.Category == "Weapon" then "Wield" else "Wear"
	elseif def.Use == "Drink" then
		return "Drink"
	elseif def.Use == "Read" then
		return if def.Category == "Book" then "Learn" else "Read"
	elseif def.Use == "Eat" then
		return "Eat"
	elseif def.Use == "Throw" then
		return "Throw"
	end
	return "Examine"
end

function Panels.ShowInventory()
	if not ClientState.InRun then
		return
	end
	local snap = ClientState.Snapshot
	if not snap then
		return
	end
	local f = panelFrame(900, 620)
	ClientState.SetPanel("Inventory")
	title(f, "Inventory")
	UiKit.Text(f, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 24),
		Size = UDim2.fromOffset(220, 20),
		TextSize = 15,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Press I or Tab to close",
		ZIndex = 32,
	})

	local left = UiKit.Frame(f, { BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 64), Size = UDim2.new(0.46, -26, 1, -84), ZIndex = 32 })
	UiKit.Text(left, {
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = UiKit.BodyBold,
		TextSize = 17,
		TextColor3 = C.Parchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format("Pack (%d slots, the first %d are your hotbar)", Config.Player.PackSlots, Config.Player.HotbarSlots),
		ZIndex = 32,
	})
	local rows = UiKit.Frame(left, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28), ZIndex = 32 })
	UiKit.List(rows, 3)
	for i = 1, Config.Player.PackSlots do
		local e = snap.Pack[i]
		local def = if e then Items[e.Id] else nil
		local b = Instance.new("TextButton")
		b.AutoButtonColor = true
		b.BackgroundColor3 = if i == selectedPackSlot then Color3.fromRGB(60, 46, 32) else C.Ink
		b.BackgroundTransparency = if i <= Config.Player.HotbarSlots then 0.1 else 0.35
		b.BorderSizePixel = 0
		b.Size = UDim2.new(1, 0, 0, 32)
		b.LayoutOrder = i
		b.FontFace = UiKit.Body
		b.TextSize = 17
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextColor3 = if e then C.Text else C.LineDim
		local hot = if i <= Config.Player.HotbarSlots then ("     - hotbar " .. i) else ""
		b.Text = "        " .. string.sub(LETTERS, i, i) .. ")  " .. (if e then Items.EntryName(e) else "(empty)") .. hot
		b.ZIndex = 33
		b.Parent = rows
		if def then
			UiKit.Frame(b, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(10, 10), Rotation = 45, BackgroundColor3 = def.Color, ZIndex = 34 })
		end
		if i == selectedPackSlot then
			UiKit.Stroke(b, C.Gold, 1)
		end
		b.Activated:Connect(function()
			selectedPackSlot = i
			Panels.ShowInventory()
		end)
	end

	local right = scrolling(f, UDim2.new(0.46, 6, 0, 64), UDim2.new(0.54, -28, 1, -84))
	local o = 0
	local function add(text: string, size: number, color: Color3, display: boolean?)
		o += 1
		return line(right, text, size, color, o, display)
	end
	add("Equipped", 23, C.Gold, true)
	local wdef = Items[snap.Weapon.Id]
	add("Weapon: " .. Items.EntryName(snap.Weapon) .. "   (" .. weaponLine(snap.Weapon) .. ")", 16, C.Text)
	if wdef and wdef.Quirk then
		add("   Quirk: " .. wdef.Quirk, 14, C.Dim)
	end
	if wdef and wdef.Special then
		add(string.format("   Skill [Q] %s: %s", wdef.Special.Name, wdef.Special.Description), 14, C.Dim)
	end
	add("Armor: " .. (if snap.ArmorItem then Items.EntryName(snap.ArmorItem) else "none") .. "   (armor " .. snap.Armor .. ")", 16, C.Text)

	o += 1
	local selBox = UiKit.Frame(right, {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.2,
		LayoutOrder = o,
		ZIndex = 32,
	})
	UiKit.Stroke(selBox, C.LineDim, 1)
	UiKit.Pad(selBox, 10)
	UiKit.List(selBox, 6)
	local sel = snap.Pack[selectedPackSlot]
	local def = if sel then Items[sel.Id] else nil
	if sel and def then
		line(selBox, Items.EntryName(sel), 22, C.Parchment, 1, true)
		local desc = def.Description
		if def.Category == "Book" and sel.Spell and Spells.ById[sel.Spell] then
			local s = Spells.ById[sel.Spell]
			desc = string.format("%s (%d mana, %ds cooldown)\n%s", s.Name, s.Mana, s.Cooldown, s.Description)
		end
		line(selBox, desc, 16, C.Text, 2)
		if def.Weapon then
			line(selBox, weaponLine(sel) .. "\nYou have: " .. weaponLine(snap.Weapon), 14, C.Dim, 3)
			if def.Quirk then
				line(selBox, "Quirk: " .. def.Quirk, 14, C.Dim, 3)
			end
			if def.Special then
				line(selBox, "Skill [Q] " .. def.Special.Name .. ": " .. def.Special.Description, 14, C.Dim, 3)
			end
		elseif def.Armor then
			line(selBox, string.format("Armor %d  (you have %d)", def.Armor + (sel.Bonus or 0), snap.Armor), 14, C.Dim, 3)
		end
		local actions = UiKit.Frame(selBox, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 4, ZIndex = 32 })
		UiKit.List(actions, 6, true)
		local slot = selectedPackSlot
		local function act(text: string, w: number, onClick: () -> ())
			local b = button(actions, text, { Size = UDim2.fromOffset(w, 32), TextSize = 18 }, onClick)
			b.LayoutOrder = #actions:GetChildren()
		end
		if def.Use ~= "Passive" then
			act(useVerb(def), 90, function()
				if def.Use == "Equip" then
					Remotes.RequestInventory:FireServer("Equip", slot)
				elseif def.Use == "Throw" then
					if slot > Config.Player.HotbarSlots then
						Remotes.RequestInventory:FireServer("Swap", slot, ClientState.SelectedSlot)
					else
						deps.Input.SelectSlot(slot)
					end
					close()
					deps.Hud.Message("Right click to throw it where you aim.")
				else
					Remotes.RequestUseItem:FireServer(slot, ClientState.AimPoint)
				end
			end)
		end
		act("Drop", 80, function()
			Remotes.RequestInventory:FireServer("Drop", slot)
		end)
		local hot = UiKit.Frame(selBox, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 5, ZIndex = 32 })
		UiKit.List(hot, 6, true)
		UiKit.Text(hot, { Size = UDim2.fromOffset(110, 30), TextSize = 15, TextColor3 = C.Dim, Text = "Move to slot:", LayoutOrder = 0, ZIndex = 32 })
		for k = 1, Config.Player.HotbarSlots do
			local b = button(hot, tostring(k), { Size = UDim2.fromOffset(34, 28), TextSize = 17, FontFace = UiKit.Body }, function()
				if k ~= slot then
					Remotes.RequestInventory:FireServer("Swap", slot, k)
					selectedPackSlot = k
				end
			end)
			b.LayoutOrder = k
		end
	else
		line(selBox, "Select an item on the left to see what it does.", 16, C.Dim, 1)
	end

	add(" ", 6, C.Dim)
	add(string.format("Spells  (%d of %d slots)", #(snap.Spells or {}), snap.SpellSlots or 0), 23, C.Gold, true)
	for i, id in snap.Spells or {} do
		local s = Spells.ById[id]
		if s then
			o += 1
			local rowF = UiKit.Frame(right, { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 44), LayoutOrder = o, ZIndex = 32 })
			local icon = UiKit.Frame(rowF, { BackgroundTransparency = 1, Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(0, 6), ZIndex = 33 })
			UiKit.Glyph(icon, s.Glyph, s.Color, 2)
			UiKit.Text(rowF, { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -130, 0, 20), FontFace = UiKit.BodyBold, TextSize = 16, TextColor3 = C.Parchment, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("[%s] %s  ·  %d mana", Config.Spells.Keys[i] or "?", s.Name, s.Mana), ZIndex = 33 })
			UiKit.Text(rowF, { Position = UDim2.fromOffset(40, 20), Size = UDim2.new(1, -130, 0, 24), TextSize = 13, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = s.Description, ZIndex = 33 })
			if #snap.Spells > 1 then
				button(rowF, "Forget", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Size = UDim2.fromOffset(80, 28), TextSize = 16 }, function()
					Remotes.RequestAbility:FireServer("Forget", i)
				end)
			end
		end
	end
	add("Read spellbooks to learn more spells. You get more slots at levels " .. table.concat(Config.Spells.SlotLevels, ", ") .. ".", 13, C.Dim)
	if (snap.PendingPerks or 0) > 0 then
		add(" ", 6, C.Dim)
		add("You have a perk to choose - press L.", 16, C.Gold)
	end
end

function Panels.ToggleInventory()
	if ClientState.Panel == "Inventory" then
		close()
	elseif ClientState.Panel == nil or ClientState.Panel == "Pause" then
		Panels.ShowInventory()
	end
end

---------------------------------------------------------------------------
-- Journal
---------------------------------------------------------------------------

function Panels.ShowJournal(returnTo: string?)
	local f = panelFrame(580, 640, returnTo == "Menu")
	ClientState.SetPanel(if returnTo == "Menu" then "Menu" else "Journal")
	title(f, "Journal")
	local list = scrolling(f, UDim2.fromOffset(26, 64), UDim2.new(1, -52, 1, -128))
	button(f, "Back", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(160, 38) }, function()
		if returnTo == "Menu" then
			Panels.ShowMainMenu()
		elseif returnTo == "Pause" then
			Panels.ShowPause()
		else
			close()
		end
	end)
	local function fill(knownList: { string })
		local known: { [string]: boolean } = {}
		for _, id in knownList do
			known[id] = true
		end
		local count = 0
		for _, def in Discoveries.List do
			if known[def.Id] then
				count += 1
				line(list, def.Title .. "   ·   " .. string.lower(def.Category), 21, C.Gold, def.Order * 2, true)
				line(list, def.Text, 16, C.Text, def.Order * 2 + 1)
			else
				line(list, "?  (not discovered yet - a " .. string.lower(def.Category) .. ")", 16, C.LineDim, def.Order * 2)
			end
		end
		line(list, string.format("%d of %d entries discovered", count, #Discoveries.List), 15, C.Dim, 99999)
	end
	local snap = ClientState.Snapshot
	if ClientState.InRun and snap and snap.Known then
		fill(snap.Known)
	else
		task.spawn(function()
			local profile = fetchProfile()
			if list.Parent then
				fill(if profile then profile.Known else {})
			end
		end)
	end
end

function Panels.ToggleJournal()
	if ClientState.Panel == "Journal" then
		close()
	elseif ClientState.Panel == nil or ClientState.Panel == "Pause" then
		Panels.ShowJournal()
	end
end

---------------------------------------------------------------------------
-- Death screen: a tombstone, as in the original Rogue.
---------------------------------------------------------------------------

function Panels.ShowSummary(s)
	ClientState.SetPanel("Summary")
	clear()
	local back = UiKit.Frame(layer, { Name = "Summary", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2, ZIndex = 30 })
	current = back

	local stone = UiKit.Frame(back, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(300, 270),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 31,
	})
	UiKit.Gradient(stone, Color3.fromRGB(120, 116, 110), Color3.fromRGB(70, 66, 62), 90)
	UiKit.Corner(stone, 110)
	local square = UiKit.Frame(stone, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 31 })
	UiKit.Gradient(square, Color3.fromRGB(96, 92, 87), Color3.fromRGB(70, 66, 62), 90)
	UiKit.Stroke(stone, Color3.fromRGB(50, 46, 42), 2)
	local engrave = Color3.fromRGB(30, 26, 24)
	local function carve(text: string, y: number, size: number, display: boolean?)
		UiKit.Text(stone, { Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, size + 4), FontFace = if display then UiKit.Display else UiKit.BodyBold, TextSize = size, TextColor3 = engrave, Text = text, ZIndex = 32 })
	end
	carve("REST", 34, 30, true)
	carve("IN", 66, 26, true)
	carve("PEACE", 94, 30, true)
	carve(s.Name or "", 138, 20)
	carve(string.format("%d gold", s.Gold or 0), 164, 18)
	carve(string.lower(s.CauseText or "killed"), 190, 17)
	carve("on dungeon level " .. s.Depth, 214, 17)

	local panel = UiKit.Ornate(back, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 306),
		Size = UDim2.new(0, 600, 1, -318),
		ZIndex = 31,
	})
	local list = scrolling(panel, UDim2.fromOffset(22, 14), UDim2.new(1, -44, 1, -78))
	local o = 0
	local function add(text: string, size: number, color: Color3, display: boolean?)
		o += 1
		line(list, text, size, color, o, display)
	end
	local function plural(n: number, word: string): string
		return n .. " " .. word .. (if n == 1 then "" else "s")
	end
	add(string.format("Experience level %d  ·  %s defeated  ·  %s opened  ·  %d:%02d played",
		s.Level or 1, plural(s.Kills or 0, "monster"), plural(s.Chests or 0, "chest"), s.Duration // 60, s.Duration % 60), 16, C.Text)
	add(string.format("Wielding: %s  ·  Deepest ever: level %d  ·  Most gold ever: %d", s.Weapon or "?", math.max(1, s.BestDepth), s.BestGold or 0), 15, C.Dim)
	if s.Spells and #s.Spells > 0 then
		add("Spells: " .. table.concat(s.Spells, ", "), 15, C.Dim)
	end
	if s.Perks and #s.Perks > 0 then
		add("Perks: " .. table.concat(s.Perks, ", "), 15, C.Dim)
	end
	if s.Hint then
		add(s.Hint, 17, C.Amber)
	end
	if #s.Discoveries > 0 then
		add("Learned this run", 20, C.Gold, true)
		for _, d in s.Discoveries do
			add("·  " .. d, 16, C.Text)
		end
	end
	if #s.Events > 0 then
		add("What happened", 20, C.Gold, true)
		for _, e in s.Events do
			add("·  " .. e, 16, C.Text)
		end
	end
	add("seed " .. tostring(s.Seed), 13, C.LineDim)

	button(panel, "New Character", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, -195, 1, -14), Size = UDim2.fromOffset(180, 44) }, function()
		Panels.ShowCreation()
	end)
	button(panel, "Same Again", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(180, 44) }, function()
		Panels.StartRun(ClientState.LastConfig)
	end)
	button(panel, "Main Menu", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 195, 1, -14), Size = UDim2.fromOffset(180, 44) }, function()
		Remotes.RequestMenu:FireServer()
		Panels.ShowMainMenu()
	end)
	deps.Hud.FadeTo(0.5, 0.6)
end

function Panels.Start(dependencies)
	deps = dependencies
	gui = deps.Hud.Gui()
	layer = UiKit.Frame(gui, { Name = "Panels", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 })

	-- Keep open panels up to date (deferred so updates coalesce).
	local pending = false
	Remotes.StateUpdate.OnClientEvent:Connect(function()
		if (ClientState.Panel == "Inventory" or ClientState.Panel == "Perks") and not pending then
			pending = true
			task.defer(function()
				pending = false
				if ClientState.Panel == "Inventory" then
					Panels.ShowInventory()
				elseif ClientState.Panel == "Perks" then
					Panels.ShowPerks()
				end
			end)
		end
	end)

	Remotes.RunEnded.OnClientEvent:Connect(function(s)
		ClientState.InRun = false
		Panels.ShowSummary(s)
	end)
	Remotes.FloorEntered.OnClientEvent:Connect(function(_info)
		deps.Sanctum.Hide()
		deps.Atmosphere.SetMode("Dungeon")
		if ClientState.Panel == "Summary" or ClientState.Panel == "Menu" or ClientState.Panel == "Create" then
			close()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or ClientState.Panel ~= "Summary" then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			Panels.StartRun(ClientState.LastConfig)
		end
	end)

	Panels.ShowMainMenu()
end

return Panels
