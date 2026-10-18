--[=[
	LayerModel (pure logic, server)
	Owns: one layer as a list of items (paper panels, tape strips, ribbon segments and bow, a lid),
	each with its action, tool grade, what blocks it, and a torn/cut bitfield over all of them.
	Rules: N28 (a strip blocks every panel it touches), N29 (ribbon = 8 segments + 1 bow), Glossary
	(a box lid is one panel). Bottom-face items rest on the floor: never interactive, they fall away
	when the rest of the layer clears.
	Must never: call game:GetService or touch an Instance. Bit operations reuse PanelGrid.
	Read first: src/server/Tear/README.md
]=]

local PanelGrid = require("./PanelGrid")

export type Item = {
	kind: string, -- "Panel" | "Tape" | "Segment" | "Bow" | "Lid"
	action: string,
	grade: number,
	bottom: boolean,
	blockedBy: { number },
	face: number?,
	row: number?,
	col: number?,
	along: string?, -- tape: "row" | "col"
	line: number?, -- tape
	band: string?, -- ribbon segment: "A" (faces top, +Z, bottom, -Z) | "B" (top, +X, bottom, -X)
}

export type Model = {
	depth: number,
	layerType: string,
	perFace: number, -- grid size for Paper; the wrapped layer's grid for Ribbon (sets ribbon width)
	count: number,
	items: { Item },
	torn: buffer,
}

export type Rules = {
	layerTable: { [string]: any }, -- Config.LayerTable
	tape: { action: string, grade: number }, -- Config.TapeOverlay
	ribbon: { bands: number, facesPerBand: number, bows: number }, -- Config.Ribbon
}

local RIBBON_BANDS = {
	A = { PanelGrid.TOP, 5, PanelGrid.BOTTOM, 6 }, -- +Y, +Z, -Y, -Z: runs round the X axis
	B = { PanelGrid.TOP, 1, PanelGrid.BOTTOM, 2 }, -- +Y, +X, -Y, -X: runs round the Z axis
}

local LayerModel = {}

local function finish(layer: any, perFace: number, items: { Item }): Model
	return {
		depth = layer.depth,
		layerType = layer.layerType,
		perFace = perFace,
		count = #items,
		items = items,
		torn = buffer.create(math.max(1, math.ceil(#items / 8))),
	}
end

local function paper(layer: any, perFace: number, rules: Rules): Model
	local rule = rules.layerTable.Paper
	local items: { Item } = {}
	local idOf = {}
	for face = 1, PanelGrid.faceCount do
		for row = 1, perFace do
			for col = 1, perFace do
				table.insert(items, {
					kind = "Panel",
					action = rule.action,
					grade = rule.grade,
					bottom = face == PanelGrid.BOTTOM,
					blockedBy = {},
					face = face,
					row = row,
					col = col,
				})
				idOf[`{face}:{row}:{col}`] = #items
			end
		end
	end
	for _, strip in layer.tapeStrips or {} do
		table.insert(items, {
			kind = "Tape",
			action = rules.tape.action,
			grade = rules.tape.grade,
			bottom = strip.face == PanelGrid.BOTTOM,
			blockedBy = {},
			face = strip.face,
			along = strip.along,
			line = strip.line,
		})
		local stripId = #items
		for _, side in { strip.line, strip.line + 1 } do
			for k = 1, perFace do
				local row = if strip.along == "row" then side else k
				local col = if strip.along == "row" then k else side
				table.insert(items[idOf[`{strip.face}:{row}:{col}`]].blockedBy, stripId)
			end
		end
	end
	return finish(layer, perFace, items)
end

local function ribbon(layer: any, wrappedPerFace: number, rules: Rules): Model
	local rule = rules.layerTable.Ribbon
	local items: { Item } = {}
	for _, band in { "A", "B" } do
		for _, face in RIBBON_BANDS[band] do
			table.insert(items, {
				kind = "Segment",
				action = rule.action,
				grade = rule.grade,
				bottom = face == PanelGrid.BOTTOM,
				blockedBy = {},
				face = face,
				band = band,
			})
		end
	end
	table.insert(items, { kind = "Bow", action = rule.action, grade = rule.grade, bottom = false, blockedBy = {} })
	local expected = rules.ribbon.bands * rules.ribbon.facesPerBand + rules.ribbon.bows
	assert(#items == expected, `LayerModel: ribbon has {#items} panels, Config.Ribbon says {expected}`)
	return finish(layer, wrappedPerFace, items)
end

local function lid(layer: any, rules: Rules): Model
	local rule = rules.layerTable.BoxLid
	return finish(layer, 1, {
		{ kind = "Lid", action = rule.action, grade = rule.grade, bottom = false, blockedBy = {} },
	})
end

-- `perFace` is the layer's own grid for Paper, and the grid of the layer it wraps for Ribbon.
function LayerModel.build(layer: any, perFace: number, rules: Rules): Model
	if layer.layerType == "Paper" then
		return paper(layer, perFace, rules)
	elseif layer.layerType == "Ribbon" then
		return ribbon(layer, perFace, rules)
	elseif layer.layerType == "BoxLid" then
		return lid(layer, rules)
	end
	error(`LayerModel: {layer.layerType} is not built yet`)
end

function LayerModel.isTorn(model: Model, id: number): boolean
	return PanelGrid.isTorn(model :: any, id)
end

-- Whether a player may start on this item now. Returns false and a reason if not.
function LayerModel.canStart(model: Model, id: number): (boolean, string?)
	local item = model.items[id]
	if not item then
		return false, "no such panel"
	end
	if item.bottom then
		return false, "on the floor"
	end
	if PanelGrid.isTorn(model :: any, id) then
		return false, "already torn"
	end
	for _, blocker in item.blockedBy do
		if not PanelGrid.isTorn(model :: any, blocker) then
			return false, "taped"
		end
	end
	return true, nil
end

-- Items still to clear by hand (bottom-face items do not count).
function LayerModel.remaining(model: Model): number
	local left = 0
	for id, item in model.items do
		if not item.bottom and not PanelGrid.isTorn(model :: any, id) then
			left += 1
		end
	end
	return left
end

function LayerModel.isCleared(model: Model): boolean
	return LayerModel.remaining(model) == 0
end

-- Marks every bottom-face item torn (the layer has cleared). Returns their ids.
function LayerModel.dropBottom(model: Model): { number }
	local dropped = {}
	for id, item in model.items do
		if item.bottom and not PanelGrid.isTorn(model :: any, id) then
			PanelGrid.setTorn(model :: any, id, true)
			table.insert(dropped, id)
		end
	end
	return dropped
end

return LayerModel
