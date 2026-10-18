--[=[
	LootScreens (client, part of HUD)
	Owns: the loot feed (a small card per side-gift as it lands), the core reveal banner (a gift tag
	over a rarity burst, top of screen so the gift rising from the box stays clear), the wipe banner,
	the bank screen (cards for what went on the shelf; sell or replace what did not fit; Done) and the
	shelf screen (slot grid of gift pictures, a detail card, replace mode) with its right-edge button.
	Must never: Compute a value it displays. Outcomes, gems and the shelf come from LootEvent and
	ShelfState; choices go up as BankChoice and the server decides.
	Read first: src/client/HUD/README.md
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Gifts = require(ReplicatedStorage.Shared.Gifts.Gifts)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Widgets = require(script.Parent.Widgets)

local LootScreens = {}

local C = Widgets.C
local make, text, list = Widgets.make, Widgets.text, Widgets.list
local player = Players.LocalPlayer
local gui: ScreenGui
local toast: (text: string) -> ()
local bankChoice: RemoteEvent
local feed: Frame
local feedCount = 0
local banner = {} :: { frame: Frame, burst: Frame, rays: { Frame }, label: TextLabel, chip: TextLabel, sub: TextLabel, token: number }
local bank = {} :: { frame: Frame, gems: TextLabel, list: ScrollingFrame }
local shelfScreen = {} :: { frame: Frame, title: TextLabel, strip: Frame, grid: ScrollingFrame, detail: Frame }
local shelf = { capacity = Config.Shelf.startSlots, items = {}, gems = 0, indexCount = 0 }
local pending = {}
local replacing: number? = nil -- pending index waiting for a shelf slot to replace
local selected: number? = nil -- slotIndex shown in the detail card
local secret: { [GuiObject]: boolean } = {}

local OUTCOME = { placed = "On your shelf", stacked = "Stacked", full = "Shelf full" }

local function rarityColor(rarity: string): Color3
	local hex = Config.Rarity[rarity] and Config.Rarity[rarity].color
	return if hex then Color3.fromHex(hex) else C.cream
end

-- Rarity colour on `property`. Secret is never a fixed colour: an animated hue sweep (Art bible A).
local function paint(object: GuiObject, rarity: string, property: string)
	object:SetAttribute("SecretProperty", property)
	if rarity == "Secret" then
		secret[object] = true
	else
		secret[object] = nil;
		(object :: any)[property] = rarityColor(rarity)
	end
end

local function isCore(giftId: string): boolean
	return Gifts.byId[giftId] ~= nil and Gifts.byId[giftId].kind == "Core"
end

local function leftText(parent: Instance, value: string, size: UDim2, position: UDim2, tier: string?, ink: boolean?): TextLabel
	local label = text(parent, value, size, nil, tier, ink)
	label.Position = position
	label.TextXAlignment = Enum.TextXAlignment.Left
	return label
end

local function popIn(object: GuiObject)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = object
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

---------------------------------------------------------------- feed and banners

-- One feed card: the gift's picture, its name, and a line in its rarity colour.
local function feedCard(giftId: string, rarity: string, line: string)
	feedCount += 1
	local card = make("Frame", { Parent = feed, Name = "FeedCard", LayoutOrder = -feedCount, Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.woodDark, BackgroundTransparency = 0.12 })
	Widgets.stroke(card, C.woodDark, 2)
	paint(make("Frame", { Parent = card, Name = "Rarity", Size = UDim2.new(0, 6, 1, -12), Position = UDim2.fromOffset(6, 6), Corner = UDim.new(0.5, 0) }), rarity, "BackgroundColor3")
	Widgets.gift(card, giftId, rarity, nil, UDim2.fromOffset(44, 44), UDim2.fromOffset(15, 3))
	leftText(card, Gifts.displayName(giftId), UDim2.new(1, -72, 0.52, 0), UDim2.new(0, 64, 0.06, 0), "S")
	paint(leftText(card, line, UDim2.new(1, -72, 0.38, 0), UDim2.new(0, 64, 0.56, 0), "S"), rarity, "TextColor3")
	popIn(card)
	local cards = {}
	for _, child in feed:GetChildren() do
		if child.Name == "FeedCard" then
			table.insert(cards, child)
		end
	end
	if #cards > 5 then -- keep the feed short; the oldest card goes first
		table.sort(cards, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		cards[1]:Destroy()
	end
	task.delay(Config.HUD.feedSeconds, function()
		card:Destroy()
	end)
end

local function buildBanner()
	local frame = make("Frame", { Parent = gui, Name = "CoreBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.12), Size = UDim2.fromScale(0.5, 0.2), BackgroundTransparency = 1, Visible = false, ZIndex = 8, Corner = false })
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize, limit.MaxSize = Vector2.new(300, 110), Vector2.new(600, 170)
	limit.Parent = frame
	-- A slow-turning burst of rays in the rarity colour behind the tag.
	local burst = make("Frame", { Parent = frame, Name = "Burst", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.6, 1.6), BackgroundTransparency = 1, Corner = false })
	Widgets.aspect(burst, 1)
	local rays = {}
	for k = 0, 7 do
		local ray = make("Frame", { Parent = burst, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.13, 1), Rotation = k * 22.5, BackgroundTransparency = 0.45, Corner = UDim.new(0.5, 0) })
		table.insert(rays, ray)
	end
	local tag, label = Widgets.tag(frame, "", UDim2.fromScale(0.86, 0.58), UDim2.fromScale(0.07, 0.08))
	label.TextXAlignment = Enum.TextXAlignment.Center
	tag.ZIndex = 2
	local chip = Widgets.chip(frame, "", C.woodDark, UDim2.fromScale(0.32, 0.26))
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.fromScale(0.5, 0.7)
	local sub = text(frame, "", UDim2.fromScale(0.9, 0.24), nil, "M")
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.fromScale(0.5, 0.72)
	banner = { frame = frame, burst = burst, rays = rays, label = label, chip = chip, sub = sub, token = 0 }
end

local function showBanner(title: string, rarity: string?, subtitle: string?, seconds: number)
	banner.token += 1
	local token = banner.token
	banner.label.Text = title
	banner.chip.Visible = rarity ~= nil
	banner.sub.Visible = subtitle ~= nil
	banner.sub.Text = subtitle or ""
	for _, ray in banner.rays do
		if rarity then
			paint(ray, rarity, "BackgroundColor3")
		else
			secret[ray] = nil
			ray.BackgroundColor3 = Color3.fromHex(Config.HUD.nightTimerColor)
		end
	end
	if rarity then
		banner.chip.Text = rarity
		paint(banner.chip, rarity, "BackgroundColor3")
	end
	banner.frame.Visible = true
	popIn(banner.frame)
	task.delay(seconds, function()
		if banner.token == token then
			banner.frame.Visible = false
		end
	end)
end

---------------------------------------------------------------- shelf screen

local function showDetail(item: any?)
	local detail = shelfScreen.detail
	Widgets.clear(detail)
	if not item then
		text(detail, "Tap a gift to see it here", UDim2.new(0.9, 0, 0.3, 0), nil, "M", true).Position = UDim2.fromScale(0.05, 0.35)
		return
	end
	local picture = Widgets.gift(detail, item.giftId, item.rarity, item.mutation, UDim2.fromScale(0.86, 0.5))
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.fromScale(0.5, 0.03)
	local name = text(detail, Gifts.displayName(item.giftId, item.mutation), UDim2.new(0.92, 0, 0.14, 0), nil, "M", true)
	name.Position = UDim2.fromScale(0.04, 0.54)
	local chip = Widgets.chip(detail, item.rarity, C.woodDark, UDim2.fromScale(0.6, 0.1))
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.fromScale(0.5, 0.7)
	paint(chip, item.rarity, "BackgroundColor3")
	local slots = Config.Rarity[item.rarity].shelfSlots
	local lines = { `Takes {slots} slot{if slots == 1 then "" else "s"}` }
	if item.count > 1 then
		table.insert(lines, `×{item.count} stacked`)
	end
	if isCore(item.giftId) then
		table.insert(lines, "★ Core gift")
	end
	local info = text(detail, table.concat(lines, "  ·  "), UDim2.new(0.92, 0, 0.12, 0), nil, "S", true)
	info.Position = UDim2.fromScale(0.04, 0.84)
	info.TextColor3 = C.woodMid
end

local function refreshShelf()
	local grid = shelfScreen.grid
	Widgets.clear(grid)
	Widgets.clear(shelfScreen.strip)
	local used = 0
	local starts = {}
	for _, item in shelf.items do
		starts[item.slotIndex] = item
		used += Config.Rarity[item.rarity].shelfSlots
	end
	if replacing then
		shelfScreen.title.Text = "Replace which?"
		local note = Widgets.chip(shelfScreen.strip, "Tap a shelf gift to swap it out (it is sold)", C.action, UDim2.fromScale(1, 1))
		note.TextXAlignment = Enum.TextXAlignment.Center
	else
		shelfScreen.title.Text = "Shelf"
		for i, stat in { { "Shelf", `{used} / {shelf.capacity}`, "IconShelf" }, { "Gems", tostring(shelf.gems), "IconGems" }, { "Star", `Index {shelf.indexCount}`, nil } } do
			local pill = make("Frame", { Parent = shelfScreen.strip, LayoutOrder = i, Size = UDim2.new(0.32, -6, 1, 0), BackgroundColor3 = C.woodDark, BackgroundTransparency = 0.25, Corner = UDim.new(0.5, 0) })
			Widgets.icon(pill, stat[1], UDim2.new(0, 36, 1, -6), UDim2.fromOffset(6, 3), stat[3])
			leftText(pill, stat[2], UDim2.new(1, -52, 0.8, 0), UDim2.new(0, 46, 0.1, 0), "M")
		end
	end

	local slot, order = 1, 0
	local shown = nil
	while slot <= shelf.capacity do
		order += 1
		local item = starts[slot]
		if item then
			local slots = Config.Rarity[item.rarity].shelfSlots
			local tile = Widgets.card(grid, UDim2.new(0.25 * slots, -8, 0, 100), order)
			tile.Name = "Tile"
			if selected == item.slotIndex then
				shown = item
				tile:FindFirstChildOfClass("UIStroke").Color = C.action
				tile:FindFirstChildOfClass("UIStroke").Thickness = 4
			end
			paint(make("Frame", { Parent = tile, Name = "Rarity", Size = UDim2.new(1, -8, 0, 7), Position = UDim2.new(0, 4, 1, -11), Corner = UDim.new(0.5, 0) }), item.rarity, "BackgroundColor3")
			local picture = Widgets.gift(tile, item.giftId, item.rarity, item.mutation, UDim2.new(1, -8, 0, 62))
			picture.AnchorPoint = Vector2.new(0.5, 0)
			picture.Position = UDim2.new(0.5, 0, 0, 3)
			local name = text(tile, Gifts.displayName(item.giftId, item.mutation), UDim2.new(1, -8, 0, 22), nil, "S", true)
			name.Position = UDim2.new(0, 4, 1, -36)
			name:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = Config.HUD.tileTextMax
			if isCore(item.giftId) then
				Widgets.chip(tile, "★", C.woodDark, UDim2.fromOffset(28, 24)).Position = UDim2.fromOffset(-6, -6)
			end
			if item.count > 1 then
				local count = Widgets.chip(tile, `×{item.count}`, C.woodDark, UDim2.fromOffset(40, 24))
				count.AnchorPoint = Vector2.new(1, 0)
				count.Position = UDim2.new(1, 6, 0, -6)
			end
			local tap = make("TextButton", { Parent = tile, Name = "Tap", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 4, Corner = false })
			tap.Activated:Connect(function()
				if replacing then
					bankChoice:FireServer("Replace", replacing, item.slotIndex)
					replacing = nil
					bank.frame.Visible = true
				else
					selected = item.slotIndex
					refreshShelf()
				end
			end)
			slot += slots
		else
			make("Frame", { Parent = grid, Name = "Empty", LayoutOrder = order, Size = UDim2.new(0.25, -8, 0, 100), BackgroundColor3 = C.woodDark, BackgroundTransparency = 0.6 })
			slot += 1
		end
	end
	showDetail(shown)
end

local function buildShelf()
	local frame, title, body, close = Widgets.screen(gui, "ShelfScreen", "Shelf")
	shelfScreen.frame, shelfScreen.title = frame, title
	close.Activated:Connect(function()
		if replacing then -- back to the bank without replacing anything
			replacing = nil
			bank.frame.Visible = true
		end
	end)
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			refreshShelf()
		end
	end)
	shelfScreen.strip = make("Frame", { Parent = body, Name = "Strip", Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Corner = false })
	list(shelfScreen.strip, true, false, 8).HorizontalAlignment = Enum.HorizontalAlignment.Left
	shelfScreen.grid = Widgets.scroll(body, UDim2.new(0.66, -6, 1, -54), UDim2.fromOffset(0, 54))
	shelfScreen.grid.Name = "Grid"
	local layout = list(shelfScreen.grid, true, true, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	shelfScreen.detail = Widgets.card(body, UDim2.new(0.34, -6, 1, -54))
	shelfScreen.detail.Name = "Detail"
	shelfScreen.detail.Position = UDim2.new(0.66, 6, 0, 54)

	-- The Shelf button on the right edge, key F (Table 13).
	local function toggle()
		replacing = nil
		frame.Visible = not frame.Visible
	end
	Widgets.sideButton(gui, "Shelf", "Shelf", Config.UI.keys.Shelf, 1, toggle)
	Widgets.onKey(Config.UI.keys.Shelf, toggle)
end

---------------------------------------------------------------- bank screen

local function refreshPending()
	for _, child in bank.list:GetChildren() do
		if child:GetAttribute("Pending") then
			child:Destroy()
		end
	end
	if #pending == 0 then
		return
	end
	local header = text(bank.list, "Did not fit: sell it, or swap it for a shelf gift", UDim2.new(1, -8, 0, 30), 900, "M")
	header:SetAttribute("Pending", true)
	for i, item in pending do
		local buttons = {}
		if item.sellGems then
			table.insert(buttons, { text = `Sell · {item.sellGems}`, tap = function()
				bankChoice:FireServer("Sell", i)
			end, style = "wood" })
		end
		table.insert(buttons, { text = "Replace…", tap = function()
			replacing = i
			shelfScreen.frame.Visible = true
		end })
		local card = Widgets.rowCard(bank.list, 1000 + i, function(slot)
			Widgets.gift(slot, item.giftId, item.rarity, item.mutation, UDim2.fromScale(1, 1))
		end, Gifts.displayName(item.giftId, item.mutation), item.rarity, buttons)
		card:SetAttribute("Pending", true)
	end
end

local function showBank(event: any)
	Widgets.clear(bank.list)
	bank.gems.Text = `+{event.gems} gems`
	text(bank.list, "This run's gifts", UDim2.new(1, -8, 0, 30), 1, "M")
	local grid = make("Frame", { Parent = bank.list, Name = "Gifts", LayoutOrder = 2, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Corner = false })
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.235, 0, 0, 156)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for i, item in event.items do
		local card = Widgets.card(grid, UDim2.new(), i)
		local picture = Widgets.gift(card, item.giftId, item.rarity, item.mutation, UDim2.new(1, -12, 0, 76))
		picture.AnchorPoint = Vector2.new(0.5, 0)
		picture.Position = UDim2.new(0.5, 0, 0, 4)
		local name = text(card, Gifts.displayName(item.giftId, item.mutation), UDim2.new(1, -10, 0, 24), nil, "S", true)
		name.Position = UDim2.fromOffset(5, 80)
		local rarity = Widgets.chip(card, item.rarity, C.woodDark, UDim2.new(0.8, 0, 0, 20))
		rarity.AnchorPoint = Vector2.new(0.5, 0)
		rarity.Position = UDim2.new(0.5, 0, 0, 106)
		paint(rarity, item.rarity, "BackgroundColor3")
		local outcome = text(card, OUTCOME[item.outcome] or "", UDim2.new(1, -10, 0, 20), nil, "S", true)
		outcome.Position = UDim2.fromOffset(5, 130)
		outcome.TextColor3 = if item.outcome == "full" then C.close else C.woodMid
		if item.kind == "Core" then
			Widgets.chip(card, "★", C.woodDark, UDim2.fromOffset(28, 24)).Position = UDim2.fromOffset(-6, -6)
		end
	end
	pending = event.pending
	refreshPending()
	bank.frame.Visible = true
end

local function buildBank()
	local frame, _, body, close = Widgets.screen(gui, "BankScreen", "Banked!")
	bank.frame = frame
	close.Activated:Connect(function()
		bankChoice:FireServer("Done") -- closing the bank is the same as Done
	end)
	local strip = make("Frame", { Parent = body, Name = "Gems", Size = UDim2.new(0.5, 0, 0, 46), BackgroundColor3 = C.woodDark, BackgroundTransparency = 0.25, Corner = UDim.new(0.5, 0) })
	Widgets.icon(strip, "Gems", UDim2.new(0, 40, 1, -6), UDim2.fromOffset(6, 3), "IconGems")
	bank.gems = leftText(strip, "", UDim2.new(1, -60, 0.8, 0), UDim2.new(0, 52, 0.1, 0), "M")
	bank.list = Widgets.scroll(body, UDim2.new(1, 0, 1, -122), UDim2.fromOffset(0, 52))
	bank.list.Name = "List"
	list(bank.list, false, false, 8)
	local doneHolder = make("Frame", { Parent = body, Name = "Done", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(0.34, 0, 0, 58), BackgroundTransparency = 1, Corner = false })
	Widgets.button(doneHolder, "Done", UDim2.fromScale(1, 1), function()
		bankChoice:FireServer("Done")
		frame.Visible = false
	end)
end

---------------------------------------------------------------- init

function LootScreens.init(screen: ScreenGui, showToast: (text: string) -> ())
	gui = screen
	toast = showToast
	bankChoice = Remotes.get("BankChoice")

	feed = make("Frame", { Parent = gui, Name = "LootFeed", Position = UDim2.new(0, 14, 0.14, 0), Size = UDim2.fromScale(0.26, 0.42), BackgroundTransparency = 1, Corner = false })
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(320, 340)
	limit.Parent = feed
	list(feed, false, false, 6)
	buildBanner()
	buildShelf()
	buildBank()

	Remotes.get("LootEvent").OnClientEvent:Connect(function(event)
		if event.type == "Side" then
			local who = if event.toUserId == player.UserId then `+{event.cash} cash` else (event.to or "")
			feedCard(event.giftId, event.rarity, `{event.rarity} · {who}`)
		elseif event.type == "Core" then
			showBanner(`★ {Gifts.displayName(event.giftId, event.mutation)}`, event.rarity, nil, Config.Loot.coreRevealSeconds + Config.Loot.revealBeatSeconds)
		elseif event.type == "Bank" then
			showBank(event)
		elseif event.type == "BankPending" then
			pending = event.pending
			refreshPending()
		elseif event.type == "Refused" then
			toast(event.reason)
		elseif event.type == "Lost" then
			feedCard(event.giftId, event.rarity, `Lost · {event.rarity}`)
		elseif event.type == "Wipe" then
			-- Everyone went down: the run bag is gone; the Index kept what was seen, the shelf is untouched.
			showBanner("Wiped!", nil, "The run bag is lost. Your shelf is safe.", event.seconds or Config.Night.wipeScreenSeconds)
		end
	end)
	Remotes.get("ShelfState").OnClientEvent:Connect(function(state)
		shelf = state
		if shelfScreen.frame.Visible then
			refreshShelf()
		end
	end)
	Remotes.get("RunState").OnClientEvent:Connect(function(state)
		if state ~= "Bank" then
			bank.frame.Visible = false
			replacing = nil
		end
	end)
	RunService.RenderStepped:Connect(function()
		if banner.frame.Visible then
			banner.burst.Rotation = (os.clock() * 18) % 360
		end
		if next(secret) == nil then
			return
		end
		local color = Color3.fromHSV((os.clock() / Config.Greybox.secretHueSeconds) % 1, 0.6, 1)
		for object in secret do
			if object.Parent then
				(object :: any)[object:GetAttribute("SecretProperty")] = color
			else
				secret[object] = nil
			end
		end
	end)
end

return LootScreens
