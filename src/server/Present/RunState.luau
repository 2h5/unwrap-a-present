--[=[
	RunState (server)
	Owns: the run's state (PLAN-TABLES.txt Diagram B): Lobby, Building, Unwrapping, Night, CoreLid,
	Reveal, Bank, Wipe. Replicated as the Workspace attribute "RunState" and the Down remote RunState.
	Every up remote checks it before it does anything (N21).
	Must never: decide a transition itself. Present, Tear and Loot set it when the run moves on.
	Read first: src/server/Present/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

local RunState = {}

local state = "Lobby"

function RunState.get(): string
	return state
end

function RunState.set(new: string)
	state = new
	workspace:SetAttribute("RunState", new)
	Remotes.get("RunState"):FireAllClients(new)
end

-- True while players may tear, cut, snip or lift (the core lid included).
function RunState.canTear(): boolean
	return state == "Unwrapping" or state == "Night" or state == "CoreLid"
end

return RunState
