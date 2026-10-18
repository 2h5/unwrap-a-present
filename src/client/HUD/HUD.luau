--[=[
	HUD (client system)
	Owns: Cash, depth, Night timer, bank, shop, classes, rewards screens.
	Must never: Compute a value it displays. Cash, tools and depth are attributes the server sets.
	This file: the toast for refusals and the run room shop (cash), opened from the counter's prompt;
	Buy sends ShopBuy. Cash, depth, tool, party, prompt: Status. Loot feed, reveal, bank, shelf:
	LootScreens. Classes, Rewards, Robux shop: MetaScreens.
	Touch-first (invariant 3): every control is a large tap target; nothing needs a keyboard.
	Read first: src/client/HUD/README.md
]=]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local LootScreens = require(script.Parent.LootScreens)
local MetaScreens = require(script.Parent.MetaScreens)
local Status = require(script.Parent.Status)

local HUD = {}

-- Shop order and labels follow PLAN-TABLES.txt Table 7.
local SHOP = {
	{ item = "Scissors", label = "Scissors", tool = true },
	{ item = "BoxCutter", label = "Box cutter", tool = true },
	{ item = "Chainsaw", label = "Chainsaw", tool = true },
	{ item = "GripTape", label = "Grip tape" },
	{ item = "Flashlight", label = "Flashlight" },
	{ item = "SpareLid", label = "Spare lid" },
	{ item = "LuckyBow", label = "Lucky bow" },
}

local player = Players.LocalPlayer
local gui: ScreenGui
local toastLabel: TextLabel
local shopFrame: Frame
local buttons: { [string]: TextButton } = {}
local toastToken = 0

local function label(parent: Instance, name: string, size: UDim2, pos: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos
	l.BackgroundColor3 = Color3.fromHex(Config.HUD.barColor)
	l.BackgroundTransparency = 0.25
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.Parent = parent
	local corner = Instance.new("UICorner")
	corner.Parent = l
	return l
end

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
		button.Text = if owned then `{entry.label} · owned` elseif locked then `{entry.label} · tier {info.minTier}` else `{entry.label} · {info.cost}`
		local can = not owned and not locked and cash >= info.cost
		button.AutoButtonColor = can
		button.BackgroundTransparency = if can then 0 else 0.5
	end
end

-- This player's own hold for the tool's hold ring (TearInput): progress and seconds, or nil when it ends.
function HUD.hold(progress: number?, seconds: number?)
	Status.hold(progress, seconds)
end

-- Shows a short message near the top of the screen (refusals like "Needs scissors").
function HUD.toast(text: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(Config.HUD.toastSeconds, function()
		if toastToken == token then
			toastLabel.Visible = false
		end
	end)
end

local function buildShop()
	shopFrame = Instance.new("Frame")
	shopFrame.Name = "RunShop"
	shopFrame.Size = UDim2.fromScale(0.5, 0.7)
	shopFrame.Position = UDim2.fromScale(0.25, 0.15)
	shopFrame.BackgroundColor3 = Color3.fromHex(Config.HUD.shopColor)
	shopFrame.Visible = false
	shopFrame.Parent = gui
	Instance.new("UICorner").Parent = shopFrame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0.02, 0)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = shopFrame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.03, 0)
	pad.Parent = shopFrame

	local buy = Remotes.get("ShopBuy")
	for i, entry in SHOP do
		local button = Instance.new("TextButton")
		button.Name = entry.item
		button.LayoutOrder = i
		button.Size = UDim2.fromScale(0.9, 0.1)
		button.BackgroundColor3 = Color3.fromHex(Config.HUD.buttonColor)
		button.TextScaled = true
		button.Font = Enum.Font.GothamBold
		button.Parent = shopFrame
		Instance.new("UICorner").Parent = button
		button.Activated:Connect(function()
			buy:FireServer(entry.item)
		end)
		buttons[entry.item] = button
	end
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.LayoutOrder = #SHOP + 1
	close.Size = UDim2.fromScale(0.5, 0.1)
	close.Text = "Close"
	close.TextScaled = true
	close.Font = Enum.Font.GothamBold
	close.Parent = shopFrame
	Instance.new("UICorner").Parent = close
	close.Activated:Connect(function()
		shopFrame.Visible = false
	end)
end

function HUD.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	Status.init(gui)
	toastLabel = label(gui, "Toast", UDim2.fromScale(0.4, 0.06), UDim2.fromScale(0.3, 0.32))
	toastLabel.Visible = false
	buildShop()
	LootScreens.init(gui, HUD.toast)
	MetaScreens.init(gui, HUD.toast)
	Remotes.get("RunState").OnClientEvent:Connect(function(state)
		if state ~= "Unwrapping" and state ~= "Night" then
			shopFrame.Visible = false
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" then
			shopFrame.Visible = not shopFrame.Visible
			refresh()
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
