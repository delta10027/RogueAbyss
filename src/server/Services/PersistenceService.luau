--!strict
-- Versioned per-player save data (TECH_ARCHITECTURE §19-20).
-- Persists knowledge and records only; never power.
--
-- If DataStores are unavailable (e.g. Studio without API access) the game
-- keeps working with in-memory data and says so once in the output.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PersistenceService = {}

local SCHEMA_VERSION = 1
local STORE_NAME = "RogueAbyss_Player"
local SAVE_DEBOUNCE = 6

export type Data = {
	SchemaVersion: number,
	Discoveries: { [string]: boolean },
	Stats: {
		Runs: number,
		Deaths: number,
		BestDepth: number,
		Curios: number,
		FloorsCleared: number,
		Kills: number,
		BestGold: number,
	},
}

local store: DataStore? = nil
local storeWarned = false
local cache: { [Player]: Data } = {}
local loaded: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}

local function defaultData(): Data
	return {
		SchemaVersion = SCHEMA_VERSION,
		Discoveries = {},
		Stats = { Runs = 0, Deaths = 0, BestDepth = 0, Curios = 0, FloorsCleared = 0, Kills = 0, BestGold = 0 },
	}
end

-- Brings any older or malformed save up to the current schema.
local function migrate(raw: any): Data
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end
	-- Version 0 (pre-release) had no SchemaVersion; fields are merged below.
	if type(raw.Discoveries) == "table" then
		for k, v in raw.Discoveries do
			if type(k) == "string" and v == true then
				data.Discoveries[k] = true
			end
		end
	end
	if type(raw.Stats) == "table" then
		for k, v in data.Stats do
			local incoming = raw.Stats[k]
			if type(incoming) == "number" and incoming == incoming then
				(data.Stats :: any)[k] = math.max(0, math.floor(incoming))
			else
				(data.Stats :: any)[k] = v
			end
		end
	end
	data.SchemaVersion = SCHEMA_VERSION
	return data
end
PersistenceService.Migrate = migrate

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		return store
	end
	if not storeWarned then
		storeWarned = true
		warn("[Persistence] DataStore unavailable, using session-only data: " .. tostring(result))
	end
	return nil
end

local function keyFor(player: Player): string
	return "p_" .. player.UserId
end

function PersistenceService.Load(player: Player): Data
	local ds = getStore()
	local data = defaultData()
	local success = false
	if ds and player.UserId > 0 then
		for attempt = 1, 3 do
			local ok, raw = pcall(function()
				return ds:GetAsync(keyFor(player))
			end)
			if ok then
				data = migrate(raw)
				success = true
				break
			elseif attempt == 3 then
				if not storeWarned then
					storeWarned = true
					warn("[Persistence] load failed, using session-only data: " .. tostring(raw))
				end
			else
				task.wait(attempt)
			end
		end
	end
	if player.Parent then
		cache[player] = data
		-- Only a successful load may be saved over; otherwise this session is
		-- memory-only and must not overwrite real progress.
		loaded[player] = success
	end
	return data
end

function PersistenceService.Get(player: Player): Data
	local d = cache[player]
	if not d then
		d = defaultData()
		cache[player] = d
	end
	return d
end

function PersistenceService.MarkDirty(player: Player)
	dirty[player] = true
end

function PersistenceService.Save(player: Player)
	local data = cache[player]
	local ds = getStore()
	if not data or not ds or not loaded[player] or player.UserId <= 0 then
		dirty[player] = nil
		return
	end
	dirty[player] = nil
	local ok, err = pcall(function()
		ds:UpdateAsync(keyFor(player), function(old)
			-- Merge so a stale server never erases knowledge earned elsewhere.
			local merged = migrate(old)
			for k in data.Discoveries do
				merged.Discoveries[k] = true
			end
			for k, v in data.Stats do
				-- Every stat is monotonic, so max() is a safe merge.
				local cur = (merged.Stats :: any)[k] or 0;
				(merged.Stats :: any)[k] = math.max(cur, v)
			end
			return merged
		end)
	end)
	if not ok then
		dirty[player] = true
		warn("[Persistence] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function PersistenceService.Init(_registry)
	Players.PlayerRemoving:Connect(function(player)
		PersistenceService.Save(player)
		cache[player] = nil
		loaded[player] = nil
		dirty[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(PersistenceService.Save, player)
		end
		task.wait(2)
	end)
end

function PersistenceService.Start()
	while true do
		task.wait(SAVE_DEBOUNCE)
		for player in dirty do
			if player.Parent then
				task.spawn(PersistenceService.Save, player)
			else
				dirty[player] = nil
			end
		end
	end
end

return PersistenceService
