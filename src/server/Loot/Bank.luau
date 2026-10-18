--[=[
	Bank (pure logic, server)
	Owns: what a run end pays (PLAN.md › Mechanics B, Bank; Table 6, Table 9): gems for the run, and
	gems for a sold gift. Every finisher banks a copy of the whole run bag and the core gift (N14).
	Must never: call game:GetService or touch the shelf. Loot applies the result.
	Read first: src/server/Loot/README.md
]=]

export type GemConfig = {
	completed: number, -- Config.BankGems
	noDowns: number,
	tickSurvived: number,
	lowerTier: number, -- Config.Tiers.lowerTierGemsPerRun
}

local Bank = {}

-- Gems for a completed run: the best of completed / no downs / Tick survived at your highest
-- unlocked tier; a flat lowerTier below it (P3).
function Bank.runGems(config: GemConfig, downs: number, tickSurvived: boolean, belowHighestTier: boolean): number
	if belowHighestTier then
		return config.lowerTier
	end
	if tickSurvived then
		return config.tickSurvived
	end
	if downs == 0 then
		return config.noDowns
	end
	return config.completed
end

-- Gems for selling `count` of a gift of `rarity`, or nil if it cannot be sold (Secret, N33).
function Bank.sellGems(sellGems: { [string]: number }, rarity: string, count: number?): number?
	local each = sellGems[rarity]
	if not each then
		return nil
	end
	return each * (count or 1)
end

return Bank
