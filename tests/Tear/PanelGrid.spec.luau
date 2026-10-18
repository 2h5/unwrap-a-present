-- Spec for src/server/Tear/PanelGrid.luau. Numbers come from Config, never inline.

local PanelGrid = require("../../src/server/Tear/PanelGrid")
local Config = require("../../src/shared/Config/Config")

local PAPER = { layerType = "Paper", depth = 0 }

return function(test, expectEqual)
	test("a 16-stud paper layer is 4x4 per face, 96 panels", function()
		local grid = PanelGrid.fromLayer(PAPER, Config.Tiers.Birthday.presentStuds, Config.Panels)
		expectEqual(grid.perFace, 4, "perFace")
		expectEqual(grid.count, 96, "count")
	end)

	test("panels per face follow the layer size, clamped 3..6 (about 4 studs a panel)", function()
		for _, case in { { 6, 3 }, { 9, 3 }, { 12, 3 }, { 16, 4 }, { 20, 5 }, { 23.9, 5 }, { 24, 6 }, { 28, 6 } } do
			local grid = PanelGrid.fromLayer(PAPER, case[1], Config.Panels)
			expectEqual(grid.perFace, case[2], `{case[1]} studs`)
			expectEqual(grid.count, PanelGrid.faceCount * case[2] * case[2], `{case[1]} studs count`)
		end
	end)

	test("grid keeps the layer definition", function()
		local grid = PanelGrid.fromLayer({ layerType = "Paper", depth = 2 }, Config.Tiers.Birthday.presentStuds, Config.Panels)
		expectEqual(grid.layerType, "Paper", "layerType")
		expectEqual(grid.depth, 2, "depth")
	end)

	test("a layer type that is not a panel grid is refused", function()
		local ok = pcall(PanelGrid.fromLayer, { layerType = "BoxLid", depth = 5 }, Config.Tiers.Birthday.presentStuds, Config.Panels)
		expectEqual(ok, false, "fromLayer(BoxLid) succeeded")
	end)

	test("panel ids map to face, row, col and back", function()
		local grid = PanelGrid.fromLayer(PAPER, Config.Tiers.Birthday.presentStuds, Config.Panels)
		for id = 1, grid.count do
			local face, row, col = PanelGrid.locate(grid, id)
			expectEqual(PanelGrid.panelId(grid, face, row, col), id, `id {id}`)
		end
	end)

	test("every panel starts whole", function()
		local grid = PanelGrid.fromLayer(PAPER, Config.Tiers.Birthday.presentStuds, Config.Panels)
		for id = 1, grid.count do
			expectEqual(PanelGrid.isTorn(grid, id), false, `panel {id}`)
		end
	end)

	test("panel bitfield round-trips", function()
		for _, tier in { "Birthday", "Wedding" } do
			local grid = PanelGrid.fromLayer(PAPER, Config.Tiers[tier].presentStuds, Config.Panels)
			for id = 1, grid.count do
				if id % 3 == 0 or id == 1 or id == grid.count then
					PanelGrid.setTorn(grid, id, true)
				end
			end
			PanelGrid.setTorn(grid, 3, false)

			local copy = PanelGrid.fromLayer(PAPER, Config.Tiers[tier].presentStuds, Config.Panels)
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
		local grid = PanelGrid.fromLayer(PAPER, Config.Tiers.Birthday.presentStuds, Config.Panels)
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
