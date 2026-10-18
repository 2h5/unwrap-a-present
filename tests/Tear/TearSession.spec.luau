-- Spec for src/server/Tear/TearSession.luau and RateLimit.luau. Numbers come from Config, never inline.

local PanelGrid = require("../../src/server/Tear/PanelGrid")
local TearSession = require("../../src/server/Tear/TearSession")
local RateLimit = require("../../src/server/Tear/RateLimit")
local Config = require("../../src/shared/Config/Config")

local SECONDS = Config.Tools.Hands.actions.Tear

local function newSession()
	local grid = PanelGrid.fromLayer({ layerType = "Paper", depth = 0 }, Config.Tiers.Birthday.presentStuds, Config.Panels)
	return TearSession.new(grid), grid
end

return function(test, expectEqual)
	test("holding for the full panel time tears the panel", function()
		local s, grid = newSession()
		expectEqual(TearSession.begin(s, "a", 5, SECONDS, 10), SECONDS, "seconds needed")
		local r = TearSession.release(s, "a", 10 + SECONDS)
		expectEqual(r.torn, true, "torn")
		expectEqual(PanelGrid.isTorn(grid, 5), true, "bit set")
	end)

	test("early release keeps progress and does not tear", function()
		local s, grid = newSession()
		TearSession.begin(s, "a", 5, SECONDS, 0)
		local r = TearSession.release(s, "a", SECONDS / 2)
		expectEqual(r.torn, false, "torn")
		expectEqual(r.progress, 0.5, "progress")
		expectEqual(PanelGrid.isTorn(grid, 5), false, "bit set")
		expectEqual(TearSession.fraction(s, 5, SECONDS, 100), 0.5, "fraction while idle")
	end)

	test("a second hold continues from the kept progress", function()
		local s, grid = newSession()
		TearSession.begin(s, "a", 5, SECONDS, 0)
		TearSession.release(s, "a", SECONDS / 4)
		local needed = TearSession.begin(s, "b", 5, SECONDS, 50)
		expectEqual(needed, SECONDS * 3 / 4, "seconds still needed")
		expectEqual(TearSession.release(s, "b", 50 + needed).torn, true, "torn after the rest")
		expectEqual(PanelGrid.isTorn(grid, 5), true, "bit set")
	end)

	test("fraction grows while held", function()
		local s = newSession()
		TearSession.begin(s, "a", 7, SECONDS, 0)
		expectEqual(TearSession.fraction(s, 7, SECONDS, SECONDS / 2), 0.5, "half way")
		expectEqual(TearSession.fraction(s, 7, SECONDS, SECONDS * 3), 1, "capped at 1")
	end)

	test("a panel held by one player is refused to another", function()
		local s = newSession()
		TearSession.begin(s, "a", 5, SECONDS, 0)
		local needed, reason = TearSession.begin(s, "b", 5, SECONDS, 0.1)
		expectEqual(needed, nil, "needed")
		expectEqual(reason, "held by another player", "reason")
	end)

	test("a torn panel, a missing panel and a fractional id are refused", function()
		local s, grid = newSession()
		PanelGrid.setTorn(grid, 9, true)
		expectEqual(select(2, TearSession.begin(s, "a", 9, SECONDS, 0)), "already torn", "torn")
		expectEqual(select(2, TearSession.begin(s, "a", 0, SECONDS, 0)), "no such panel", "zero")
		expectEqual(select(2, TearSession.begin(s, "a", grid.count + 1, SECONDS, 0)), "no such panel", "past end")
		expectEqual(select(2, TearSession.begin(s, "a", 2.5, SECONDS, 0)), "no such panel", "fraction")
	end)

	test("starting a new panel releases the old one and keeps its progress", function()
		local s = newSession()
		TearSession.begin(s, "a", 1, SECONDS, 0)
		TearSession.begin(s, "a", 2, SECONDS, SECONDS / 2)
		expectEqual(TearSession.fraction(s, 1, SECONDS, 99), 0.5, "panel 1 kept")
		expectEqual(TearSession.holding(s, "a").panelId, 2, "now holding")
	end)

	test("release with nothing held does nothing", function()
		local s = newSession()
		expectEqual(TearSession.release(s, "a", 1), nil, "result")
	end)

	test("rate limit allows the configured requests per second, then frees up", function()
		local perSecond = Config.Tear.maxRequestsPerSecond
		local limiter = RateLimit.new(perSecond)
		for i = 1, perSecond do
			expectEqual(RateLimit.allow(limiter, "a", 0.01 * i), true, `request {i}`)
		end
		expectEqual(RateLimit.allow(limiter, "a", 0.5), false, "over the limit")
		expectEqual(RateLimit.allow(limiter, "b", 0.5), true, "other player unaffected")
		expectEqual(RateLimit.allow(limiter, "a", 1.2), true, "a second later")
	end)
end
