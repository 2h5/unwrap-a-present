--[=[
	LootScreens (client, part of HUD)
	Owns: the loot feed (side-gifts as they land), the core reveal banner, the bank screen (what went
	on the shelf, sell or replace what did not fit, Done) and the shelf screen (Shelf button).
	Must never: Compute a value it displays. Outcomes, gems and the shelf come from LootEvent and
	ShelfState; choices go up as BankChoice and the server decides.
	Read first: src/client/HUD/README.md
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Gifts = require(ReplicatedStorage.Shared.Gifts.Gifts)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Widgets = require(script.Parent.Widgets)

local LootScreens = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local toast: (text: string) -> ()
local feed: Frame
local banner: TextLabel
local bankFrame: Frame
local bankList: ScrollingFrame
local bankTitle: TextLabel
local shelfFrame: Frame
local shelfGrid: Frame
local shelfTitle: TextLabel
local shelf = { capacity = Config.Shelf.startSlots, items = {}, gems = 0, indexCount = 0 }
local pending = {}
local replacing: number? = nil -- pending index waiting for a shelf slot to replace
local bankChoice: RemoteEvent
local secretLabels: { [GuiObject]: boolean } = {}

local DARK = Widgets.DARK

local function rarityColor(rarity: string): Color3
	local hex = Config.Rarity[rarity] and Config.Rarity[rarity].color
	return if hex then Color3.fromHex(hex) else Color3.new(1, 1, 1)
end

-- Secret is never a fixed color: an animated hue sweep (Art bible A).
local function paint(object: GuiObject, rarity: string, property: string)
	if rarity == "Secret" then
		secretLabels[object] = true
		object.Destroying:Connect(function()
			secretLabels[object] = nil
		end)
		object:SetAttribute("SecretProperty", property)
	else
		(object :: any)[property] = rarityColor(rarity)
	end
end

local make, text, button, list = Widgets.make, Widgets.text, Widgets.button, Widgets.list

---------------------------------------------------------------- feed and banner

local function feedLine(value: string, rarity: string)
	local line = text(feed, value, UDim2.new(1, 0, 0, 28))
	line.BackgroundTransparency = 0.3
	line.BackgroundColor3 = DARK
	paint(line, rarity, "TextColor3")
	task.delay(Config.HUD.feedSeconds, function()
		line:Destroy()
	end)
end

local function showBanner(giftId: string, rarity: string, mutation: string?)
	banner.Text = `{Gifts.displayName(giftId, mutation)}\n{rarity}`
	banner.TextColor3 = rarityColor(rarity)
	secretLabels[banner] = if rarity == "Secret" then true else nil
	banner:SetAttribute("SecretProperty", "TextColor3")
	banner.Visible = true
	task.delay(Config.Loot.coreRevealSeconds + Config.Loot.revealBeatSeconds, function()
		banner.Visible = false
		secretLabels[banner] = nil
	end)
end

---------------------------------------------------------------- shelf screen

local function refreshShelf()
	for _, child in shelfGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local used = 0
	local starts = {}
	for _, item in shelf.items do
		starts[item.slotIndex] = item
		used += Config.Rarity[item.rarity].shelfSlots
	end
	shelfTitle.Text = if replacing
		then "Tap a shelf item to replace (it is sold)"
		else `Shelf {used} / {shelf.capacity}   ·   Gems {shelf.gems}   ·   Index {shelf.indexCount}`
	local cell = 1 / 6
	local slot, order = 1, 0
	while slot <= shelf.capacity do
		order += 1
		local item = starts[slot]
		if item then
			local slots = Config.Rarity[item.rarity].shelfSlots
			local core = Gifts.byId[item.giftId] and Gifts.byId[item.giftId].kind == "Core"
			local label = `{if core then "★ " else ""}{Gifts.displayName(item.giftId, item.mutation)}{if item.count > 1 then ` ×{item.count}` else ""}`
			local tile = button(shelfGrid, label, UDim2.new(cell * slots, -6, cell, -6), function()
				if replacing then
					bankChoice:FireServer("Replace", replacing, item.slotIndex)
					replacing = nil
					shelfFrame.Visible = false
					bankFrame.Visible = true
				end
			end)
			tile.LayoutOrder = order
			local cap = Instance.new("UITextSizeConstraint")
			cap.MaxTextSize = Config.HUD.tileTextMax
			cap.Parent = tile
			tile.TextColor3 = DARK
			paint(tile, item.rarity, "BackgroundColor3")
			slot += slots
		else
			local empty = make("Frame", { Parent = shelfGrid, Size = UDim2.new(cell, -6, cell, -6), LayoutOrder = order })
			empty.BackgroundColor3 = DARK
			empty.BackgroundTransparency = 0.6
			slot += 1
		end
	end
end

local function buildShelf()
	shelfFrame = make("Frame", {
		Parent = gui,
		Name = "ShelfScreen",
		Size = UDim2.fromScale(0.6, 0.7),
		Position = UDim2.fromScale(0.2, 0.15),
		BackgroundColor3 = Color3.fromHex(Config.HUD.shopColor),
		Visible = false,
	})
	shelfFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if shelfFrame.Visible then
			refreshShelf()
		end
	end)
	list(shelfFrame)
	shelfTitle = text(shelfFrame, "Shelf", UDim2.fromScale(0.95, 0.1), 1)
	shelfGrid = make("Frame", { Parent = shelfFrame, Size = UDim2.fromScale(0.95, 0.72), LayoutOrder = 2, BackgroundTransparency = 1 })
	list(shelfGrid, true, true)
	local close = button(shelfFrame, "Close", UDim2.fromScale(0.4, 0.1), function()
		shelfFrame.Visible = false
		if replacing then
			replacing = nil
			bankFrame.Visible = true
		end
	end)
	close.LayoutOrder = 3
	-- The Shelf button on the right edge (Art bible B: big round icon buttons on the right).
	local open = button(gui, "Shelf", UDim2.fromScale(0.1, 0.08), function()
		replacing = nil
		shelfFrame.Visible = not shelfFrame.Visible
	end)
	open.Name = "ShelfButton"
	open.Position = UDim2.fromScale(0.88, 0.27)
end

---------------------------------------------------------------- bank screen

local OUTCOME = { placed = "on your shelf", stacked = "stacked", full = "shelf full" }

local function refreshPending()
	for _, child in bankList:GetChildren() do
		if child:GetAttribute("Pending") then
			child:Destroy()
		end
	end
	for i, item in pending do
		local row = make("Frame", { Parent = bankList, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1000 + i, BackgroundTransparency = 1 })
		row:SetAttribute("Pending", true)
		list(row, true)
		local name = text(row, `{Gifts.displayName(item.giftId, item.mutation)} ({item.rarity})`, UDim2.new(0.45, 0, 1, 0))
		paint(name, item.rarity, "TextColor3")
		if item.sellGems then
			button(row, `Sell · {item.sellGems} gems`, UDim2.new(0.25, 0, 1, 0), function()
				bankChoice:FireServer("Sell", i)
			end)
		end
		button(row, "Replace…", UDim2.new(0.25, 0, 1, 0), function()
			replacing = i
			bankFrame.Visible = false
			if shelfFrame.Visible then
				refreshShelf()
			end
			shelfFrame.Visible = true
		end)
	end
end

local function showBank(event: any)
	for _, child in bankList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	bankTitle.Text = `Banked!   +{event.gems} gems`
	for i, item in event.items do
		local core = if item.kind == "Core" then "★ " else ""
		local line = text(bankList, `{core}{Gifts.displayName(item.giftId, item.mutation)} ({item.rarity}) · {OUTCOME[item.outcome]}`, UDim2.new(1, 0, 0, 30), i)
		paint(line, item.rarity, "TextColor3")
	end
	pending = event.pending
	refreshPending()
	bankFrame.Visible = true
end

local function buildBank()
	bankFrame = make("Frame", {
		Parent = gui,
		Name = "BankScreen",
		Size = UDim2.fromScale(0.6, 0.75),
		Position = UDim2.fromScale(0.2, 0.12),
		BackgroundColor3 = DARK,
		Visible = false,
	})
	list(bankFrame)
	bankTitle = text(bankFrame, "Banked!", UDim2.fromScale(0.95, 0.1), 1)
	bankList = make("ScrollingFrame", {
		Parent = bankFrame,
		Size = UDim2.fromScale(0.95, 0.72),
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
	})
	list(bankList)
	local done = button(bankFrame, "Done", UDim2.fromScale(0.4, 0.1), function()
		bankChoice:FireServer("Done")
		bankFrame.Visible = false
	end)
	done.LayoutOrder = 3
end

---------------------------------------------------------------- init

function LootScreens.init(screen: ScreenGui, showToast: (text: string) -> ())
	gui = screen
	toast = showToast
	bankChoice = Remotes.get("BankChoice")

	feed = make("Frame", { Parent = gui, Name = "LootFeed", Size = UDim2.fromScale(0.3, 0.4), Position = UDim2.fromScale(0.01, 0.2), BackgroundTransparency = 1 })
	list(feed)
	banner = text(gui, "", UDim2.fromScale(0.6, 0.18), nil)
	banner.Name = "CoreBanner"
	banner.Position = UDim2.fromScale(0.2, 0.2)
	banner.Visible = false
	banner.TextStrokeTransparency = 0
	buildShelf()
	buildBank()

	Remotes.get("LootEvent").OnClientEvent:Connect(function(event)
		if event.type == "Side" then
			local who = if event.toUserId == player.UserId then `+{event.cash} cash` else (event.to or "")
			feedLine(`{Gifts.displayName(event.giftId)} · {event.rarity} · {who}`, event.rarity)
		elseif event.type == "Core" then
			showBanner(event.giftId, event.rarity, event.mutation)
		elseif event.type == "Bank" then
			showBank(event)
		elseif event.type == "BankPending" then
			pending = event.pending
			refreshPending()
		elseif event.type == "Refused" then
			toast(event.reason)
		end
	end)
	Remotes.get("ShelfState").OnClientEvent:Connect(function(state)
		shelf = state
		if shelfFrame.Visible then
			refreshShelf()
		end
	end)
	Remotes.get("RunState").OnClientEvent:Connect(function(state)
		if state ~= "Bank" then
			bankFrame.Visible = false
			replacing = nil
		end
	end)
	RunService.RenderStepped:Connect(function()
		if next(secretLabels) == nil then
			return
		end
		local color = Color3.fromHSV((os.clock() / Config.Greybox.secretHueSeconds) % 1, 0.6, 1)
		for object in secretLabels do
			(object :: any)[object:GetAttribute("SecretProperty")] = color
		end
	end)
end

return LootScreens
