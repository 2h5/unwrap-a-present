--[=[
	Tear (server system)
	Owns: Panel bitfields per layer, tool and action validation, panel timing, layer-cleared events.
	Must never: Trust a client position or timer.
	Read first: src/server/Tear/README.md
]=]

local Tear = {}

function Tear.init()
	-- Not built yet (Phase 0).
end

return Tear
