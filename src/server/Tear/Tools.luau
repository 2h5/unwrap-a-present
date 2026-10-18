--[=[
	Tools (pure logic, server)
	Owns: which owned tool a player uses for an action, and how long it takes. Hands are always owned.
	A tool qualifies when its grade is at least the item's grade and it has the action ("All" for the
	chainsaw); the fastest qualifying tool wins. `timeScale` applies run upgrades (grip tape).
	Must never: call game:GetService. Ownership comes in as a table the caller builds.
	Read first: src/server/Tear/README.md
]=]

local ORDER = { "Hands", "Scissors", "BoxCutter", "Chainsaw" }

local Tools = {}

Tools.order = ORDER

-- Returns seconds and the tool's name, or nil if no owned tool can do it.
function Tools.best(owned: { [string]: boolean }, action: string, grade: number, tools: { [string]: any }, timeScale: number?): (number?, string?)
	local bestSeconds, bestName = nil, nil
	for _, name in ORDER do
		local tool = tools[name]
		if tool and (name == "Hands" or owned[name]) and tool.grade >= grade then
			local seconds = if tool.actions == "All" then tool.seconds else tool.actions[action]
			if seconds and (not bestSeconds or seconds < bestSeconds) then
				bestSeconds, bestName = seconds, name
			end
		end
	end
	if bestSeconds then
		return bestSeconds * (timeScale or 1), bestName
	end
	return nil, nil
end

return Tools
