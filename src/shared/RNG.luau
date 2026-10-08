--!strict
-- Deterministic, stream-separated randomness.
-- A stream is derived from (runSeed, floor, stageName) so changing how one
-- stage consumes randomness never perturbs another stage.

local RNG = {}
RNG.__index = RNG

export type Stream = typeof(setmetatable({} :: { _r: Random }, RNG))

-- FNV-1a 32-bit over a string.
local function hashString(s: string): number
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * 16777619) % 4294967296
	end
	return h
end
RNG.HashString = hashString

function RNG.Derive(runSeed: number, floor: number, stage: string): number
	return hashString(string.format("%d:%d:%s", runSeed, floor, stage))
end

function RNG.new(seed: number): Stream
	return setmetatable({ _r = Random.new(seed) }, RNG)
end

function RNG.Stream(runSeed: number, floor: number, stage: string): Stream
	return RNG.new(RNG.Derive(runSeed, floor, stage))
end

function RNG.Int(self: Stream, lo: number, hi: number): number
	return self._r:NextInteger(lo, hi)
end

function RNG.Float(self: Stream, lo: number?, hi: number?): number
	local a = lo or 0
	local b = hi or 1
	return a + (b - a) * self._r:NextNumber()
end

function RNG.Chance(self: Stream, p: number): boolean
	return self._r:NextNumber() < p
end

function RNG.Pick<T>(self: Stream, list: { T }): T
	return list[self._r:NextInteger(1, #list)]
end

-- Picks a key from { [key] = weight }, iterating keys in sorted order so the
-- result is deterministic regardless of table hash order.
function RNG.Weighted(self: Stream, weights: { [string]: number }): string?
	local keys = {}
	local total = 0
	for k, w in weights do
		if w > 0 then
			table.insert(keys, k)
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	table.sort(keys)
	local roll = self._r:NextNumber() * total
	for _, k in keys do
		roll -= weights[k]
		if roll <= 0 then
			return k
		end
	end
	return keys[#keys]
end

function RNG.Shuffle<T>(self: Stream, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self._r:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return RNG
