-- Spec for src/server/Present/Nest.luau and src/shared/Rng/Rng.luau. Numbers come from Config.

local Nest = require("../../src/server/Present/Nest")
local Rng = require("../../src/shared/Rng/Rng")
local Config = require("../../src/shared/Config/Config")

local ALL_TYPES = { "Paper", "Ribbon", "BubbleWrap", "Foil", "Chains", "Ice", "BoxLid" }
local SEEDS = 500

local function config(layerTypes)
	return { tiers = Config.Tiers, layerTable = Config.LayerTable, layerTypes = layerTypes }
end

local function eachNest(layerTypes, fn)
	for _, tier in Config.Tiers.order do
		for seed = 1, SEEDS do
			fn(Nest.generate(seed, tier, config(layerTypes), Rng), tier, seed)
		end
	end
end

return function(test, expectEqual)
	test("rng: same seed, same sequence; values in [0, 1)", function()
		local a, b = Rng.new(42), Rng.new(42)
		for i = 1, 1000 do
			local x = Rng.next(a)
			expectEqual(Rng.next(b), x, `step {i}`)
			assert(x >= 0 and x < 1, `out of range: {x}`)
		end
	end)

	test("rng: seed 0 still produces numbers", function()
		local r = Rng.new(0)
		assert(Rng.next(r) ~= Rng.next(r), "stuck at one value")
	end)

	test("rng: weighted never picks a zero weight", function()
		local r = Rng.new(7)
		for _ = 1, 2000 do
			local v = Rng.weighted(r, { { value = "a", weight = 0 }, { value = "b", weight = 3 }, { value = "c", weight = 0 } })
			expectEqual(v, "b", "pick")
		end
		expectEqual(Rng.weighted(r, { { value = "a", weight = 0 } }), nil, "nothing pickable")
	end)

	test("layer count matches the tier, depths run 0..n-1", function()
		eachNest(Config.LaunchLayerTypes, function(nest, tier)
			expectEqual(#nest.layers, Config.Tiers[tier].layers, `{tier} count`)
			for i, layer in nest.layers do
				expectEqual(layer.depth, i - 1, `{tier} depth`)
			end
		end)
	end)

	test("nest never repeats a type twice in a row and always ends in two lids", function()
		for _, types in { Config.LaunchLayerTypes, ALL_TYPES } do
			eachNest(types, function(nest, tier, seed)
				local n = #nest.layers
				expectEqual(nest.layers[n].layerType, "BoxLid", `{tier}/{seed} last`)
				expectEqual(nest.layers[n - 1].layerType, "BoxLid", `{tier}/{seed} second to last`)
				assert(nest.layers[n - 2].layerType ~= "BoxLid", `{tier}/{seed}: three lids at the end`)
				for i = 2, n - 2 do
					assert(nest.layers[i].layerType ~= nest.layers[i - 1].layerType, `{tier}/{seed}: repeat at {i}`)
				end
			end)
		end
	end)

	test("depth 0 is always Paper", function()
		eachNest(ALL_TYPES, function(nest, tier, seed)
			expectEqual(nest.layers[1].layerType, "Paper", `{tier}/{seed} depth 0`)
		end)
	end)

	test("at least one BoxLid sits in the middle third", function()
		for _, types in { Config.LaunchLayerTypes, ALL_TYPES } do
			eachNest(types, function(nest, tier, seed)
				local n = #nest.layers
				local found = false
				for i = 1, n - 2 do
					local layer = nest.layers[i]
					if layer.layerType == "BoxLid" and Nest.band(layer.depth, n) == 2 then
						found = true
					end
				end
				assert(found, `{tier}/{seed}: no middle-third lid`)
			end)
		end
	end)

	test("sizes: depth 0 is the present size, the core is 6, shells shrink evenly, ribbon wraps", function()
		eachNest(Config.LaunchLayerTypes, function(nest, tier, seed)
			local outer = Config.Tiers[tier].presentStuds
			local sizes = Nest.sizes(nest, outer, Config.Tiers.coreBoxStuds)
			local n = #nest.layers
			expectEqual(sizes[0], outer, `{tier}/{seed} outer`)
			expectEqual(sizes[n - 1], Config.Tiers.coreBoxStuds, `{tier}/{seed} core`)
			local last, step = nil, nil
			for _, layer in nest.layers do
				local size = sizes[layer.depth]
				if layer.layerType == "Ribbon" then
					expectEqual(size, sizes[layer.depth + 1], `{tier}/{seed} ribbon wraps`)
				else
					if last then
						local s = last - size
						assert(s > 0, `{tier}/{seed}: shell at {layer.depth} does not shrink`)
						if step then
							assert(math.abs(s - step) < 1e-9, `{tier}/{seed}: uneven step at {layer.depth}`)
						end
						step = s
					end
					last = size
				end
			end
		end)
	end)

	test("only the build's layer types appear", function()
		local allowed = {}
		for _, t in Config.LaunchLayerTypes do
			allowed[t] = true
		end
		eachNest(Config.LaunchLayerTypes, function(nest, tier, seed)
			for _, layer in nest.layers do
				assert(allowed[layer.layerType], `{tier}/{seed}: {layer.layerType} is not in this build`)
			end
		end)
	end)

	test("a type with weight 0 in a band never appears in that band", function()
		eachNest(ALL_TYPES, function(nest, tier, seed)
			local n = #nest.layers
			for i = 2, n - 2 do
				local layer = nest.layers[i]
				local band = Nest.band(layer.depth, n)
				local weight = Config.LayerTable[layer.layerType].weights[band]
				assert(weight > 0, `{tier}/{seed}: {layer.layerType} at band {band} has weight 0`)
			end
		end)
	end)

	test("same seed and tier give the same nest; seeds differ", function()
		local cfg = config(ALL_TYPES)
		local a = Nest.generate(99, "Wedding", cfg, Rng)
		local b = Nest.generate(99, "Wedding", cfg, Rng)
		for i, layer in a.layers do
			expectEqual(b.layers[i].layerType, layer.layerType, `layer {i}`)
		end
		local distinct = {}
		for seed = 1, 50 do
			local key = {}
			for _, layer in Nest.generate(seed, "Wedding", cfg, Rng).layers do
				table.insert(key, layer.layerType)
			end
			distinct[table.concat(key, ",")] = true
		end
		local count = 0
		for _ in distinct do
			count += 1
		end
		assert(count > 10, `only {count} distinct nests from 50 seeds`)
	end)

	test("tape: only Paper, never depth 0, never the floor face, 25-50% of the seams", function()
		local PanelGrid = require("../../src/server/Tear/PanelGrid")
		local perFaceOf = function(studs)
			return PanelGrid.gridPerFace(studs, Config.Panels)
		end
		local taped, paperBeyond0 = 0, 0
		eachNest(Config.LaunchLayerTypes, function(nest, tier, seed)
			local sizes = Nest.sizes(nest, Config.Tiers[tier].presentStuds, Config.Tiers.coreBoxStuds)
			Nest.tape(nest, sizes, perFaceOf, Config.TapeOverlay, PanelGrid.faceCount, PanelGrid.BOTTOM, Rng)
			for _, layer in nest.layers do
				local strips = layer.tapeStrips
				if layer.layerType == "Paper" and layer.depth > 0 then
					paperBeyond0 += 1
				end
				if strips then
					taped += 1
					assert(layer.layerType == "Paper" and layer.depth > 0, `{tier}/{seed}: tape on {layer.layerType} at {layer.depth}`)
					local per = perFaceOf(sizes[layer.depth])
					local seams = (PanelGrid.faceCount - 1) * 2 * (per - 1)
					local lo = math.floor(Config.TapeOverlay.seamFraction[1] * seams + 0.5)
					local hi = math.floor(Config.TapeOverlay.seamFraction[2] * seams + 0.5)
					assert(#strips >= math.max(1, lo) and #strips <= hi, `{tier}/{seed}: {#strips} strips of {seams} seams`)
					local seen = {}
					for _, s in strips do
						assert(s.face ~= PanelGrid.BOTTOM, "tape on the floor face")
						assert(s.line >= 1 and s.line < per, "line off the grid")
						assert(not seen[s.seamIndex], "same seam taped twice")
						seen[s.seamIndex] = true
					end
				end
			end
		end)
		assert(taped > 0 and taped < paperBeyond0, `taped {taped} of {paperBeyond0} paper layers`)
	end)

	test("lid tape: every BoxLid gets one strip per side from tier 2, none at tier 1 (N36)", function()
		local PanelGrid = require("../../src/server/Tear/PanelGrid")
		local perFaceOf = function(studs)
			return PanelGrid.gridPerFace(studs, Config.Panels)
		end
		local cfg = config(Config.LaunchLayerTypes)
		for tierNumber, tier in Config.Tiers.order do
			for seed = 1, 50 do
				local nest = Nest.generate(seed, tier, cfg, Rng)
				local sizes = Nest.sizes(nest, Config.Tiers[tier].presentStuds, Config.Tiers.coreBoxStuds)
				Nest.tape(nest, sizes, perFaceOf, Config.TapeOverlay, PanelGrid.faceCount, PanelGrid.BOTTOM, Rng, tierNumber)
				for _, layer in nest.layers do
					if layer.layerType == "BoxLid" then
						local want = if tierNumber >= Config.TapeOverlay.boxLidFromTier then Config.TapeOverlay.boxLidStrips else 0
						expectEqual(#(layer.tapeStrips or {}), want, `{tier}/{seed} lid at {layer.depth}`)
					end
				end
			end
		end
	end)

	test("tape is the same for the same seed and does not change the layer types", function()
		local PanelGrid = require("../../src/server/Tear/PanelGrid")
		local perFaceOf = function(studs)
			return PanelGrid.gridPerFace(studs, Config.Panels)
		end
		local cfg = config(Config.LaunchLayerTypes)
		for seed = 1, 50 do
			local a = Nest.generate(seed, "Wedding", cfg, Rng)
			local b = Nest.generate(seed, "Wedding", cfg, Rng)
			local sizes = Nest.sizes(a, Config.Tiers.Wedding.presentStuds, Config.Tiers.coreBoxStuds)
			Nest.tape(a, sizes, perFaceOf, Config.TapeOverlay, PanelGrid.faceCount, PanelGrid.BOTTOM, Rng)
			Nest.tape(b, sizes, perFaceOf, Config.TapeOverlay, PanelGrid.faceCount, PanelGrid.BOTTOM, Rng)
			local plain = Nest.generate(seed, "Wedding", cfg, Rng)
			for i, layer in a.layers do
				expectEqual(layer.layerType, plain.layers[i].layerType, `{seed} layer {i}`)
				expectEqual(#(layer.tapeStrips or {}), #(b.layers[i].tapeStrips or {}), `{seed} strips {i}`)
			end
		end
	end)

	test("depth bands split the nest in thirds", function()
		local bands = {}
		for depth = 0, 5 do
			table.insert(bands, Nest.band(depth, 6))
		end
		expectEqual(table.concat(bands, ""), "112233", "Birthday bands")
		expectEqual(Nest.band(0, 16), 1, "Package first")
		expectEqual(Nest.band(15, 16), 3, "Package last")
	end)
end
