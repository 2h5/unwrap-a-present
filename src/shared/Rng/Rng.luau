--[=[
	Rng (shared, pure logic)
	Owns: a seeded xorshift32 generator, so the same seed gives the same Nest (and later the same
	rolls) in Roblox and under Lune tests alike.
	Must never: call game:GetService, or be seeded by the client. Seeds are rolled on the server.
	Read first: src/shared/README.md
]=]

export type Rng = { state: number }

local TWO_32 = 4294967296

local Rng = {}

function Rng.new(seed: number): Rng
	local state = bit32.band(math.floor(seed) % TWO_32, 0xFFFFFFFF)
	if state == 0 then
		state = 0x9E3779B9 -- xorshift cannot leave zero
	end
	return { state = state }
end

-- Next number in [0, 1).
function Rng.next(rng: Rng): number
	local x = rng.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	rng.state = x
	return x / TWO_32
end

-- Integer in [lo, hi].
function Rng.int(rng: Rng, lo: number, hi: number): number
	return lo + math.floor(Rng.next(rng) * (hi - lo + 1))
end

-- Picks one entry by weight. Entries with weight <= 0 are never picked. Returns nil if none can be.
function Rng.weighted<T>(rng: Rng, entries: { { value: T, weight: number } }): T?
	local total = 0
	for _, entry in entries do
		if entry.weight > 0 then
			total += entry.weight
		end
	end
	if total <= 0 then
		return nil
	end
	local pick = Rng.next(rng) * total
	for _, entry in entries do
		if entry.weight > 0 then
			pick -= entry.weight
			if pick < 0 then
				return entry.value
			end
		end
	end
	-- Float slack: fall back to the last pickable entry.
	for i = #entries, 1, -1 do
		if entries[i].weight > 0 then
			return entries[i].value
		end
	end
	return nil
end

return Rng
