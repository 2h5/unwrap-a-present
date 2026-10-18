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
				for i = 1, n - 2 do
					assert(nest.layers[i].layerType ~= "BoxLid", `{tier}/{seed}: lid before the end at {i}`)
					if i > 1 then
						assert(nest.layers[i].layerType ~= nest.layers[i - 1].layerType, `{tier}/{seed}: repeat at {i}`)
					end
				end
			end)
		end
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
			for i = 1, n - 2 do
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
