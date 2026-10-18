-- Spec for LayerModel, LayerGeometry, LidSession and Tools (src/server/Tear). Numbers come from Config.

local PanelGrid = require("../../src/server/Tear/PanelGrid")
local LayerModel = require("../../src/server/Tear/LayerModel")
local LayerGeometry = require("../../src/server/Tear/LayerGeometry")
local LidSession = require("../../src/server/Tear/LidSession")
local Tools = require("../../src/server/Tear/Tools")
local Config = require("../../src/shared/Config/Config")

local RULES = { layerTable = Config.LayerTable, tape = Config.TapeOverlay, ribbon = Config.Ribbon }
local SIZE = Config.Tiers.Birthday.presentStuds
local PER = PanelGrid.gridPerFace(SIZE, Config.Panels)
local T = Config.Greybox.panelThickness

local function tornAll(model, except)
	for id, item in model.items do
		if not item.bottom and id ~= except then
			PanelGrid.setTorn(model, id, true)
		end
	end
end

return function(test, expectEqual)
	test("paper: one item per panel, bottom face on the floor", function()
		local m = LayerModel.build({ layerType = "Paper", depth = 2 }, PER, RULES)
		expectEqual(m.count, 6 * PER * PER, "count")
		local bottom = 0
		for _, item in m.items do
			if item.bottom then
				bottom += 1
			end
		end
		expectEqual(bottom, PER * PER, "bottom panels")
		expectEqual(LayerModel.remaining(m), 5 * PER * PER, "panels to clear by hand")
	end)

	test("a tape strip blocks every panel it touches (8 at 4x4) until it is cut", function()
		local strip = { seamIndex = 1, face = 5, along = "row", line = 2, cut = false }
		local m = LayerModel.build({ layerType = "Paper", depth = 2, tapeStrips = { strip } }, PER, RULES)
		local stripId = m.count
		expectEqual(m.items[stripId].kind, "Tape", "last item is the strip")
		local blocked = 0
		for id, item in m.items do
			if table.find(item.blockedBy, stripId) then
				blocked += 1
				expectEqual(item.face, 5, "same face")
				assert(item.row == 2 or item.row == 3, `row {item.row} is not beside line 2`)
				expectEqual(select(2, LayerModel.canStart(m, id)), "taped", `panel {id}`)
			end
		end
		expectEqual(blocked, 2 * PER, "panels touched")
		PanelGrid.setTorn(m, stripId, true)
		for id, item in m.items do
			if table.find(item.blockedBy, stripId) then
				expectEqual(LayerModel.canStart(m, id), true, `panel {id} after the cut`)
			end
		end
	end)

	test("a panel under two strips needs both cut", function()
		local strips = {
			{ seamIndex = 1, face = 5, along = "row", line = 1, cut = false },
			{ seamIndex = 2, face = 5, along = "col", line = 1, cut = false },
		}
		local m = LayerModel.build({ layerType = "Paper", depth = 2, tapeStrips = strips }, PER, RULES)
		local corner = PanelGrid.panelId({ perFace = PER } :: any, 5, 1, 1)
		expectEqual(#m.items[corner].blockedBy, 2, "blockers")
		PanelGrid.setTorn(m, m.count - 1, true)
		expectEqual(LayerModel.canStart(m, corner), false, "one strip left")
		PanelGrid.setTorn(m, m.count, true)
		expectEqual(LayerModel.canStart(m, corner), true, "both cut")
	end)

	test("ribbon: 8 segments and a bow, all Snip grade 1, two segments on the floor", function()
		local m = LayerModel.build({ layerType = "Ribbon", depth = 1 }, PER, RULES)
		expectEqual(m.count, 9, "count")
		local bottom, bows = 0, 0
		for _, item in m.items do
			expectEqual(item.action, "Snip", "action")
			expectEqual(item.grade, 1, "grade")
			if item.bottom then
				bottom += 1
			end
			if item.kind == "Bow" then
				bows += 1
			end
		end
		expectEqual(bottom, 2, "bottom segments")
		expectEqual(bows, 1, "bows")
		expectEqual(LayerModel.remaining(m), 7, "snips by hand")
	end)

	test("lid: one Lift panel", function()
		local m = LayerModel.build({ layerType = "BoxLid", depth = 4 }, 1, RULES)
		expectEqual(m.count, 1, "count")
		expectEqual(m.items[1].action, "Lift", "action")
	end)

	test("a layer clears when everything off the floor is done; the floor items then drop", function()
		local m = LayerModel.build({ layerType = "Ribbon", depth = 1 }, PER, RULES)
		local last
		for id, item in m.items do
			if not item.bottom then
				last = id
			end
		end
		tornAll(m, last)
		expectEqual(LayerModel.isCleared(m), false, "one left")
		PanelGrid.setTorn(m, last, true)
		expectEqual(LayerModel.isCleared(m), true, "cleared")
		expectEqual(#LayerModel.dropBottom(m), 2, "dropped")
		for id = 1, m.count do
			expectEqual(PanelGrid.isTorn(m, id), true, `item {id}`)
		end
	end)

	test("geometry: panels inside the shell, tape just outside on its line, lid on top", function()
		local strip = { seamIndex = 1, face = 1, along = "col", line = 1, cut = false }
		local m = LayerModel.build({ layerType = "Paper", depth = 2, tapeStrips = { strip } }, PER, RULES)
		local half = SIZE / 2
		for id = 1, m.count - 1 do
			local p = LayerGeometry.place(m, id, SIZE, T, Config.TapeOverlay.stripStuds)
			local n = p.normal
			local along = p.center.x * n.x + p.center.y * n.y + p.center.z * n.z
			assert(math.abs(along - (half - T / 2)) < 1e-9, `panel {id} not inset by half a thickness`)
		end
		local tape = LayerGeometry.place(m, m.count, SIZE, T, Config.TapeOverlay.stripStuds)
		assert(math.abs(tape.center.x - (half + T / 2)) < 1e-9, "tape not on the outside of face +X")
		expectEqual(tape.sizeY, SIZE, "tape runs the full face")
		expectEqual(tape.sizeX, Config.TapeOverlay.stripStuds, "tape width")
		local lid = LayerModel.build({ layerType = "BoxLid", depth = 4 }, 1, RULES)
		local top = LayerGeometry.place(lid, 1, SIZE, T, Config.TapeOverlay.stripStuds)
		expectEqual(top.normal.y, 1, "lid faces up")
		expectEqual(#LayerGeometry.walls(SIZE, T), 5, "box walls")
	end)

	test("geometry: ribbon bands are one panel wide and cross on top", function()
		local m = LayerModel.build({ layerType = "Ribbon", depth = 1 }, PER, RULES)
		local w = SIZE / PER
		local tops = {}
		for id, item in m.items do
			local p = LayerGeometry.place(m, id, SIZE, T, Config.TapeOverlay.stripStuds)
			if item.kind == "Segment" then
				expectEqual(math.min(p.sizeX, p.sizeY), w, `segment {id} width`)
				expectEqual(math.max(p.sizeX, p.sizeY), SIZE, `segment {id} length`)
				if item.face == PanelGrid.TOP then
					table.insert(tops, p)
				end
			else
				assert(p.center.y > SIZE / 2, "bow sits above the top")
			end
		end
		expectEqual(#tops, 2, "two segments on top")
		assert(tops[1].sizeX ~= tops[2].sizeX, "top segments run across each other")
		assert(tops[1].center.y ~= tops[2].center.y, "crossing segments do not share a plane")
	end)

	test("lid: needs the required holders, keeps progress when they let go", function()
		local seconds = Config.Tools.Hands.actions.Lift
		local s = LidSession.new(2, seconds)
		expectEqual(LidSession.join(s, "a", 0), nil, "one holder of two")
		expectEqual(LidSession.join(s, "b", 1), seconds, "two holders: full time left")
		expectEqual(LidSession.leave(s, "b", 1 + seconds / 2), nil, "back to one")
		assert(math.abs(LidSession.fraction(s, 50) - 0.5) < 1e-9, "progress kept")
		local left = LidSession.join(s, "c", 60) :: number
		assert(math.abs(left - seconds / 2) < 1e-9, "rest of the lift")
		expectEqual(LidSession.isDone(s, 60 + left), true, "lifted")
	end)

	test("lid: two holders from tier 2, never more than the players present", function()
		local from = Config.LayerTable.BoxLid.twoPlayerFromTier
		expectEqual(LidSession.requiredHolders(1, from, 4), 1, "Birthday")
		expectEqual(LidSession.requiredHolders(2, from, 4), 2, "Christmas")
		expectEqual(LidSession.requiredHolders(2, from, 1), 1, "Christmas solo")
	end)

	test("tools: hands tear and lift, cannot snip or cut; scissors can; fastest wins; grip tape scales", function()
		local hands = {}
		expectEqual(Tools.best(hands, "Tear", 0, Config.Tools), Config.Tools.Hands.actions.Tear, "hands tear")
		expectEqual(Tools.best(hands, "Snip", 1, Config.Tools), nil, "hands snip")
		expectEqual(Tools.best(hands, "Cut", 1, Config.Tools), nil, "hands cut tape")
		local scissors = { Scissors = true }
		expectEqual(Tools.best(scissors, "Snip", 1, Config.Tools), Config.Tools.Scissors.actions.Snip, "scissors snip")
		expectEqual(Tools.best(scissors, "Cut", 1, Config.Tools), Config.TapeOverlay.stripSeconds.Scissors, "scissors cut tape")
		expectEqual(Tools.best(scissors, "Tear", 0, Config.Tools), Config.Tools.Scissors.actions.Tear, "scissors tear faster")
		local both = { Scissors = true, BoxCutter = true }
		expectEqual(select(2, Tools.best(both, "Cut", 1, Config.Tools)), "BoxCutter", "box cutter is faster")
		local scale = Config.Shop.GripTape.panelTimeScale
		local s = Tools.best(hands, "Tear", 0, Config.Tools, scale)
		assert(math.abs(s - Config.Tools.Hands.actions.Tear * scale) < 1e-9, "grip tape")
	end)
end
