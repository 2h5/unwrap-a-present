--[=[
	Test runner (Lune). Run from the repo root: lune run tests/run
	Owns: a tiny test/expect harness and the list of spec files.
	Must never: require a module that calls game:GetService. Specs test pure-logic modules only.
	Read first: tests/README.md
]=]

local process = require("@lune/process")

local SPECS = {
	{ name = "Tear/PanelGrid", run = require("./Tear/PanelGrid.spec") },
	{ name = "Tear/TearSession", run = require("./Tear/TearSession.spec") },
	{ name = "Tear/Layer", run = require("./Tear/Layer.spec") },
	{ name = "Debris/DebrisPool", run = require("./Debris/DebrisPool.spec") },
	{ name = "Present/Nest", run = require("./Present/Nest.spec") },
	{ name = "Loot/Rarity", run = require("./Loot/Rarity.spec") },
	{ name = "Loot/Bank", run = require("./Loot/Bank.spec") },
	{ name = "Data/Schema", run = require("./Data/Schema.spec") },
}

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print(`  ok   {name}`)
	else
		failed += 1
		print(`  FAIL {name}\n       {err}`)
	end
end

local function expectEqual(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

for _, spec in SPECS do
	print(spec.name)
	spec.run(test, expectEqual)
end

print(`\n{passed} passed, {failed} failed`)
process.exit(if failed == 0 then 0 else 1)
