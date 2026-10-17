-- Spec for src/server/Tear/PanelGrid.luau. Numbers come from Config, never inline.

local PanelGrid = require("../../src/server/Tear/PanelGrid")
local Config = require("../../src/shared/Config/Config")

local PAPER = { layerType = "Paper", depth = 0 }

return function(test, expectEqual)
	test("paper layer is 4x4 per face, 96 panels, at tiers 1 and 2", function()
		for tier = 1, 2 do
			local grid = PanelGrid.fromLayer(PAPER, tier, Config.Panels)
			expectEqual(grid.perFace, Config.Panels.gridPerFaceLowTier, "perFace")
			expectEqual(grid.perFace, 4, "perFace")
			expectEqual(grid.count, 96, "count")
		end
	end)

	test("paper layer is 6x6 per face at tiers 3 and 4", function()
		for tier = 3, 4 do
			local grid = PanelGrid.fromLayer(PAPER, tier, Config.Panels)
			expectEqual(grid.perFace, Config.Panels.gridPerFaceHighTier, "perFace")
			expectEqual(grid.count, PanelGrid.faceCount * 6 * 6, "count")
		end
	end)

	test("grid keeps the layer definition", function()
		local grid = PanelGrid.fromLayer({ layerType = "Paper", depth = 2 }, 1, Config.Panels)
		expectEqual(grid.layerType, "Paper", "layerType")
		expectEqual(grid.depth, 2, "depth")
	end)

	test("a layer type that is not a panel grid is refused", function()
		local ok = pcall(PanelGrid.fromLayer, { layerType = "BoxLid", depth = 5 }, 1, Config.Panels)
		expectEqual(ok, false, "fromLayer(BoxLid) succeeded")
	end)

	test("panel ids map to face, row, col and back", function()
		local grid = PanelGrid.fromLayer(PAPER, 1, Config.Panels)
		for id = 1, grid.count do
			local face, row, col = PanelGrid.locate(grid, id)
			expectEqual(PanelGrid.panelId(grid, face, row, col), id, `id {id}`)
		end
	end)

	test("every panel starts whole", function()
		local grid = PanelGrid.fromLayer(PAPER, 1, Config.Panels)
		for id = 1, grid.count do
			expectEqual(PanelGrid.isTorn(grid, id), false, `panel {id}`)
		end
	end)

	test("panel bitfield round-trips", function()
		for _, tier in { 1, 3 } do
			local grid = PanelGrid.fromLayer(PAPER, tier, Config.Panels)
			for id = 1, grid.count do
				if id % 3 == 0 or id == 1 or id == grid.count then
					PanelGrid.setTorn(grid, id, true)
				end
			end
			PanelGrid.setTorn(grid, 3, false)

			local copy = PanelGrid.fromLayer(PAPER, tier, Config.Panels)
			PanelGrid.decode(copy, PanelGrid.encode(grid))
			for id = 1, grid.count do
				expectEqual(PanelGrid.isTorn(copy, id), PanelGrid.isTorn(grid, id), `tier {tier} panel {id}`)
			end
			expectEqual(PanelGrid.isTorn(copy, 3), false, "panel 3 after un-tear")
			expectEqual(PanelGrid.isTorn(copy, grid.count), true, "last panel")
		end
	end)

	test("every panel sits on the cube surface, inside its face, at a unique spot", function()
		local size = Config.Tiers.Birthday.presentStuds
		local half = size / 2
		local grid = PanelGrid.fromLayer(PAPER, 1, Config.Panels)
		local seen = {}
		for id = 1, grid.count do
			local p = PanelGrid.placement(grid, id, size)
			local c = p.center
			local onSurface = 0
			for _, axis in { c.x, c.y, c.z } do
				assert(math.abs(axis) <= half + 1e-9, `panel {id} outside the cube`)
				if math.abs(math.abs(axis) - half) < 1e-9 then
					onSurface += 1
				end
			end
			expectEqual(onSurface, 1, `panel {id} faces touched`)
			expectEqual(p.width, size / grid.perFace, `panel {id} width`)
			local key = `{c.x},{c.y},{c.z}`
			assert(not seen[key], `panel {id} overlaps another`)
			seen[key] = true
		end
	end)
end
