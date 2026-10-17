--[=[
	Main (client entry)
	Owns: boot order for client systems.
	Must never: decide anything. The client only asks and animates (invariant 7).
	Read first: docs/PLAN.md › Systems architecture
]=]

local ORDER = { "HUD", "Debris", "TearInput", "Shelf" }

for _, name in ORDER do
	local system = require(script.Parent[name][name])
	system.init()
end
