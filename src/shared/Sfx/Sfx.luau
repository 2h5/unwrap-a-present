--[=[
	Sfx (shared, used by client systems)
	Owns: playing one clip from a Config.Sounds list at a world position, pitch randomized within
	Config.Tear.pitchVariance, and preloading every clip.
	Must never: decide anything or play on the server. Sounds are local to the client that plays them.
	Read first: src/shared/README.md
]=]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)

local Sfx = {}

local rng = Random.new()

-- Plays one random clip from `clips` at `position`. Returns the Sound (already playing).
function Sfx.playAt(clips: { string }, position: Vector3): Sound
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = clips[rng:NextInteger(1, #clips)]
	local variance = Config.Tear.pitchVariance
	sound.PlaybackSpeed = 1 + rng:NextNumber(-variance, variance)
	sound.Parent = anchor
	sound.Ended:Once(function()
		anchor:Destroy()
	end)
	sound:Play()
	return sound
end

-- Preloads every clip in Config.Sounds so the first tear is not silent. Yields.
function Sfx.preload()
	local sounds = {}
	for _, clips in Config.Sounds do
		for _, id in clips do
			local sound = Instance.new("Sound")
			sound.SoundId = id
			table.insert(sounds, sound)
		end
	end
	ContentProvider:PreloadAsync(sounds)
end

return Sfx
