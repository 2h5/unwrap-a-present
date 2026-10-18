--[=[
	Meta (pure logic, server)
	Owns: the gem economy's rules on a profile table: daily and group rewards, the login streak,
	bring-a-friend, class spins, the permanent track, shelf slots, prestige, vault reclaims and the
	tier a player may run. PLAN.md › Mechanics D and E; PLAN-TABLES.txt Tables 7, 8, 9, 19.
	Must never: call game:GetService, read a clock, or grant a gift (invariant 6). The caller passes
	the time, the Rng and the config; every function returns what changed so the HUD can say it.
	Read first: src/server/Economy/README.md
]=]

export type RngApi = {
	int: (rng: any, lo: number, hi: number) -> number,
	weighted: (rng: any, entries: { { value: string, weight: number } }) -> string?,
}

local Meta = {}

local DAY = 24 * 60 * 60

---------------------------------------------------------------- rewards

-- Seconds until the daily reward can be claimed again (0 = now).
function Meta.dailyWait(data: any, now: number, interval: number): number
	if data.dailyClaimedAt == 0 then
		return 0 -- never claimed
	end
	return math.max(0, data.dailyClaimedAt + interval - now)
end

-- Claims the daily reward. Returns the gems paid, or nil if it is not ready.
function Meta.claimDaily(data: any, now: number, interval: number, gems: number): number?
	if Meta.dailyWait(data, now, interval) > 0 then
		return nil
	end
	data.dailyClaimedAt = now
	data.gems += gems
	return gems
end

-- One-time group reward. `inGroup` is checked by the caller. Returns the gems paid, or nil.
function Meta.claimGroup(data: any, inGroup: boolean, gems: number): number?
	if data.groupClaimed or not inGroup then
		return nil
	end
	data.groupClaimed = true
	data.gems += gems
	return gems
end

-- The login streak on a join at `now` (UTC days). Day n of a streak pays perDay × n, capped at
-- capDays; a missed day starts again at day 1. Returns the gems paid (0 if already counted today).
function Meta.login(data: any, now: number, perDay: number, capDays: number): number
	local today = now // DAY
	local streak = data.streak
	if streak.lastLoginDay == today then
		return 0
	end
	streak.days = if streak.lastLoginDay == today - 1 then streak.days + 1 else 1
	streak.lastLoginDay = today
	local gems = perDay * math.min(streak.days, capDays)
	data.gems += gems
	return gems
end

-- Bring-a-friend: every player in a party of 2 or more gets this per completed run.
function Meta.friendBonus(partySize: number, perPlayer: number): number
	return if partySize >= 2 then perPlayer else 0
end

---------------------------------------------------------------- classes

-- Rolls a class from the spin odds (config: id -> { odds }, `order` fixes the iteration order).
function Meta.rollClass(rng: any, classes: { [string]: any }, order: { string }, Rng: RngApi): string
	local entries = {}
	for _, id in order do
		table.insert(entries, { value = id, weight = classes[id].odds })
	end
	return Rng.weighted(rng, entries) :: string
end

-- Pays for a spin and applies the roll. Returns the class and whether it is new, the refund for a
-- duplicate, or nil if the player cannot afford the spin.
function Meta.spin(data: any, rolled: string, cost: number, refund: number): (string?, boolean, number)
	if data.gems < cost then
		return nil, false, 0
	end
	data.gems -= cost
	if table.find(data.classes, rolled) then
		data.gems += refund
		return rolled, false, refund
	end
	table.insert(data.classes, rolled)
	if data.activeClass == "" then
		data.activeClass = rolled
	end
	return rolled, true, 0
end

-- Picks an owned class for the next run. Returns true if it changed.
function Meta.pickClass(data: any, id: string): boolean
	if not table.find(data.classes, id) then
		return false
	end
	data.activeClass = id
	return true
end

---------------------------------------------------------------- permanent track and shelf slots

-- Gem cost of the next level of a track line, or nil at max level.
function Meta.trackCost(line: any, level: number): number?
	if level >= line.maxLevel then
		return nil
	end
	return line.costLevel1 + line.costStep * level
end

-- Buys the next level of `name` ("pockets" or "nightEyes"). Returns the new level, or nil.
function Meta.buyTrack(data: any, name: string, line: any): number?
	local level = data.upgrades[name]
	local cost = Meta.trackCost(line, level)
	if not cost or data.gems < cost then
		return nil
	end
	data.gems -= cost
	data.upgrades[name] = level + 1
	return level + 1
end

-- Buys 4 more shelf slots with gems, up to the gem cap. Returns the new slot count, or nil.
function Meta.buyShelfSlots(data: any, shelf: any): number?
	if data.shelfSlots + 4 > shelf.gemSlotsMax or data.gems < shelf.gemsPer4Slots then
		return nil
	end
	data.gems -= shelf.gemsPer4Slots
	data.shelfSlots += 4
	return data.shelfSlots
end

-- Shelf capacity: bought slots, or the pass size with the Big Shelf gamepass.
function Meta.shelfCapacity(data: any, shelf: any, bigShelf: boolean): number
	return if bigShelf then shelf.passSlotsMax else data.shelfSlots
end

---------------------------------------------------------------- prestige and tiers

-- Completed runs needed to prestige from the player's tier, or nil at the last tier this build ships.
function Meta.prestigeNeed(data: any, tiers: { string }, need: { [string]: number }, maxTier: number): number?
	if data.tier >= maxTier then
		return nil
	end
	return need[tiers[data.tier]]
end

function Meta.canPrestige(data: any, tiers: { string }, need: { [string]: number }, maxTier: number): boolean
	local n = Meta.prestigeNeed(data, tiers, need, maxTier)
	return n ~= nil and (data.tierCompletions[tostring(data.tier)] or 0) >= n
end

-- Prestiges: next tier, shelf back to `slots`; whatever no longer fits goes to the vault (P2).
-- Index, gems, classes, passes, stats and the track are not touched. Returns the items vaulted.
function Meta.prestige(data: any, slots: number, slotSizes: { [string]: number }): { any }
	data.tier += 1
	data.prestigeCount += 1
	data.shelfSlots = slots
	local kept, moved = {}, {}
	for _, item in data.shelf do
		if item.slotIndex + slotSizes[item.rarity] - 1 <= slots then
			table.insert(kept, item)
		else
			table.insert(moved, item)
		end
	end
	data.shelf = kept
	for _, item in moved do
		item.slotIndex = #data.vault + 1
		table.insert(data.vault, item)
	end
	return moved
end

-- A completed run at `tierNumber`: counts toward prestige only at the player's own tier (N13), and
-- refills the vault reclaims (P2).
function Meta.runCompleted(data: any, tierNumber: number, reclaims: number)
	if tierNumber == data.tier then
		local key = tostring(tierNumber)
		data.tierCompletions[key] = (data.tierCompletions[key] or 0) + 1
	end
	data.vaultReclaimsLeft = reclaims
end

-- Tiers a player may run: every tier up to their own (P3).
function Meta.canRunTier(data: any, tierNumber: number): boolean
	return tierNumber >= 1 and tierNumber <= data.tier
end

return Meta
