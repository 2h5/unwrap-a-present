--[=[
	Remotes (shared)
	Owns: the list of RemoteEvents and how both sides get them. Server creates; client waits.
	Must never: carry a decision. Up remotes are requests; the server validates RunState and args.
	Read first: src/shared/README.md
]=]

local RunService = game:GetService("RunService")

local Remotes = {}

-- Client → server: requests only.
Remotes.Up = { "TearRequest", "LidLift", "ShopBuy", "ClassSpin", "StealRequest", "Revive" }

-- Server → client: replicated state.
Remotes.Down = { "RunState", "LootEvent", "NightState", "ShelfState", "TearState" }

local FOLDER_NAME = "RemoteEvents"

local function getFolder(): Folder
	local parent = script.Parent
	if RunService:IsServer() then
		local folder = parent:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			for _, list in { Remotes.Up, Remotes.Down } do
				for _, name in list do
					local remote = Instance.new("RemoteEvent")
					remote.Name = name
					remote.Parent = folder
				end
			end
			folder.Parent = parent
		end
		return folder
	end
	return parent:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.get(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

return Remotes
