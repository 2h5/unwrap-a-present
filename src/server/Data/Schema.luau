--[=[
	Schema (pure logic, server)
	Owns: the profile's shape (PLAN.md › Mechanics D, data schema; PLAN-TABLES.txt Table 10), its
	schemaVersion, and the ordered migrations that bring an old profile up to it (N20).
	Must never: require ProfileStore or call game:GetService, so the migration test runs from the
	command line. Never holds run state (RunBag, panel bitfields, Nest, Night timer).
	Read first: src/server/Data/README.md
]=]

local Schema = {}

Schema.VERSION = 2

-- A fresh profile. ProfileStore copies it for a new player and fills missing keys on load.
-- Optional fields are empty strings or zeros, never nil, so Reconcile can see them.
function Schema.template(): { [string]: any }
	return {
		schemaVersion = Schema.VERSION,
		tier = 1,
		prestigeCount = 0,
		gems = 0,
		naughty = 0,
		naughtyUpdatedAt = 0,
		shelf = {}, -- { giftId, rarity, mutation?, slotIndex, count }
		vault = {},
		index = {}, -- giftId (or giftId:Mutation) -> { count, firstDepth, firstSeenAt, bestRarity? }
		classes = {},
		activeClass = "",
		passes = {},
		stats = {
			runs = 0,
			completions = 0,
			wipes = 0,
			ticksSurvived = 0,
			stolen = 0,
			stolenFrom = 0,
			mythicsFound = 0,
			fastestBirthdayRunSeconds = 0,
		},
		upgrades = { pockets = 0, nightEyes = 0 },
		streak = { days = 0, lastLoginDay = 0 },
		likesReceived = 0,
		likedShelves = {},
		rejoin = { accessCode = "", expiresAt = 0 },
		dailyClaimedAt = 0,
		groupClaimed = false,
		-- v2
		tierCompletions = {}, -- tier number as a string -> completed runs at that tier (prestige, P4)
		shelfSlots = 12, -- bought with gems up to 24; the Big Shelf pass adds the rest at runtime
		vaultReclaimsLeft = 0, -- set to 3 by each completed run (P2)
		purchases = {}, -- dev product receipt ids already granted, newest last
	}
end

-- Copies every key the template has and `data` lacks, all the way down. Never overwrites.
function Schema.reconcile(data: { [string]: any }, template: { [string]: any })
	for key, value in template do
		if data[key] == nil then
			data[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			Schema.reconcile(data[key], value)
		end
	end
end

-- migrations[n] takes a profile at version n - 1 to version n.
Schema.migrations = {
	-- 0 -> 1: profiles from before versioning. Keep everything they have, fill the rest.
	function(data)
		Schema.reconcile(data, Schema.template())
	end,
	-- 1 -> 2: per-tier run counts start from the completions so far (every v1 run was Birthday).
	function(data)
		Schema.reconcile(data, Schema.template())
		if next(data.tierCompletions) == nil and data.stats.completions > 0 then
			data.tierCompletions["1"] = data.stats.completions
		end
	end,
}

-- Brings `data` up to Schema.VERSION in place. A profile from a newer build is left alone and the
-- function returns false, so an old server never downgrades it. Returns true otherwise.
function Schema.migrate(data: { [string]: any }): boolean
	local version = data.schemaVersion or 0
	if version > Schema.VERSION then
		return false
	end
	for v = version + 1, Schema.VERSION do
		Schema.migrations[v](data)
		data.schemaVersion = v
	end
	Schema.reconcile(data, Schema.template())
	return true
end

return Schema
