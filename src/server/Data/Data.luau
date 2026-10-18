--[=[
	Data (server system)
	Owns: ProfileStore profiles, schema version, migration, session lock.
	Must never: Store run state. Shelf, gems, Index and stats change only through the system that
	owns them (Loot, Economy), which edits the table Data.get returns; ProfileStore saves it.
	Schema and migration are pure: Schema.luau. ProfileStore is vendored, untouched (N34).
	Read first: src/server/Data/README.md
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local ProfileStore = require(script.Parent.ProfileStore.ProfileStore)
local Schema = require(script.Parent.Schema)

local Data = {}

local store = ProfileStore.New(Config.Data.storeName, Schema.template())
local profiles: { [Player]: any } = {}
local loadedListeners: { (player: Player, data: { [string]: any }) -> () } = {}
local releaseListeners: { (player: Player, data: { [string]: any }) -> () } = {}

local function load(player: Player)
	-- Studio only: Workspace attribute DevMockData loads from ProfileStore's mock, so tests never touch
	-- a real profile.
	local useMock = RunService:IsStudio() and workspace:GetAttribute("DevMockData") == true
	local profile = (if useMock then store.Mock else store):StartSessionAsync(`{Config.Data.keyPrefix}{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		-- Another server holds the session lock and would not let go, or the player left.
		if player.Parent == Players then
			player:Kick("Your data could not load. Please rejoin.")
		end
		return
	end
	profile:AddUserId(player.UserId) -- GDPR
	-- Migrate before reconciling, so an old profile is not stamped with the new version first.
	if not Schema.migrate(profile.Data) then
		warn(`Data: {player.Name}'s profile is from a newer build (v{profile.Data.schemaVersion}); not touched`)
	end
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data was opened on another server. Please rejoin.")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile
	for _, listener in loadedListeners do
		task.spawn(listener, player, profile.Data)
	end
end

-- The player's profile data, or nil while it loads (or after it failed). Edit it in place.
function Data.get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.Data
end

-- Calls `listener(player, data)` for every profile that loads from now on, and for those already loaded.
function Data.onLoaded(listener: (player: Player, data: { [string]: any }) -> ())
	table.insert(loadedListeners, listener)
	for player, profile in profiles do
		task.spawn(listener, player, profile.Data)
	end
end

-- Calls `listener(player, data)` when a player leaves, just before their profile is saved and released,
-- so a system can settle what it owes them (Loot sells unclaimed bank overflow). Must not yield.
function Data.beforeRelease(listener: (player: Player, data: { [string]: any }) -> ())
	table.insert(releaseListeners, listener)
end

-- Asks ProfileStore to save now (after a Robux purchase), without waiting.
function Data.save(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Save()
	end
end

-- Whether saves reach the real DataStore ("Access"), or a mock in Studio without API access.
function Data.storeState(): string
	return ProfileStore.DataStoreState
end

function Data.init()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			for _, listener in releaseListeners do
				local ok, err = pcall(listener, player, profile.Data)
				if not ok then
					warn(`Data: release listener failed: {err}`)
				end
			end
			profiles[player] = nil
			profile:EndSession()
		end
	end)
end

return Data
