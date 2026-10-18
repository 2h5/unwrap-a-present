--[=[
	Shelf (pure logic, server)
	Owns: where a banked gift goes on a player's shelf. Items take slots by rarity (Table 6: 1, 1, 2,
	2, 3, 4); a duplicate (same gift, rarity and mutation) stacks on the slot it already holds, up to
	Config.Shelf.stackMax; anything else takes the first run of free slots that fits.
	Must never: call game:GetService or decide what is sold. The bank screen asks the player.
	Read first: src/server/Loot/README.md
]=]

export type Item = { giftId: string, rarity: string, mutation: string?, slotIndex: number, count: number }

export type ShelfConfig = {
	slotSizes: { [string]: number }, -- rarity -> slots
	stackMax: number,
}

local Shelf = {}

local function same(a: any, b: any): boolean
	return a.giftId == b.giftId and a.rarity == b.rarity and (a.mutation or "") == (b.mutation or "")
end

-- Slot i is taken when some item covers it.
local function occupied(shelf: { Item }, config: ShelfConfig): { [number]: boolean }
	local taken = {}
	for _, item in shelf do
		for i = item.slotIndex, item.slotIndex + config.slotSizes[item.rarity] - 1 do
			taken[i] = true
		end
	end
	return taken
end

function Shelf.usedSlots(shelf: { Item }, config: ShelfConfig): number
	local used = 0
	for _, item in shelf do
		used += config.slotSizes[item.rarity]
	end
	return used
end

-- The first slot where `size` free slots in a row fit inside `capacity`, or nil.
function Shelf.freeRun(shelf: { Item }, size: number, capacity: number, config: ShelfConfig): number?
	local taken = occupied(shelf, config)
	for start = 1, capacity - size + 1 do
		local ok = true
		for i = start, start + size - 1 do
			if taken[i] then
				ok = false
				break
			end
		end
		if ok then
			return start
		end
	end
	return nil
end

-- Where `gift` ({ giftId, rarity, mutation? }) would go: "stacked" with the item, "placed" at a slot,
-- or "full". Changes nothing.
function Shelf.preview(shelf: { Item }, gift: any, capacity: number, config: ShelfConfig): (string, any)
	for _, item in shelf do
		if same(item, gift) and item.count < config.stackMax then
			return "stacked", item
		end
	end
	local slot = Shelf.freeRun(shelf, config.slotSizes[gift.rarity], capacity, config)
	if slot then
		return "placed", slot
	end
	return "full", nil
end

-- Puts `gift` on the shelf if it fits. Returns "stacked", "placed" or "full" (shelf unchanged).
function Shelf.place(shelf: { Item }, gift: any, capacity: number, config: ShelfConfig): string
	local outcome, target = Shelf.preview(shelf, gift, capacity, config)
	if outcome == "stacked" then
		target.count += 1
	elseif outcome == "placed" then
		local item: Item = { giftId = gift.giftId, rarity = gift.rarity, slotIndex = target, count = 1 }
		if gift.mutation and gift.mutation ~= "" then
			item.mutation = gift.mutation
		end
		table.insert(shelf, item)
		table.sort(shelf, function(a, b)
			return a.slotIndex < b.slotIndex
		end)
	end
	return outcome
end

-- Takes the whole item at `slotIndex` off the shelf and returns it, or nil.
function Shelf.removeAt(shelf: { Item }, slotIndex: number): Item?
	for i, item in shelf do
		if item.slotIndex == slotIndex then
			return table.remove(shelf, i)
		end
	end
	return nil
end

return Shelf
