--[=[
	Main (server entry)
	Owns: boot order. Requires each system and calls init once.
	Must never: hold game logic. Logic lives in the system folders.
	Read first: docs/PLAN.md › Systems architecture
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remotes before any system wires handlers.
require(ReplicatedStorage.Shared.Remotes.Remotes)

local ORDER = { "Data", "Economy", "Present", "Tear", "Loot", "Night", "Steal", "Lobby" }

for _, name in ORDER do
	local system = require(script.Parent[name][name])
	system.init()
end
