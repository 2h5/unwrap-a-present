--[=[
	GiftModels (shared)
	Owns: one chunky toy model per launch gift (N31: 32 side-gifts, 18 core gifts), built from blocks,
	balls, cylinders and wedges so each has its own silhouette: Art bible A's loot style, flat colours
	from the gift's rarity plus one accent. These are the placeholders until the commissioned models
	(N7) arrive; a model in ReplicatedStorage.Assets.Gifts named by gift id replaces one with no code
	change. Mutations: Giant (scale), Golden (gold base, reflectance). Secret base parts are tagged
	`LootBase` so the caller sweeps their hue.
	Must never: decide a gift or a rarity (Loot rolls on the server), or put dot relief anywhere but here.
	Read first: src/shared/README.md
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Art = require(ReplicatedStorage.Shared.Art.Art)

local GiftModels = {}

local L = Config.LootLook

-- A recipe part: shape, size (x, y, z), centre (x, y, z), colour key, rotation in degrees (x, y, z).
-- Units: the model stands on y = 0 and its largest side is about 1; `build` scales it to studs.
-- Shapes: B block, S ball (size x only), C cylinder (along x), V cylinder standing up (size x = height), W wedge.
type Piece = { any }

local function p(shape: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, color: string, rx: number?, ry: number?, rz: number?): Piece
	return { shape, sx, sy, sz, x, y, z, color, rx or 0, ry or 0, rz or 0 }
end

-- Two of a piece, mirrored across x = 0.
local function pair(shape: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, color: string, rx: number?, ry: number?, rz: number?): { Piece }
	return { p(shape, sx, sy, sz, x, y, z, color, rx, ry, rz), p(shape, sx, sy, sz, -x, y, z, color, rx, if ry then -ry else nil, if rz then -rz else nil) }
end

-- Four wheels of diameter d at half-length hx and half-width hz.
local function wheels(d: number, hx: number, hz: number, y: number?): { Piece }
	local out = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(out, p("C", d * 0.45, d, d, sx * hx, y or d / 2, sz * hz, "ink", 0, 90, 0))
		end
	end
	return out
end

local function eyes(spread: number, y: number, z: number, d: number?): { Piece }
	return pair("S", d or 0.06, 0, 0, spread, y, z, "ink")
end

-- Front of every model faces -z.
local RECIPES: { [string]: { any } } = {
	---------------------------------------------------------------- plush
	PlushBear = {
		p("S", 0.6, 0, 0, 0, 0.3, 0, "base"),
		p("S", 0.46, 0, 0, 0, 0.74, -0.02, "base"),
		pair("S", 0.18, 0, 0, 0.18, 0.95, 0, "shade"),
		p("S", 0.18, 0, 0, 0, 0.68, -0.21, "accent"),
		eyes(0.09, 0.8, -0.19),
		pair("S", 0.22, 0, 0, 0.3, 0.4, -0.06, "shade"),
		p("S", 0.3, 0, 0, 0, 0.3, -0.18, "accent"),
	},
	PlushBunny = {
		p("S", 0.56, 0, 0, 0, 0.28, 0, "base"),
		p("S", 0.42, 0, 0, 0, 0.66, -0.02, "base"),
		pair("B", 0.12, 0.38, 0.08, 0.1, 1.0, 0.02, "base", 0, 0, 8),
		pair("B", 0.06, 0.28, 0.02, 0.1, 0.99, -0.03, "accent", 0, 0, 8),
		eyes(0.09, 0.71, -0.18),
		p("S", 0.07, 0, 0, 0, 0.63, -0.21, "shade"),
		p("S", 0.18, 0, 0, 0, 0.22, 0.28, "accent"),
	},
	PlushWhale = {
		p("C", 0.6, 0.48, 0.48, 0.05, 0.26, 0, "base"),
		p("S", 0.48, 0, 0, -0.25, 0.26, 0, "base"),
		p("S", 0.4, 0, 0, 0.35, 0.26, 0, "base"),
		p("W", 0.2, 0.05, 0.14, -0.05, 0.1, -0.28, "shade", 0, 180, 0),
		p("W", 0.2, 0.05, 0.14, -0.05, 0.1, 0.28, "shade"),
		p("B", 0.7, 0.06, 0.34, -0.02, 0.06, 0, "accent"),
		p("W", 0.08, 0.26, 0.3, 0.6, 0.42, 0, "shade", 0, 90, 0),
		p("S", 0.07, 0, 0, -0.4, 0.32, -0.18, "ink"),
		p("S", 0.07, 0, 0, -0.4, 0.32, 0.18, "ink"),
		p("V", 0.14, 0.05, 0.05, -0.22, 0.56, 0, "accent"),
	},
	PlushDragon = {
		p("S", 0.52, 0, 0, 0, 0.27, 0.02, "base"),
		p("S", 0.38, 0, 0, 0, 0.66, -0.04, "base"),
		p("B", 0.24, 0.16, 0.2, 0, 0.6, -0.24, "accent"),
		pair("W", 0.06, 0.18, 0.12, 0.11, 0.88, 0.02, "shade"),
		pair("W", 0.06, 0.34, 0.3, 0.3, 0.46, 0.12, "shade", 0, 0, -35),
		p("W", 0.12, 0.16, 0.42, 0, 0.12, 0.36, "base"),
		eyes(0.1, 0.72, -0.17),
		p("W", 0.05, 0.12, 0.12, 0, 0.56, 0.24, "accent"),
	},
	---------------------------------------------------------------- vehicle
	ToyTruck = {
		p("B", 0.92, 0.16, 0.44, 0, 0.22, 0, "shade"),
		p("B", 0.52, 0.3, 0.44, 0.2, 0.45, 0, "base"),
		p("B", 0.32, 0.36, 0.44, -0.3, 0.48, 0, "base"),
		p("B", 0.03, 0.16, 0.36, -0.47, 0.54, 0, "accent"),
		p("B", 0.04, 0.08, 0.4, -0.47, 0.28, 0, "accent"),
		wheels(0.26, 0.3, 0.2),
	},
	ToyPlane = {
		p("C", 0.9, 0.22, 0.22, 0, 0.42, 0, "base"),
		p("S", 0.22, 0, 0, -0.45, 0.42, 0, "accent"),
		p("B", 0.24, 0.04, 0.98, -0.05, 0.42, 0, "shade"),
		p("W", 0.04, 0.22, 0.2, 0.42, 0.58, 0, "shade", 0, 90, 0),
		p("B", 0.14, 0.03, 0.38, 0.4, 0.46, 0, "shade"),
		p("B", 0.02, 0.36, 0.06, -0.57, 0.42, 0, "ink"),
		p("C", 0.05, 0.12, 0.12, -0.1, 0.06, -0.14, "ink", 0, 90, 0),
		p("C", 0.05, 0.12, 0.12, -0.1, 0.06, 0.14, "ink", 0, 90, 0),
		p("V", 0.26, 0.03, 0.03, -0.1, 0.19, -0.14, "ink"),
		p("V", 0.26, 0.03, 0.03, -0.1, 0.19, 0.14, "ink"),
	},
	ToyBoat = {
		p("B", 0.66, 0.2, 0.38, 0.08, 0.14, 0, "base"),
		p("W", 0.38, 0.2, 0.24, -0.37, 0.14, 0, "base", 0, 90, 0),
		p("B", 0.7, 0.05, 0.4, 0.06, 0.26, 0, "accent"),
		p("V", 0.62, 0.04, 0.04, 0.02, 0.58, 0, "ink"),
		p("W", 0.03, 0.5, 0.36, 0.13, 0.56, 0, "accent", 0, 90, 0),
		p("B", 0.1, 0.06, 0.02, 0.05, 0.92, 0, "shade"),
	},
	ToyTrain = {
		p("B", 0.84, 0.1, 0.36, 0, 0.16, 0, "shade"),
		p("C", 0.52, 0.32, 0.32, -0.1, 0.38, 0, "base"),
		p("B", 0.26, 0.44, 0.36, 0.28, 0.43, 0, "shade"),
		p("B", 0.3, 0.05, 0.4, 0.28, 0.67, 0, "base"),
		p("V", 0.2, 0.1, 0.1, -0.26, 0.62, 0, "ink"),
		p("W", 0.1, 0.12, 0.34, -0.44, 0.13, 0, "accent", 0, -90, 0),
		p("B", 0.02, 0.12, 0.2, 0.42, 0.5, 0, "accent"),
		wheels(0.2, 0.24, 0.18, 0.12),
	},
	---------------------------------------------------------------- figure
	ToySoldier = {
		p("C", 0.08, 0.36, 0.36, 0, 0.04, 0, "shade", 0, 0, 90),
		pair("B", 0.1, 0.28, 0.12, 0.06, 0.22, 0, "ink"),
		p("B", 0.26, 0.3, 0.18, 0, 0.5, 0, "base"),
		p("B", 0.27, 0.04, 0.19, 0, 0.4, 0, "accent"),
		pair("B", 0.07, 0.28, 0.1, 0.17, 0.5, 0, "base"),
		p("S", 0.2, 0, 0, 0, 0.75, 0, "accent"),
		p("V", 0.26, 0.18, 0.18, 0, 0.96, 0, "ink"),
		eyes(0.04, 0.76, -0.09, 0.03),
	},
	ToyKnight = {
		p("C", 0.08, 0.36, 0.36, 0, 0.04, 0, "shade", 0, 0, 90),
		pair("B", 0.1, 0.26, 0.12, 0.06, 0.21, 0, "shade"),
		p("B", 0.28, 0.3, 0.2, 0, 0.48, 0, "base"),
		p("S", 0.26, 0, 0, 0, 0.76, 0, "shade"),
		p("B", 0.16, 0.04, 0.03, 0, 0.77, -0.12, "ink"),
		p("W", 0.04, 0.16, 0.2, 0, 0.93, 0.02, "base"),
		p("B", 0.22, 0.3, 0.04, -0.2, 0.46, -0.08, "accent"),
		p("B", 0.04, 0.48, 0.04, 0.2, 0.52, -0.08, "accent"),
		p("B", 0.12, 0.03, 0.05, 0.2, 0.34, -0.08, "shade"),
	},
	ToyAstronaut = {
		pair("B", 0.12, 0.26, 0.14, 0.07, 0.13, 0, "accent"),
		p("B", 0.32, 0.32, 0.22, 0, 0.42, 0, "base"),
		p("B", 0.24, 0.3, 0.12, 0, 0.44, 0.16, "shade"),
		pair("B", 0.08, 0.26, 0.12, 0.2, 0.42, 0, "base"),
		p("S", 0.34, 0, 0, 0, 0.74, 0, "accent"),
		p("B", 0.22, 0.13, 0.04, 0, 0.75, -0.15, "ink"),
		p("B", 0.12, 0.08, 0.02, 0, 0.47, -0.12, "accent"),
	},
	ToyDinosaur = {
		p("S", 0.5, 0, 0, 0.05, 0.36, 0, "base"),
		p("B", 0.16, 0.32, 0.16, -0.22, 0.6, 0, "base", 0, 0, -20),
		p("B", 0.3, 0.16, 0.18, -0.36, 0.78, 0, "base"),
		p("W", 0.14, 0.18, 0.46, 0.42, 0.3, 0, "shade", 0, -90, 0),
		pair("V", 0.22, 0.12, 0.12, 0.13, 0.11, 0.14, "shade"),
		pair("V", 0.22, 0.12, 0.12, -0.08, 0.11, 0.14, "shade"),
		p("W", 0.04, 0.12, 0.12, -0.02, 0.66, 0, "accent"),
		p("W", 0.04, 0.12, 0.12, 0.14, 0.62, 0, "accent"),
		p("W", 0.04, 0.1, 0.1, 0.28, 0.54, 0, "accent"),
		p("S", 0.05, 0, 0, -0.42, 0.82, -0.09, "ink"),
		p("S", 0.05, 0, 0, -0.42, 0.82, 0.09, "ink"),
	},
	---------------------------------------------------------------- candy
	CandyCane = {
		p("V", 0.72, 0.14, 0.14, 0, 0.36, 0, "base"),
		p("C", 0.14, 0.14, 0.14, -0.06, 0.76, 0, "base", 0, 0, 30),
		p("C", 0.14, 0.14, 0.14, -0.16, 0.8, 0, "base", 0, 0, 0),
		p("C", 0.14, 0.14, 0.14, -0.25, 0.74, 0, "base", 0, 0, -50),
		p("V", 0.04, 0.15, 0.15, 0, 0.16, 0, "accent"),
		p("V", 0.04, 0.15, 0.15, 0, 0.32, 0, "accent"),
		p("V", 0.04, 0.15, 0.15, 0, 0.48, 0, "accent"),
		p("V", 0.04, 0.15, 0.15, 0, 0.64, 0, "accent"),
	},
	Lollipop = {
		p("V", 0.5, 0.06, 0.06, 0, 0.25, 0, "accent"),
		p("C", 0.12, 0.6, 0.6, 0, 0.72, 0, "base", 0, 90, 0),
		p("C", 0.13, 0.42, 0.42, 0, 0.72, 0, "accent", 0, 90, 0),
		p("C", 0.14, 0.26, 0.26, 0, 0.72, 0, "base", 0, 90, 0),
		p("C", 0.15, 0.1, 0.1, 0, 0.72, 0, "shade", 0, 90, 0),
	},
	Gumdrop = {
		p("V", 0.24, 0.66, 0.66, 0, 0.12, 0, "base"),
		p("S", 0.62, 0, 0, 0, 0.26, 0, "base"),
		p("S", 0.06, 0, 0, 0.12, 0.5, -0.18, "accent"),
		p("S", 0.06, 0, 0, -0.16, 0.44, -0.2, "accent"),
		p("S", 0.06, 0, 0, 0.02, 0.56, 0.05, "accent"),
		p("S", 0.06, 0, 0, 0.22, 0.3, -0.24, "accent"),
	},
	ChocolateCoin = {
		p("C", 0.12, 0.8, 0.8, 0, 0.4, 0, "base", 0, 90, 0),
		p("C", 0.14, 0.62, 0.62, 0, 0.4, 0, "shade", 0, 90, 0),
		p("C", 0.15, 0.3, 0.3, 0, 0.4, 0, "accent", 0, 90, 0),
		p("B", 0.04, 0.16, 0.16, 0, 0.4, -0.08, "base", 0, 90, 45),
	},
	---------------------------------------------------------------- trinket
	Marble = {
		p("S", 0.62, 0, 0, 0, 0.31, 0, "base"),
		p("C", 0.08, 0.64, 0.64, 0, 0.31, 0, "accent", 0, 0, 25),
		p("S", 0.14, 0, 0, -0.12, 0.44, -0.2, "accent"),
		p("S", 0.1, 0, 0, 0.14, 0.2, -0.22, "shade"),
	},
	Keychain = {
		p("C", 0.05, 0.32, 0.32, 0, 0.82, 0, "accent", 0, 90, 0),
		p("C", 0.06, 0.2, 0.2, 0, 0.82, 0, "ink", 0, 90, 0),
		p("B", 0.38, 0.5, 0.08, 0, 0.38, 0, "base", 0, 0, 8),
		p("S", 0.08, 0, 0, 0.02, 0.56, -0.04, "ink"),
		p("B", 0.22, 0.06, 0.06, 0.06, 0.32, -0.06, "accent", 0, 0, 8),
		p("B", 0.06, 0.22, 0.04, -0.24, 0.62, 0.04, "shade", 0, 0, 30),
		p("B", 0.1, 0.06, 0.04, -0.3, 0.52, 0.04, "shade", 0, 0, 30),
	},
	SpinningTop = {
		p("S", 0.08, 0, 0, 0, 0.04, 0, "ink"),
		p("V", 0.12, 0.2, 0.2, 0, 0.12, 0, "accent"),
		p("V", 0.14, 0.42, 0.42, 0, 0.25, 0, "shade"),
		p("V", 0.16, 0.66, 0.66, 0, 0.4, 0, "base"),
		p("V", 0.04, 0.68, 0.68, 0, 0.42, 0, "accent"),
		p("V", 0.1, 0.4, 0.4, 0, 0.53, 0, "base"),
		p("V", 0.24, 0.08, 0.08, 0, 0.68, 0, "accent"),
	},
	MusicBox = {
		p("B", 0.72, 0.36, 0.5, 0, 0.18, 0, "base"),
		p("B", 0.74, 0.05, 0.52, 0, 0.2, 0, "accent"),
		p("B", 0.72, 0.05, 0.5, 0, 0.58, 0.28, "shade", -70, 0, 0),
		p("C", 0.12, 0.05, 0.05, 0.42, 0.2, 0, "accent"),
		p("B", 0.03, 0.14, 0.04, 0.48, 0.25, 0, "accent"),
		p("V", 0.08, 0.16, 0.16, 0, 0.4, -0.02, "shade"),
		p("V", 0.16, 0.06, 0.06, 0, 0.52, -0.02, "accent"),
		p("S", 0.1, 0, 0, 0, 0.64, -0.02, "accent"),
	},
	---------------------------------------------------------------- tech
	WalkieTalkie = {
		p("B", 0.34, 0.62, 0.18, 0, 0.31, 0, "base"),
		p("V", 0.36, 0.05, 0.05, 0.1, 0.8, 0, "ink"),
		p("S", 0.07, 0, 0, 0.1, 0.99, 0, "ink"),
		p("B", 0.24, 0.16, 0.02, 0, 0.18, -0.09, "accent"),
		p("B", 0.22, 0.1, 0.02, 0, 0.44, -0.09, "accent"),
		p("B", 0.08, 0.05, 0.03, -0.06, 0.55, -0.09, "ink"),
		p("B", 0.03, 0.14, 0.06, -0.18, 0.4, 0, "shade"),
	},
	ToyCamera = {
		p("B", 0.72, 0.42, 0.3, 0, 0.21, 0, "base"),
		p("B", 0.72, 0.08, 0.3, 0, 0.46, 0, "shade"),
		p("C", 0.14, 0.32, 0.32, 0, 0.21, -0.2, "shade", 0, 90, 0),
		p("C", 0.15, 0.2, 0.2, 0, 0.21, -0.21, "ink", 0, 90, 0),
		p("B", 0.16, 0.08, 0.02, -0.22, 0.36, -0.15, "accent"),
		p("V", 0.06, 0.1, 0.1, 0.24, 0.53, 0, "accent"),
	},
	PocketGame = {
		p("B", 0.46, 0.68, 0.1, 0, 0.34, 0, "base"),
		p("B", 0.34, 0.26, 0.02, 0, 0.5, -0.05, "accent"),
		p("B", 0.28, 0.2, 0.02, 0, 0.5, -0.06, "ink"),
		p("B", 0.12, 0.04, 0.03, -0.1, 0.2, -0.05, "ink"),
		p("B", 0.04, 0.12, 0.03, -0.1, 0.2, -0.05, "ink"),
		p("S", 0.07, 0, 0, 0.08, 0.17, -0.05, "shade"),
		p("S", 0.07, 0, 0, 0.14, 0.24, -0.05, "shade"),
	},
	Calculator = {
		p("B", 0.5, 0.72, 0.1, 0, 0.36, 0, "base"),
		p("B", 0.38, 0.14, 0.02, 0, 0.58, -0.05, "accent"),
		p("B", 0.1, 0.08, 0.03, -0.13, 0.4, -0.05, "shade"),
		p("B", 0.1, 0.08, 0.03, 0, 0.4, -0.05, "shade"),
		p("B", 0.1, 0.08, 0.03, 0.13, 0.4, -0.05, "accent"),
		p("B", 0.1, 0.08, 0.03, -0.13, 0.28, -0.05, "shade"),
		p("B", 0.1, 0.08, 0.03, 0, 0.28, -0.05, "shade"),
		p("B", 0.1, 0.08, 0.03, 0.13, 0.28, -0.05, "accent"),
		p("B", 0.1, 0.08, 0.03, -0.13, 0.16, -0.05, "shade"),
		p("B", 0.1, 0.08, 0.03, 0, 0.16, -0.05, "shade"),
		p("B", 0.1, 0.08, 0.03, 0.13, 0.16, -0.05, "accent"),
	},
	---------------------------------------------------------------- odd
	RubberDuck = {
		p("S", 0.56, 0, 0, 0.05, 0.27, 0, "base"),
		p("S", 0.38, 0, 0, -0.14, 0.62, 0, "base"),
		p("W", 0.16, 0.08, 0.16, -0.38, 0.58, 0, "shade", 0, 90, 0),
		p("W", 0.08, 0.16, 0.16, 0.34, 0.4, 0, "base", 0, -90, 0),
		p("S", 0.06, 0, 0, -0.24, 0.68, -0.13, "ink"),
		p("S", 0.06, 0, 0, -0.24, 0.68, 0.13, "ink"),
		p("W", 0.26, 0.12, 0.04, 0.05, 0.32, -0.26, "shade"),
		p("W", 0.26, 0.12, 0.04, 0.05, 0.32, 0.26, "shade"),
	},
	WhoopeeCushion = {
		p("V", 0.18, 0.72, 0.72, 0, 0.09, 0.05, "base"),
		p("S", 0.5, 0, 0, 0, 0.16, 0.05, "base"),
		p("V", 0.05, 0.74, 0.74, 0, 0.1, 0.05, "accent"),
		p("C", 0.22, 0.14, 0.14, 0, 0.08, -0.38, "shade", 0, 90, 0),
		p("C", 0.04, 0.18, 0.18, 0, 0.08, -0.48, "accent", 0, 90, 0),
	},
	WindUpTeeth = {
		p("B", 0.6, 0.14, 0.44, 0, 0.07, 0, "base"),
		p("B", 0.6, 0.14, 0.44, 0, 0.36, 0.06, "base", -20, 0, 0),
		p("B", 0.52, 0.08, 0.06, 0, 0.17, -0.18, "accent"),
		p("B", 0.52, 0.08, 0.06, 0, 0.27, -0.16, "accent", -20, 0, 0),
		pair("S", 0.14, 0, 0, 0.24, 0.05, -0.12, "shade"),
		p("C", 0.14, 0.05, 0.05, 0.37, 0.22, 0.1, "shade"),
		p("B", 0.03, 0.16, 0.06, 0.45, 0.22, 0.1, "shade"),
	},
	LuckyRock = {
		p("S", 0.58, 0, 0, 0, 0.25, 0, "base"),
		p("B", 0.42, 0.28, 0.4, 0.08, 0.17, 0.05, "shade", 10, 25, 5),
		p("B", 0.3, 0.24, 0.32, -0.16, 0.16, -0.04, "base", -8, 40, 0),
		pair("S", 0.12, 0, 0, 0.08, 0.36, -0.24, "accent"),
		pair("S", 0.05, 0, 0, 0.08, 0.36, -0.3, "ink"),
		p("B", 0.12, 0.03, 0.03, 0, 0.24, -0.29, "ink"),
	},
	---------------------------------------------------------------- seasonal
	Bauble = {
		p("S", 0.62, 0, 0, 0, 0.31, 0, "base"),
		p("V", 0.1, 0.18, 0.18, 0, 0.66, 0, "accent"),
		p("C", 0.03, 0.12, 0.12, 0, 0.76, 0, "ink", 0, 90, 0),
		p("V", 0.06, 0.64, 0.64, 0, 0.36, 0, "accent"),
		p("S", 0.12, 0, 0, -0.12, 0.44, -0.24, "accent"),
	},
	JingleBell = {
		p("S", 0.56, 0, 0, 0, 0.28, 0, "base"),
		p("B", 0.36, 0.04, 0.04, 0, 0.18, -0.25, "ink"),
		p("S", 0.08, 0, 0, 0, 0.14, -0.24, "ink"),
		p("V", 0.06, 0.58, 0.58, 0, 0.36, 0, "shade"),
		p("C", 0.05, 0.16, 0.16, 0, 0.6, 0, "accent", 0, 90, 0),
	},
	PartyHat = {
		p("V", 0.14, 0.6, 0.6, 0, 0.07, 0, "base"),
		p("V", 0.14, 0.48, 0.48, 0, 0.21, 0, "accent"),
		p("V", 0.14, 0.36, 0.36, 0, 0.35, 0, "base"),
		p("V", 0.14, 0.24, 0.24, 0, 0.49, 0, "accent"),
		p("V", 0.14, 0.13, 0.13, 0, 0.63, 0, "base"),
		p("S", 0.18, 0, 0, 0, 0.76, 0, "shade"),
		p("V", 0.04, 0.64, 0.64, 0, 0.02, 0, "shade"),
	},
	PaperCrown = {
		p("V", 0.24, 0.66, 0.66, 0, 0.12, 0, "base"),
		p("W", 0.06, 0.24, 0.2, 0, 0.36, -0.31, "base", 0, 180, 0),
		p("W", 0.06, 0.24, 0.2, 0.3, 0.36, -0.1, "base", 0, 108, 0),
		p("W", 0.06, 0.24, 0.2, -0.3, 0.36, -0.1, "base", 0, -108, 0),
		p("W", 0.06, 0.24, 0.2, 0.19, 0.36, 0.26, "base", 0, 36, 0),
		p("W", 0.06, 0.24, 0.2, -0.19, 0.36, 0.26, "base", 0, -36, 0),
		p("S", 0.08, 0, 0, 0, 0.14, -0.33, "accent"),
		pair("S", 0.07, 0, 0, 0.24, 0.14, -0.24, "shade"),
	},
	---------------------------------------------------------------- core: Common
	Sock = {
		p("B", 0.3, 0.6, 0.24, 0.12, 0.5, 0, "base"),
		p("B", 0.56, 0.24, 0.24, -0.04, 0.12, 0, "base"),
		p("B", 0.32, 0.1, 0.26, 0.12, 0.76, 0, "accent"),
		p("B", 0.32, 0.06, 0.26, 0.12, 0.6, 0, "accent"),
		p("B", 0.14, 0.26, 0.26, -0.29, 0.12, 0, "shade"),
		p("B", 0.12, 0.2, 0.26, 0.22, 0.14, 0, "shade"),
	},
	Mug = {
		p("V", 0.6, 0.52, 0.52, -0.06, 0.3, 0, "base"),
		p("V", 0.03, 0.42, 0.42, -0.06, 0.6, 0, "ink"),
		p("V", 0.06, 0.54, 0.54, -0.06, 0.48, 0, "accent"),
		p("B", 0.18, 0.06, 0.08, 0.26, 0.46, 0, "shade"),
		p("B", 0.06, 0.28, 0.08, 0.34, 0.32, 0, "shade"),
		p("B", 0.18, 0.06, 0.08, 0.26, 0.18, 0, "shade"),
	},
	PaperclipBox = {
		p("B", 0.7, 0.3, 0.46, 0, 0.15, 0, "base"),
		p("B", 0.74, 0.08, 0.5, 0, 0.32, 0, "accent"),
		p("B", 0.3, 0.12, 0.02, 0, 0.16, -0.24, "accent"),
		p("B", 0.34, 0.03, 0.03, 0, 0.38, -0.05, "shade"),
		p("B", 0.3, 0.03, 0.03, 0.02, 0.38, 0.05, "shade"),
		p("B", 0.03, 0.03, 0.13, 0.17, 0.38, 0, "shade"),
		p("B", 0.03, 0.03, 0.1, -0.15, 0.38, 0, "shade"),
	},
	---------------------------------------------------------------- core: Uncommon
	YoYo = {
		p("C", 0.16, 0.66, 0.66, -0.12, 0.4, 0, "base"),
		p("C", 0.16, 0.66, 0.66, 0.12, 0.4, 0, "base"),
		p("C", 0.1, 0.24, 0.24, 0, 0.4, 0, "accent"),
		p("C", 0.17, 0.34, 0.34, -0.12, 0.4, 0, "shade"),
		p("C", 0.17, 0.34, 0.34, 0.12, 0.4, 0, "shade"),
		p("V", 0.44, 0.03, 0.03, 0, 0.82, 0, "ink"),
		p("C", 0.03, 0.1, 0.1, 0, 1.0, 0, "ink", 0, 90, 0),
	},
	ModelCar = {
		p("B", 0.96, 0.16, 0.44, 0, 0.2, 0, "base"),
		p("B", 0.46, 0.18, 0.4, 0.04, 0.36, 0, "shade"),
		p("B", 0.04, 0.14, 0.36, -0.2, 0.36, 0, "accent", 0, 0, 30),
		p("W", 0.22, 0.1, 0.4, -0.38, 0.33, 0, "base", 0, -90, 0),
		p("B", 0.08, 0.04, 0.46, 0.46, 0.4, 0, "ink"),
		pair("B", 0.03, 0.12, 0.03, 0.18, 0.34, 0.42, "ink"),
		wheels(0.24, 0.32, 0.2),
	},
	SnowGlobe = {
		p("V", 0.18, 0.62, 0.62, 0, 0.09, 0, "shade"),
		p("V", 0.04, 0.66, 0.66, 0, 0.18, 0, "accent"),
		p("S", 0.62, 0, 0, 0, 0.5, 0, "base"),
		p("V", 0.1, 0.22, 0.22, 0, 0.3, 0, "accent"),
		p("V", 0.12, 0.16, 0.16, 0, 0.4, 0, "accent"),
		pair("S", 0.05, 0, 0, 0.12, 0.62, -0.22, "accent"),
		p("S", 0.05, 0, 0, 0, 0.72, -0.24, "accent"),
	},
	---------------------------------------------------------------- core: Rare
	Robot = {
		pair("B", 0.12, 0.24, 0.14, 0.09, 0.12, 0, "shade"),
		p("B", 0.42, 0.34, 0.28, 0, 0.4, 0, "base"),
		p("B", 0.18, 0.12, 0.02, 0, 0.42, -0.15, "accent"),
		pair("B", 0.08, 0.3, 0.1, 0.26, 0.42, 0, "shade"),
		p("B", 0.32, 0.26, 0.26, 0, 0.72, 0, "base"),
		pair("B", 0.08, 0.06, 0.02, 0.07, 0.74, -0.14, "accent"),
		p("B", 0.14, 0.03, 0.02, 0, 0.66, -0.14, "ink"),
		p("V", 0.14, 0.03, 0.03, 0, 0.92, 0, "ink"),
		p("S", 0.07, 0, 0, 0, 1.0, 0, "shade"),
	},
	Guitar = {
		p("C", 0.12, 0.46, 0.46, 0, 0.24, 0, "base", 0, 90, 0),
		p("C", 0.12, 0.36, 0.36, 0, 0.52, 0, "base", 0, 90, 0),
		p("C", 0.13, 0.14, 0.14, 0, 0.42, 0, "ink", 0, 90, 0),
		p("B", 0.07, 0.48, 0.05, 0, 0.82, -0.02, "shade"),
		p("B", 0.12, 0.14, 0.06, 0, 1.08, -0.02, "shade"),
		p("B", 0.03, 0.8, 0.02, 0, 0.68, -0.07, "accent"),
		p("B", 0.18, 0.04, 0.03, 0, 0.18, -0.07, "accent"),
	},
	TinyTree = {
		p("V", 0.2, 0.34, 0.34, 0, 0.1, 0, "shade"),
		p("V", 0.04, 0.38, 0.38, 0, 0.2, 0, "accent"),
		p("V", 0.12, 0.1, 0.1, 0, 0.26, 0, "ink"),
		p("V", 0.18, 0.62, 0.62, 0, 0.38, 0, "base"),
		p("V", 0.18, 0.46, 0.46, 0, 0.54, 0, "base"),
		p("V", 0.18, 0.3, 0.3, 0, 0.7, 0, "base"),
		p("B", 0.14, 0.14, 0.04, 0, 0.86, 0, "accent", 0, 0, 45),
		p("S", 0.07, 0, 0, 0.2, 0.42, -0.24, "accent"),
		p("S", 0.07, 0, 0, -0.14, 0.58, -0.18, "accent"),
	},
	---------------------------------------------------------------- core: Epic
	GoKart = {
		p("B", 0.9, 0.08, 0.5, 0, 0.14, 0, "shade"),
		p("B", 0.3, 0.26, 0.4, 0.14, 0.28, 0, "base"),
		p("B", 0.08, 0.3, 0.4, 0.3, 0.38, 0, "base"),
		p("W", 0.3, 0.12, 0.4, -0.28, 0.24, 0, "base", 0, -90, 0),
		p("V", 0.22, 0.04, 0.04, -0.1, 0.3, 0, "ink", 0, 0, -30),
		p("C", 0.04, 0.2, 0.2, -0.16, 0.42, 0, "ink", 0, 0, 60),
		p("B", 0.03, 0.12, 0.16, -0.43, 0.22, 0, "accent"),
		wheels(0.26, 0.32, 0.26),
	},
	ArcadeCabinet = {
		p("B", 0.5, 0.96, 0.44, 0, 0.48, 0, "base"),
		p("B", 0.52, 0.12, 0.46, 0, 0.92, -0.01, "accent"),
		p("B", 0.36, 0.28, 0.02, 0, 0.66, -0.23, "ink"),
		p("B", 0.3, 0.22, 0.02, 0, 0.66, -0.24, "accent"),
		p("W", 0.5, 0.1, 0.18, 0, 0.47, -0.3, "shade", 0, 180, 0),
		p("V", 0.1, 0.03, 0.03, -0.1, 0.55, -0.32, "ink"),
		p("S", 0.06, 0, 0, -0.1, 0.6, -0.32, "accent"),
		pair("S", 0.05, 0, 0, 0.08, 0.52, -0.32, "accent"),
	},
	PuppyCrate = {
		p("B", 0.84, 0.5, 0.56, 0, 0.25, 0, "base"),
		p("B", 0.86, 0.06, 0.06, 0, 0.12, -0.28, "shade"),
		p("B", 0.86, 0.06, 0.06, 0, 0.38, -0.28, "shade"),
		pair("B", 0.06, 0.52, 0.06, 0.4, 0.25, -0.28, "shade"),
		p("S", 0.34, 0, 0, 0.1, 0.6, -0.04, "accent"),
		pair("B", 0.1, 0.18, 0.06, 0.15, 0.68, 0, "shade", 0, 0, 20),
		p("S", 0.07, 0, 0, 0.1, 0.56, -0.2, "ink"),
		pair("S", 0.04, 0, 0, 0.06, 0.64, -0.17, "ink"),
	},
	---------------------------------------------------------------- core: Mythic
	GoldenGoose = {
		p("S", 0.56, 0, 0, 0.06, 0.3, 0, "base"),
		p("V", 0.3, 0.12, 0.12, -0.18, 0.6, 0, "base"),
		p("S", 0.22, 0, 0, -0.18, 0.8, 0, "base"),
		p("W", 0.14, 0.06, 0.12, -0.33, 0.78, 0, "shade", 0, 90, 0),
		p("W", 0.36, 0.22, 0.05, 0.12, 0.36, -0.27, "shade"),
		p("W", 0.36, 0.22, 0.05, 0.12, 0.36, 0.27, "shade"),
		p("S", 0.04, 0, 0, -0.24, 0.84, -0.08, "ink"),
		p("S", 0.04, 0, 0, -0.24, 0.84, 0.08, "ink"),
		p("S", 0.2, 0, 0, 0.36, 0.1, -0.24, "accent"),
	},
	Rocket = {
		p("V", 0.56, 0.32, 0.32, 0, 0.42, 0, "base"),
		p("V", 0.1, 0.26, 0.26, 0, 0.75, 0, "accent"),
		p("V", 0.1, 0.18, 0.18, 0, 0.85, 0, "base"),
		p("S", 0.1, 0, 0, 0, 0.94, 0, "accent"),
		p("C", 0.04, 0.14, 0.14, 0, 0.56, -0.16, "accent", 0, 90, 0),
		p("C", 0.05, 0.09, 0.09, 0, 0.56, -0.17, "ink", 0, 90, 0),
		pair("W", 0.04, 0.26, 0.16, 0.2, 0.17, 0, "shade", 0, 90, 0),
		p("W", 0.04, 0.26, 0.16, 0, 0.17, -0.2, "shade"),
		p("V", 0.08, 0.2, 0.2, 0, 0.1, 0, "accent"),
	},
	JacksBox = {
		p("B", 0.56, 0.5, 0.56, 0, 0.25, 0, "base"),
		p("B", 0.58, 0.05, 0.58, 0, 0.12, 0, "accent"),
		p("B", 0.56, 0.04, 0.3, 0, 0.58, 0.36, "shade", -60, 0, 0),
		p("V", 0.24, 0.12, 0.12, 0, 0.62, 0, "accent"),
		p("S", 0.28, 0, 0, 0, 0.86, 0, "accent"),
		pair("W", 0.06, 0.2, 0.14, 0.09, 1.04, 0, "base", 0, 0, -20),
		eyes(0.06, 0.9, -0.13, 0.05),
		p("C", 0.16, 0.05, 0.05, 0.36, 0.3, 0, "shade"),
		p("B", 0.03, 0.16, 0.05, 0.44, 0.36, 0, "shade"),
	},
	---------------------------------------------------------------- core: Secret
	BlankGiftTag = {
		p("B", 0.5, 0.72, 0.06, 0, 0.36, 0, "base", 0, 0, 6),
		p("W", 0.06, 0.16, 0.25, 0.13, 0.76, 0, "base", 0, 90, 6),
		p("W", 0.06, 0.16, 0.25, -0.11, 0.78, 0, "base", 0, -90, 6),
		p("C", 0.08, 0.1, 0.1, 0.0, 0.62, 0, "accent", 0, 90, 0),
		p("V", 0.3, 0.03, 0.03, 0.05, 0.84, -0.02, "accent", 0, 0, 20),
	},
	WaxSealedEnvelope = {
		p("B", 0.8, 0.54, 0.06, 0, 0.27, 0, "base"),
		p("W", 0.06, 0.26, 0.4, 0.2, 0.4, -0.03, "accent", 0, 90, 0),
		p("W", 0.06, 0.26, 0.4, -0.2, 0.4, -0.03, "accent", 0, -90, 0),
		p("C", 0.06, 0.2, 0.2, 0, 0.32, -0.06, "shade", 0, 90, 0),
		p("C", 0.07, 0.1, 0.1, 0, 0.32, -0.07, "ink", 0, 90, 0),
	},
	BrassKey = {
		p("C", 0.08, 0.36, 0.36, 0, 0.8, 0, "base", 0, 90, 0),
		p("C", 0.09, 0.16, 0.16, 0, 0.8, 0, "ink", 0, 90, 0),
		p("B", 0.08, 0.6, 0.08, 0, 0.36, 0, "base"),
		p("B", 0.14, 0.06, 0.08, 0.1, 0.12, 0, "shade"),
		p("B", 0.1, 0.06, 0.08, 0.08, 0.24, 0, "shade"),
		p("B", 0.12, 0.05, 0.09, 0, 0.6, 0, "accent"),
	},
}

---------------------------------------------------------------- build

local SHAPES = { B = Enum.PartType.Block, S = Enum.PartType.Ball, C = Enum.PartType.Cylinder, V = Enum.PartType.Cylinder }

local function flatten(list: { any }, out: { Piece })
	for _, item in list do
		if typeof(item[1]) == "string" then
			table.insert(out, item)
		else
			flatten(item, out)
		end
	end
	return out
end

local function colors(rarity: string, mutation: string?): { [string]: Color3 }
	local hex = Config.Rarity[rarity] and Config.Rarity[rarity].color
	local base = if hex then Color3.fromHex(hex) else Color3.fromHex(L.accent) -- Secret: swept by the caller
	if mutation == "Golden" then
		base = Color3.fromHex(L.golden.color)
	end
	local h, s, v = base:ToHSV()
	return {
		base = base,
		shade = Color3.fromHSV(h, s, v * (1 - L.shade)),
		accent = Color3.fromHex(L.accent),
		ink = Color3.fromHex(L.ink),
	}
end

function GiftModels.has(giftId: string): boolean
	return RECIPES[giftId] ~= nil
end

export type Options = {
	studs: number, -- the model's largest side before mutations
	mutation: string?,
	static: boolean?, -- true: every part anchored (shelves, viewports); false: welded to an anchored Root
}

-- Builds the toy for `giftId` in `rarity`. The Root part sits at the model's floor centre.
function GiftModels.build(giftId: string, rarity: string, options: Options): Model
	local model = Instance.new("Model")
	model.Name = giftId
	model:SetAttribute("GiftId", giftId)
	model:SetAttribute("Rarity", rarity)
	local scale = options.studs * (if options.mutation == "Giant" then L.giantScale else 1)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Size = Vector3.one * 0.2
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local final = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Gifts")
	local authored = final and final:FindFirstChild(giftId)
	if authored and authored:IsA("Model") then
		local copy = authored:Clone()
		copy:ScaleTo(scale)
		copy:PivotTo(CFrame.new())
		for _, child in copy:GetChildren() do
			child.Parent = model
		end
		copy:Destroy()
	else
		local palette = colors(rarity, options.mutation)
		local dots = Art.image("LootDots")
		for _, piece in flatten(RECIPES[giftId] or { p("B", 0.7, 0.7, 0.7, 0, 0.35, 0, "base") }, {}) do
			local shape, sx, sy, sz, x, y, z, color, rx, ry, rz = table.unpack(piece)
			local part: BasePart
			if shape == "W" then
				part = Instance.new("WedgePart")
				part.Size = Vector3.new(sx, sy, sz) * scale
			else
				local block = Instance.new("Part")
				block.Shape = SHAPES[shape]
				block.Size = if shape == "S" then Vector3.one * sx * scale else Vector3.new(sx, sy, sz) * scale
				part = block
			end
			part.Name = color
			local cf = CFrame.new(x * scale, y * scale, z * scale) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
			if shape == "V" then
				cf *= CFrame.Angles(0, 0, math.rad(90)) -- a cylinder runs along x; stand it up
			end
			part.CFrame = cf
			part.Color = palette[color]
			part.Material = Enum.Material.SmoothPlastic
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			if (color == "base" or color == "shade") and options.mutation == "Golden" then
				part.Reflectance = L.golden.reflectance
			end
			if color == "base" then
				part:SetAttribute("LootBase", true)
				if dots and shape == "B" then
					for _, face in { Enum.NormalId.Front, Enum.NormalId.Top } do
						local texture = Instance.new("Texture")
						texture.Texture = dots
						texture.Face = face
						texture.StudsPerTileU, texture.StudsPerTileV = 1, 1
						texture.Transparency = 0.5
						texture.Parent = part
					end
				end
			end
			part.Parent = model
		end
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			if options.static then
				part.Anchored = true
			else
				part.Anchored = false
				part.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	return model
end

-- Every part tagged LootBase (Secret items sweep these through the hue).
function GiftModels.baseParts(model: Model): { BasePart }
	local out = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("LootBase") then
			table.insert(out, part)
		end
	end
	return out
end

return GiftModels
