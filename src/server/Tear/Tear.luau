--[=[
	Tear (server system)
	Owns: Panel bitfields per layer, tool and action validation, panel timing, layer-cleared events.
	Must never: Trust a client position or timer.
	Grid logic is pure and tested: PanelGrid.luau. This file is the Roblox glue around it.
	Phase 0: builds one greybox Paper layer on one cube as server Parts (Workspace.Present).
	Read first: src/server/Tear/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local PanelGrid = require(script.Parent.PanelGrid)

local Tear = {}

local grids: { [number]: PanelGrid.Grid } = {} -- by depth

-- Builds a layer's panels as anchored Parts on a cube of side `size` centred at `origin`.
local function buildGreybox(grid: PanelGrid.Grid, size: number, origin: Vector3): Folder
	local folder = Instance.new("Folder")
	folder.Name = `Layer{grid.depth}_{grid.layerType}`
	local thickness = Config.Greybox.panelThickness
	for id = 1, grid.count do
		local p = PanelGrid.placement(grid, id, size)
		local normal = Vector3.new(p.normal.x, p.normal.y, p.normal.z)
		local center = origin + Vector3.new(p.center.x, p.center.y, p.center.z) - normal * (thickness / 2)
		local part = Instance.new("Part")
		part.Name = `Panel{id}`
		part.Anchored = true
		part.Size = Vector3.new(p.width, p.width, thickness)
		-- A part's front (-Z) points along the outward normal.
		local up = if math.abs(normal.Y) > 0.5 then Vector3.zAxis else Vector3.yAxis
		part.CFrame = CFrame.lookAt(center, center + normal, up)
		part:SetAttribute("PanelId", id)
		part:SetAttribute("Depth", grid.depth)
		part.Parent = folder
	end
	return folder
end

function Tear.getGrid(depth: number): PanelGrid.Grid?
	return grids[depth]
end

function Tear.init()
	-- Phase 0 greybox: one Paper layer at depth 0, Birthday tier. Present generates the Nest from Phase 1.
	local tier = 1
	local size = Config.Tiers.Birthday.presentStuds
	local grid = PanelGrid.fromLayer({ layerType = "Paper", depth = 0 }, tier, Config.Panels)
	grids[grid.depth] = grid

	local present = Instance.new("Model")
	present.Name = "Present"
	buildGreybox(grid, size, Vector3.new(0, size / 2, 0)).Parent = present
	present.Parent = workspace
end

return Tear
