--!strict
-- Full-screen panels: main menu, pause menu, inventory, journal, records,
-- how-to-play and the death screen (a Rogue-style tombstone).
-- Only one panel is open at a time (ClientState.Panel); while any panel is
-- open, gameplay input is ignored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Definitions.Items)
local Abilities = require(Shared.Definitions.Abilities)
local Discoveries = require(Shared.Definitions.Discoveries)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClientState = require(script.Parent.ClientState)
local UiKit = require(script.Parent.UiKit)

local C = UiKit.Colors

local Panels = {}

local deps: any
local gui: ScreenGui
local layer: Frame -- holds whichever panel is open
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
		BackgroundTransparency = if opaque then 0 else 0.45,
		ZIndex = 30,
	})
	local f = UiKit.Frame(back, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, width, 0, height),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.03,
		ZIndex = 31,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(width, height)
	limit.Parent = f
	f.Size = UDim2.new(0.94, 0, 0.92, 0)
	UiKit.Stroke(f, C.Line, 1)
	current = back
	return f
end

local function title(parent: Instance, text: string, y: number?)
	return UiKit.Text(parent, {
		Position = UDim2.fromOffset(0, y or 14),
		Size = UDim2.new(1, 0, 0, 36),
		FontFace = UiKit.Display,
		TextSize = 32,
		TextColor3 = C.Parchment,
		Text = text,
		ZIndex = 32,
	})
end

local function button(parent: Instance, text: string, props: { [string]: any }, onClick: () -> ()): TextButton
	props.ZIndex = props.ZIndex or 33
	local b = UiKit.Button(parent, text, props)
	b.Activated:Connect(onClick)
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
	clear()
	local back = UiKit.Frame(layer, {
		Name = "MainMenu",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 7, 7),
		ZIndex = 30,
	})
	current = back
	-- A faint lantern glow behind the title.
	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new(Color3.fromRGB(40, 28, 18), Color3.fromRGB(8, 7, 7))
	glow.Rotation = 90
	glow.Parent = back

	local col = UiKit.Frame(back, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 520),
		ZIndex = 31,
	})
	local t = UiKit.Text(col, {
		Size = UDim2.new(1, 0, 0, 70),
		FontFace = UiKit.Display,
		TextSize = 64,
		TextColor3 = C.Parchment,
		Text = "ROGUE ABYSS",
		TextTransparency = 1,
		ZIndex = 32,
	})
	TweenService:Create(t, TweenInfo.new(1.4), { TextTransparency = 0 }):Play()
	UiKit.Text(col, {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 17,
		TextColor3 = C.Dim,
		Text = "Go as deep as you can. Collect gold. Don't die.",
		ZIndex = 32,
	})

	local y = 140
	local function menuButton(text: string, onClick: () -> ())
		button(col, text, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(260, 48),
			TextSize = 26,
		}, onClick)
		y += 60
	end
	menuButton("Play", function()
		Panels.StartRun()
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
		Position = UDim2.fromOffset(0, y + 20),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		TextColor3 = C.Dim,
		Text = "",
		ZIndex = 32,
	})
	task.spawn(function()
		local profile = fetchProfile()
		if profile and best.Parent then
			local s = profile.Stats
			best.Text = if s.Runs > 0
				then string.format("Deepest level: %d   ·   Most gold: %d   ·   Runs: %d", s.BestDepth, s.BestGold or 0, s.Runs)
				else "First time here? Read How to Play, or just press Play."
		end
	end)
	deps.Hud.FadeTo(0, 0.6)
end

function Panels.StartRun()
	clear()
	ClientState.SetPanel(nil)
	deps.Hud.FadeTo(1, 0.15)
	Remotes.RequestRestart:FireServer()
end

function Panels.ShowRecords()
	local f = panelFrame(460, 420, true)
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
	{ "The goal", "Find the stairs down on each level and go as deep as you can. Your score is the gold you carry and the deepest level you reach. When you die, the run is over - every run is a new dungeon." },
	{ "Your lantern", "Your lantern lights the way and slowly burns oil. Press F to dim it (uses less oil and helps you stay hidden). Press R to refill it with an oil flask." },
	{ "Fighting", "Left click to attack with your weapon. Each weapon has a different damage, reach and speed. Monsters raise their arms or weapon before they hit - step back, then strike." },
	{ "Sneaking", "Hold Shift to sneak. Sneaking is slow but your footsteps make no sound, and monsters have a harder time seeing you." },
	{ "Items", "Pick things up with E. Your pack holds 12 items; the first 4 are on your hotbar (keys 1-4, right click to use). Open your inventory with I to equip weapons and armor, drink potions, read scrolls or drop things." },
	{ "Chests and gold", "Open chests for gold and gear. The ornate chest inside an iron vault holds the best loot - its rusted key is somewhere on the same level." },
	{ "Experience", "Defeating monsters and going downstairs gives experience. Each new experience level gives more max health, and unlocks Dash (level 2) and spells (levels 3-6)." },
	{ "Level rules", "Every dungeon level has one special rule, written on the plaque in the first room. Read it - knowing the rule is often the difference between life and death." },
	{ "The journal", "Everything you learn about monsters, rules and places is written in your journal (J) and kept between runs." },
}

function Panels.ShowHowTo(returnTo: string?)
	local f = panelFrame(620, 640, returnTo == "Menu")
	ClientState.SetPanel(if returnTo == "Menu" then "Menu" else "HowTo")
	title(f, "How to Play")
	local list = scrolling(f, UDim2.fromOffset(30, 64), UDim2.new(1, -60, 1, -130))
	for i, h in HOW_TO do
		line(list, h[1], 22, C.Parchment, i * 2 - 1, true)
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
	local f = panelFrame(340, 350)
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
	local f = panelFrame(380, 200)
	ClientState.SetPanel("Pause")
	title(f, "Quit this run?")
	UiKit.Text(f, {
		Position = UDim2.fromOffset(20, 56),
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
	if p == "Menu" or p == "Summary" then
		return
	end
	if p then
		close()
	else
		Panels.ShowPause()
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
	return string.format("Damage %d · Reach %d · %.1f swings/sec", w.Damage + (e.Bonus or 0), w.Range, 1 / w.Cooldown)
end

local function useVerb(def): string
	if def.Use == "Equip" then
		return if def.Category == "Weapon" then "Wield" else "Wear"
	elseif def.Use == "Drink" then
		return "Drink"
	elseif def.Use == "Read" then
		return "Read"
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
	local f = panelFrame(820, 600)
	ClientState.SetPanel("Inventory")
	title(f, "Inventory")
	UiKit.Text(f, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 22),
		Size = UDim2.fromOffset(220, 20),
		TextSize = 15,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Press I or Tab to close",
		ZIndex = 32,
	})

	-- Left: the pack, lettered like Rogue.
	local left = UiKit.Frame(f, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 64),
		Size = UDim2.new(0.5, -30, 1, -84),
		ZIndex = 32,
	})
	UiKit.Text(left, {
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = UiKit.BodyBold,
		TextSize = 18,
		TextColor3 = C.Parchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format("Pack (%d slots - the first %d are your hotbar)", Config.Player.PackSlots, Config.Player.HotbarSlots),
		ZIndex = 32,
	})
	local rows = UiKit.Frame(left, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28), ZIndex = 32 })
	UiKit.List(rows, 3)
	for i = 1, Config.Player.PackSlots do
		local e = snap.Pack[i]
		local b = Instance.new("TextButton")
		b.AutoButtonColor = true
		b.BackgroundColor3 = if i == selectedPackSlot then Color3.fromRGB(48, 40, 32) else C.Ink
		b.BackgroundTransparency = if i <= Config.Player.HotbarSlots then 0.1 else 0.4
		b.BorderSizePixel = 0
		b.Size = UDim2.new(1, 0, 0, 30)
		b.LayoutOrder = i
		b.FontFace = UiKit.Body
		b.TextSize = 17
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextColor3 = if e then C.Text else C.LineDim
		local hot = if i <= Config.Player.HotbarSlots then ("     - hotbar " .. i) else ""
		b.Text = "  " .. string.sub(LETTERS, i, i) .. ")  " .. (if e then Items.EntryName(e) else "(empty)") .. hot
		b.ZIndex = 33
		b.Parent = rows
		if i == selectedPackSlot then
			UiKit.Stroke(b, C.Parchment, 1)
		end
		b.Activated:Connect(function()
			selectedPackSlot = i
			Panels.ShowInventory()
		end)
	end

	-- Right: equipment, stats, the selected item and abilities.
	local right = scrolling(f, UDim2.new(0.5, 10, 0, 64), UDim2.new(0.5, -30, 1, -84))
	local o = 0
	local function add(text: string, size: number, color: Color3, display: boolean?)
		o += 1
		return line(right, text, size, color, o, display)
	end
	add("Equipped", 22, C.Parchment, true)
	add("Weapon: " .. Items.EntryName(snap.Weapon) .. "   (" .. weaponLine(snap.Weapon) .. ")", 16, C.Text)
	add("Armor: " .. (if snap.ArmorItem then Items.EntryName(snap.ArmorItem) else "none") .. "   (armor " .. snap.Armor .. ")", 16, C.Text)
	add(string.format("Health %d/%d   Str %d   Damage %d   Gold %d", snap.HP, snap.MaxHP, snap.Str, snap.Damage, snap.Gold), 16, C.Dim)

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
	local def = sel and Items[sel.Id]
	if sel and def then
		line(selBox, Items.EntryName(sel), 22, C.Parchment, 1, true)
		line(selBox, def.Description, 16, C.Text, 2)
		if def.Weapon then
			line(selBox, weaponLine(sel) .. "\nYou have: " .. weaponLine(snap.Weapon), 15, C.Dim, 3)
		elseif def.Armor then
			line(selBox, string.format("Armor %d  (you have %d)", def.Armor + (sel.Bonus or 0), snap.Armor), 15, C.Dim, 3)
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
					-- Throwing needs aim: put it in the hand and close the panel.
					if slot > Config.Player.HotbarSlots then
						Remotes.RequestInventory:FireServer("Swap", slot, ClientState.SelectedSlot)
						slot = ClientState.SelectedSlot
					else
						deps.Input.SelectSlot(slot)
					end
					close()
					deps.Hud.Message("Right click to throw it where you aim.")
					return
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
	add("Abilities & spells", 22, C.Parchment, true)
	for _, a in Abilities.List do
		local unlocked = snap.Level >= a.Level
		add(string.format("%s  [%s]  %s", a.Name, a.Key, if unlocked then "" else ("- unlocks at level " .. a.Level)), 17, if unlocked then C.Text else C.LineDim)
		add(a.Description .. string.format("  (cooldown %ds)", a.Cooldown), 14, if unlocked then C.Dim else C.LineDim)
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
	local f = panelFrame(560, 620, returnTo == "Menu")
	ClientState.SetPanel(if returnTo == "Menu" then "Menu" else "Journal")
	title(f, "Journal")
	local list = scrolling(f, UDim2.fromOffset(26, 60), UDim2.new(1, -52, 1, -124))
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
				line(list, def.Title .. "   ·   " .. string.lower(def.Category), 20, C.Parchment, def.Order * 2, true)
				line(list, def.Text, 16, C.Text, def.Order * 2 + 1)
			else
				line(list, "?  (not discovered yet - a " .. string.lower(def.Category) .. ")", 16, C.LineDim, def.Order * 2)
			end
		end
		line(list, string.format("%d of %d entries discovered", count, #Discoveries.List), 15, C.Dim, 9999)
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
	local back = UiKit.Frame(layer, {
		Name = "Summary",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		ZIndex = 30,
	})
	current = back

	local stone = UiKit.Frame(back, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 28),
		Size = UDim2.fromOffset(300, 270),
		BackgroundColor3 = Color3.fromRGB(96, 92, 86),
		ZIndex = 31,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 110)
	corner.Parent = stone
	UiKit.Frame(stone, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(96, 92, 86),
		ZIndex = 31,
	})
	UiKit.Stroke(stone, Color3.fromRGB(60, 56, 52), 2)
	local engrave = Color3.fromRGB(34, 30, 28)
	local function carve(text: string, y: number, size: number, display: boolean?)
		UiKit.Text(stone, {
			Position = UDim2.fromOffset(16, y),
			Size = UDim2.new(1, -32, 0, size + 4),
			FontFace = if display then UiKit.Display else UiKit.BodyBold,
			TextSize = size,
			TextColor3 = engrave,
			Text = text,
			ZIndex = 32,
		})
	end
	carve("REST", 36, 30, true)
	carve("IN", 68, 26, true)
	carve("PEACE", 96, 30, true)
	carve(s.Name or "", 140, 20)
	carve(string.format("%d gold", s.Gold or 0), 166, 18)
	carve(string.lower(s.CauseText or "killed"), 192, 17)
	carve("on dungeon level " .. s.Depth, 216, 17)

	local panel = UiKit.Frame(back, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 310),
		Size = UDim2.new(0, 560, 1, -320),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.05,
		ZIndex = 31,
	})
	UiKit.Stroke(panel, C.Line, 1)
	local list = scrolling(panel, UDim2.fromOffset(22, 12), UDim2.new(1, -44, 1, -76))
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
	if s.Hint then
		add(s.Hint, 17, C.Amber)
	end
	if #s.Discoveries > 0 then
		add("Learned this run", 20, C.Parchment, true)
		for _, d in s.Discoveries do
			add("·  " .. d, 16, C.Text)
		end
	end
	if #s.Events > 0 then
		add("What happened", 20, C.Parchment, true)
		for _, e in s.Events do
			add("·  " .. e, 16, C.Text)
		end
	end
	add("seed " .. tostring(s.Seed), 13, C.LineDim)

	button(panel, "Play Again", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, -8, 1, -14),
		Size = UDim2.fromOffset(190, 44),
	}, function()
		Panels.StartRun()
	end)
	button(panel, "Main Menu", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 8, 1, -14),
		Size = UDim2.fromOffset(190, 44),
	}, function()
		Remotes.RequestMenu:FireServer()
		Panels.ShowMainMenu()
	end)
	deps.Hud.FadeTo(0.5, 0.6)
end

function Panels.Start(dependencies)
	deps = dependencies
	gui = deps.Hud.Gui()
	layer = UiKit.Frame(gui, {
		Name = "Panels",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
	})

	-- Keep the inventory up to date while it is open (after Hud stores the
	-- new snapshot; deferred so several updates coalesce into one rebuild).
	local pending = false
	Remotes.StateUpdate.OnClientEvent:Connect(function()
		if ClientState.Panel == "Inventory" and not pending then
			pending = true
			task.defer(function()
				pending = false
				if ClientState.Panel == "Inventory" then
					Panels.ShowInventory()
				end
			end)
		end
	end)

	Remotes.RunEnded.OnClientEvent:Connect(function(s)
		ClientState.InRun = false
		Panels.ShowSummary(s)
	end)
	Remotes.FloorEntered.OnClientEvent:Connect(function(_info)
		if ClientState.Panel == "Summary" or ClientState.Panel == "Menu" then
			close()
		end
	end)

	-- Enter / A on the death screen plays again.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or ClientState.Panel ~= "Summary" then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			Panels.StartRun()
		end
	end)

	Panels.ShowMainMenu()
end

return Panels
