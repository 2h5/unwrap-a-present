--[=[
	HUD (client system)
	Owns: Cash, depth, Night timer, bank, shop, classes, rewards screens.
	Must never: Compute a value it displays. Cash, tools and depth are attributes the server sets.
	This file: the toast for refusals and the run room shop (cash, seven item cards), opened from the
	counter's prompt; Buy sends ShopBuy. Cash, depth, tool, party, prompt: Status. Loot feed, reveal,
	bank, shelf: LootScreens. Classes, Rewards, Robux shop: MetaScreens. Night look and sound:
	NightView. Gift pop, reveal shaft, Secret sweep: LootView. The wooden kit: Widgets, Icons.
	Touch-first (invariant 3): every control is a large tap target; nothing needs a keyboard.
	Read first: src/client/HUD/README.md
]=]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local LootScreens = require(script.Parent.LootScreens)
local LootView = require(script.Parent.LootView)
local MetaScreens = require(script.Parent.MetaScreens)
local NightView = require(script.Parent.NightView)
local Status = require(script.Parent.Status)
local Widgets = require(script.Parent.Widgets)

local HUD = {}

local C = Widgets.C
local S = Config.Shop

-- Shop order and labels follow PLAN-TABLES.txt Table 7; each effect line reads its number from Config.
local SHOP = {
	{ item = "Scissors", label = "Scissors", tool = true, effect = "Grade 1 tool" },
	{ item = "BoxCutter", label = "Box cutter", tool = true, effect = "Grade 2 tool" },
	{ item = "Chainsaw", label = "Chainsaw", tool = true, effect = "Grade 3 tool" },
	{ item = "GripTape", label = "Grip tape", effect = `Panel time −{math.round((1 - S.GripTape.panelTimeScale) * 100)}%` },
	{ item = "Flashlight", label = "Flashlight", effect = `Night light {math.round(Config.Night.lightingScale * 100)}% → {math.round(S.Flashlight.nightLightingScale * 100)}%` },
	{ item = "SpareLid", label = "Spare lid", effect = "One extra shutter prop" },
	{ item = "LuckyBow", label = "Lucky bow", effect = `Next layer +{S.LuckyBow.extraSideGifts} side-gift` },
}

local player = Players.LocalPlayer
local gui: ScreenGui
local toastFrame: Frame
local toastLabel: TextLabel
local shopFrame: Frame
local buttons: { [string]: TextButton } = {}
local toastToken = 0

local function present(): Instance?
	return workspace:FindFirstChild("Present")
end

local function attributeFor(entry): string
	return if entry.tool then `Tool_{entry.item}` else `Upgrade_{entry.item}`
end

local function refresh()
	Status.refresh()
	local cash = player:GetAttribute("Cash") or 0
	local p = present()
	local tier = p and p:GetAttribute("TierNumber") or 1
	for _, entry in SHOP do
		local button = buttons[entry.item]
		local info = Config.Shop[entry.item]
		local owned = player:GetAttribute(attributeFor(entry)) ~= nil -- a used lucky bow stays bought
		local locked = info.minTier ~= nil and tier < info.minTier
		button.Text = if owned then "Owned" elseif locked then `Tier {info.minTier}` else `{info.cost} cash`
		Widgets.enable(button, not owned and not locked and cash >= info.cost)
	end
end

-- This player's own hold for the tool's hold ring (TearInput): progress and seconds, or nil when it ends.
function HUD.hold(progress: number?, seconds: number?)
	Status.hold(progress, seconds)
end

-- Shows a short message on a parchment card near the top of the screen (refusals like "Needs scissors").
function HUD.toast(text: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastFrame.Visible = true
	task.delay(Config.HUD.toastSeconds, function()
		if toastToken == token then
			toastFrame.Visible = false
		end
	end)
end

local function buildToast()
	toastFrame = Widgets.card(gui, UDim2.fromScale(0.4, 0.07))
	toastFrame.Name = "Toast"
	toastFrame.AnchorPoint = Vector2.new(0.5, 0)
	toastFrame.Position = UDim2.fromScale(0.5, 0.3)
	toastFrame.Visible = false
	toastFrame.ZIndex = 20
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize, limit.MaxSize = Vector2.new(240, 40), Vector2.new(480, 60)
	limit.Parent = toastFrame
	toastLabel = Widgets.text(toastFrame, "", UDim2.new(1, -16, 1, -8), nil, "M", true)
	toastLabel.Position = UDim2.fromOffset(8, 4)
	toastLabel.ZIndex = 21
end

-- The run room shop: seven cards in two rows (picture, name, effect, a cash price button).
local function buildShop()
	local frame, _, body = Widgets.screen(gui, "RunShop", "Shop")
	shopFrame = frame
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -10, 0.5, -10)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = body

	local buy = Remotes.get("ShopBuy")
	for i, entry in SHOP do
		local card = Widgets.card(body, UDim2.new(), i)
		card.Name = entry.item
		local art = Widgets.icon(card, entry.item, UDim2.new(1, -12, 0.4, 0), nil, `Shop{entry.item}`)
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Position = UDim2.new(0.5, 0, 0, 6)
		local name = Widgets.text(card, entry.label, UDim2.new(1, -10, 0.14, 0), nil, "M", true)
		name.Position = UDim2.new(0, 5, 0.42, 2)
		local effect = Widgets.text(card, entry.effect, UDim2.new(1, -10, 0.13, 0), nil, "S", true)
		effect.Position = UDim2.new(0, 5, 0.57, 2)
		effect.TextColor3 = C.woodMid
		local holder = Widgets.make("Frame", { Parent = card, Size = UDim2.new(1, -14, 0.22, 0), Position = UDim2.new(0, 7, 0.75, -2), BackgroundTransparency = 1, Corner = false })
		buttons[entry.item] = Widgets.button(holder, "", UDim2.fromScale(1, 1), function()
			buy:FireServer(entry.item)
		end)
	end
end

function HUD.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	Status.init(gui)
	buildToast()
	buildShop()
	LootScreens.init(gui, HUD.toast)
	MetaScreens.init(gui, HUD.toast)
	NightView.init()
	LootView.init()
	Remotes.get("RunState").OnClientEvent:Connect(function(state)
		if state ~= "Unwrapping" and state ~= "Night" then
			shopFrame.Visible = false
		end
	end)

	local BOOTHS = { RewardsPrompt = "Rewards", ClassesPrompt = "Classes", StorePrompt = "Shop" }
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" then
			shopFrame.Visible = not shopFrame.Visible
			refresh()
		elseif BOOTHS[prompt.Name] then
			MetaScreens.open(BOOTHS[prompt.Name])
		elseif prompt.Name == "VaultPrompt" and prompt:GetAttribute("OwnerId") == player.UserId then
			MetaScreens.open("Rewards") -- the vault list is on the Rewards screen
		end
	end)

	player.AttributeChanged:Connect(refresh)
	local function watchPresent(p: Instance)
		if p.Name == "Present" then
			p.AttributeChanged:Connect(refresh)
			refresh()
		end
	end
	workspace.ChildAdded:Connect(watchPresent)
	local p = present()
	if p then
		watchPresent(p)
	end
	refresh()
end

return HUD
