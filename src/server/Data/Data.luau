--[=[
	Data (server system)
	Owns: ProfileService profiles, schema version, migration, session lock.
	Must never: Store run state.
	Read first: src/server/Data/README.md
]=]

local Data = {}

function Data.init()
	-- Not built yet (Phase 2).
end

return Data
