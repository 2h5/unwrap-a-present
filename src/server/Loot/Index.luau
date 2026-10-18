--[=[
	Index (pure logic, server)
	Owns: the player's record of every gift ever found (PLAN.md › Mechanics B, Index). One Index for
	side-gifts and core gifts (core gifts are starred by the HUD from Shared/Gifts); a mutation is its
	own entry (giftId:Mutation); a side-gift's entry keeps the best rarity it was found at (N31).
	Never loses an entry: a steal, a sale or a wipe never calls into here.
	Must never: call game:GetService. The caller passes the clock.
	Read first: src/server/Loot/README.md
]=]

export type Entry = { count: number, firstDepth: number, firstSeenAt: number, bestRarity: string? }

local Index = {}

function Index.key(giftId: string, mutation: string?): string
	return if mutation and mutation ~= "" then `{giftId}:{mutation}` else giftId
end

function Index.has(index: { [string]: Entry }, key: string): boolean
	local entry = index[key]
	return entry ~= nil and entry.count > 0
end

-- Records one find. `rarity` is given for side-gifts (best kept, ranked by `order`). Returns true if
-- the entry is new.
function Index.record(
	index: { [string]: Entry },
	key: string,
	depth: number,
	now: number,
	rarity: string?,
	order: { string }?
): boolean
	local entry = index[key]
	local isNew = entry == nil
	if isNew then
		entry = { count = 0, firstDepth = depth, firstSeenAt = now }
		index[key] = entry
	end
	entry.count += 1
	if rarity and order then
		local best = entry.bestRarity
		if not best or (table.find(order, rarity) or 0) > (table.find(order, best) or 0) then
			entry.bestRarity = rarity
		end
	end
	return isNew
end

return Index
