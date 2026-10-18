--[=[
	Main (server entry)
	Owns: boot order. Requires each system and calls init once.
	Must never: hold game logic. Logic lives in the system folders.
	Two places, one codebase (Q2): the Workspace attribute PlaceKind is "Lobby" in the lobby place
	(lobby.project.json) and absent in the run place (default.project.json).
	Read first: docs/PLAN.md › Systems architecture
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remotes before any system wires handlers.
require(ReplicatedStorage.Shared.Remotes.Remotes)

local ORDER = if workspace:GetAttribute("PlaceKind") == "Lobby"
	then { "Data", "Economy", "Loot", "Steal", "Lobby" }
	else { "Data", "Economy", "Present", "Tear", "Loot", "Night", "Steal", "Lobby" }

for _, name in ORDER do
	local system = require(script.Parent[name][name])
	system.init()
end
