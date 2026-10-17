--[=[
	TearSession (pure logic, server)
	Owns: hold-to-tear timing for one layer's grid: who holds which panel, seconds of progress
	kept per panel, and when a panel becomes torn.
	Must never: read a clock or take a time from a client. The caller passes the server's `now`.
	Must never: call game:GetService or touch an Instance (runs under Lune tests).
	A holder holds one panel at a time; a panel has one holder at a time.
	Read first: src/server/Tear/README.md
]=]

local PanelGrid = require("./PanelGrid")

export type Hold = { panelId: number, startedAt: number, seconds: number }

export type Session = {
	grid: PanelGrid.Grid,
	progress: { [number]: number }, -- seconds already torn, kept on early release
	holds: { [any]: Hold }, -- by holder
	holderOf: { [number]: any }, -- by panel id
}

export type Result = {
	panelId: number,
	torn: boolean,
	progress: number, -- 0..1
}

local EPSILON = 1e-6 -- float slack when a timer lands exactly on the panel time

local TearSession = {}

function TearSession.new(grid: PanelGrid.Grid): Session
	return { grid = grid, progress = {}, holds = {}, holderOf = {} }
end

-- Fraction of the panel done at `now`, counting a hold in progress.
function TearSession.fraction(session: Session, panelId: number, seconds: number, now: number): number
	if PanelGrid.isTorn(session.grid, panelId) then
		return 1
	end
	local done = session.progress[panelId] or 0
	local holder = session.holderOf[panelId]
	if holder ~= nil then
		done += now - session.holds[holder].startedAt
	end
	return math.clamp(done / seconds, 0, 1)
end

-- Starts a hold. Returns the seconds still needed, or nil and a reason.
function TearSession.begin(session: Session, holder: any, panelId: number, seconds: number, now: number): (number?, string?)
	if panelId < 1 or panelId > session.grid.count or panelId % 1 ~= 0 then
		return nil, "no such panel"
	end
	if PanelGrid.isTorn(session.grid, panelId) then
		return nil, "already torn"
	end
	local other = session.holderOf[panelId]
	if other ~= nil and other ~= holder then
		return nil, "held by another player"
	end
	if session.holds[holder] then
		TearSession.release(session, holder, now)
	end
	session.holds[holder] = { panelId = panelId, startedAt = now, seconds = seconds }
	session.holderOf[panelId] = holder
	return seconds - (session.progress[panelId] or 0), nil
end

-- Ends the holder's hold: keeps the progress, and tears the panel if the time is reached.
-- Returns nil when the holder was not holding anything.
function TearSession.release(session: Session, holder: any, now: number): Result?
	local hold = session.holds[holder]
	if not hold then
		return nil
	end
	session.holds[holder] = nil
	session.holderOf[hold.panelId] = nil

	local done = (session.progress[hold.panelId] or 0) + math.max(0, now - hold.startedAt)
	if done >= hold.seconds - EPSILON then
		session.progress[hold.panelId] = nil
		PanelGrid.setTorn(session.grid, hold.panelId, true)
		return { panelId = hold.panelId, torn = true, progress = 1 }
	end
	session.progress[hold.panelId] = done
	return { panelId = hold.panelId, torn = false, progress = done / hold.seconds }
end

function TearSession.holding(session: Session, holder: any): Hold?
	return session.holds[holder]
end

return TearSession
