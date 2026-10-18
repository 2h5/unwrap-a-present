--[=[
	MetaScreens (client, part of HUD)
	Owns: the Shop (Robux passes and gem packs as illustrated cards), Classes (a large focused screen:
	the chosen class big on the left, all six as cards, Spin) and Rewards (daily and group rewards,
	streak, permanent track, shelf slots, prestige, next run's tier, vault) screens, their right-edge
	buttons and keys (B, C, R), and the Rejoin button.
	Must never: Compute a value it displays. Costs, waits and what is allowed come in ProfileState;
	every tap goes up as EconomyRequest / ClassSpin, or a Roblox purchase prompt. Prices and odds are
	live text from Config, never baked into a picture.
	Read first: src/client/HUD/README.md
]=]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local Gifts = require(ReplicatedStorage.Shared.Gifts.Gifts)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Widgets = require(script.Parent.Widgets)

local MetaScreens = {}

local C = Widgets.C
local make, text = Widgets.make, Widgets.text
local player = Players.LocalPlayer
local state: any = nil
local stateAt = 0 -- os.clock() when the last ProfileState arrived (for the daily countdown)
local screens: { [string]: { frame: Frame, title: TextLabel, body: Frame, fill: () -> () } } = {}
local request: RemoteEvent
local spin: RemoteEvent
local shopTab = "Passes"
local viewing: string? = nil -- the class shown big on the Classes screen
local dailyLine: TextLabel? = nil

local TIER_NAMES = { Birthday = "Birthday", Christmas = "Christmas", Wedding = "Wedding", ThePackage = "The Package" }
local KIT_NAMES = { Scissors = "scissors", BoxCutter = "box cutter", Chainsaw = "chainsaw", Flashlight = "a flashlight" }

-- What each class does (PLAN-TABLES.txt Table 8), with its numbers read from Config.
local PASSIVE = {
	Kid = function(c)
		return `+{c.cashBonus * 100}% cash`
	end,
	Wrapper = function()
		return "Tape panels take grade 0 (hands)"
	end,
	Sprinter = function(c)
		return `+{c.walkSpeedBonus} walk speed; Jack lunges {math.round((1 - c.jackLungeScale) * 100)}% slower at you`
	end,
	Collector = function(c)
		return `+{c.lidSideGifts} side-gift on every box lid; +{math.round(c.gemBonus * 100)}% gems`
	end,
	Heir = function()
		return "Your core gift rolls twice; you keep the better"
	end,
	KrampusKid = function()
		return "Immune to Krampus; Naughty does not rise from your steals"
	end,
}

-- What each pass does (Table 10), with its numbers read from Config.
local PASS_TEXT = {
	DoubleCash = function(p)
		return `{p.cashScale}x cash in every run`
	end,
	BigShelf = function()
		return `{Config.Shelf.passSlotsMax} shelf slots`
	end,
	ToolKeeper = function()
		return "Keep tools when down; start with scissors"
	end,
	Lucky = function()
		return "Side-gifts roll twice for your party (never the core)"
	end,
}

local function ask(kind: string, arg: any?)
	request:FireServer(kind, arg)
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

local function rarityColor(rarity: string): Color3
	local hex = Config.Rarity[rarity] and Config.Rarity[rarity].color
	return if hex then Color3.fromHex(hex) else C.woodDark -- Legendary (classes only) has no Table 12 colour
end

local function startsWith(class: any): string
	local kit = {}
	for _, tool in class.startTools or {} do
		table.insert(kit, KIT_NAMES[tool] or tool)
	end
	for _, upgrade in class.startUpgrades or {} do
		table.insert(kit, KIT_NAMES[upgrade] or upgrade)
	end
	if class.startCash then
		table.insert(kit, `{class.startCash} cash`)
	end
	return if #kit > 0 then `Starts with {table.concat(kit, ", ")}` else "Starts with nothing"
end

local function paragraph(parent: Instance, value: string, size: UDim2, position: UDim2, tier: string?): TextLabel
	local label = text(parent, value, size, nil, tier, true)
	label.Position = position
	label.TextWrapped = true
	return label
end

local function button(parent: Instance, value: string, size: UDim2, position: UDim2, on: boolean, tap: () -> (), style: string?): TextButton
	local holder = make("Frame", { Parent = parent, Size = size, Position = position, BackgroundTransparency = 1, Corner = false })
	local b = Widgets.button(holder, value, UDim2.fromScale(1, 1), tap, style)
	Widgets.enable(b, on)
	return b
end

---------------------------------------------------------------- shop

local function shopCard(row: Instance, order: number, icon: string, slot: string, title: string, detail: string, price: string, on: boolean, tap: () -> ())
	local card = Widgets.card(row, UDim2.new(0.25, -10, 1, -6), order)
	Widgets.aspect(card, 0.72)
	local art = make("Frame", { Parent = card, Name = "Art", Size = UDim2.new(1, -12, 0.4, 0), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = C.cream, Corner = UDim.new(0, 10) })
	Widgets.stroke(art, C.woodDark, 2)
	local picture = Widgets.icon(art, icon, UDim2.fromScale(0.9, 0.9), nil, slot)
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	local name = text(card, title, UDim2.new(1, -12, 0.12, 0), nil, "M", true)
	name.Position = UDim2.new(0, 6, 0.42, 4)
	local line = paragraph(card, detail, UDim2.new(1, -14, 0.24, 0), UDim2.new(0, 7, 0.55, 2), "S")
	line.TextColor3 = C.woodMid
	button(card, price, UDim2.new(1, -16, 0.16, 0), UDim2.new(0, 8, 0.82, -4), on, tap)
end

local function fillShop()
	local s = screens.Shop
	Widgets.clear(s.body)
	s.title.Text = "Shop"
	local tabs = make("Frame", { Parent = s.body, Name = "Tabs", Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Corner = false })
	Widgets.list(tabs, true, false, 10).HorizontalAlignment = Enum.HorizontalAlignment.Left
	for i, tab in { "Passes", "Gems" } do
		local holder = make("Frame", { Parent = tabs, LayoutOrder = i, Size = UDim2.new(0, 150, 1, 0), BackgroundTransparency = 1, Corner = false })
		Widgets.button(holder, tab, UDim2.fromScale(1, 1), function()
			shopTab = tab
			fillShop()
		end, if shopTab == tab then "action" else "wood")
	end
	-- One row of tall cards that fits a phone without scrolling (four passes, or three gem packs).
	local row = make("Frame", { Parent = s.body, Name = "Cards", Size = UDim2.new(1, 0, 1, -58), Position = UDim2.fromOffset(0, 58), BackgroundTransparency = 1, Corner = false })
	Widgets.list(row, true, false, 10)
	if shopTab == "Passes" then
		for i, name in Config.GamepassOrder do
			local pass = Config.Gamepasses[name]
			local owned = state.passes[name]
			shopCard(row, i, name, `Pass{name}`, pass.name, PASS_TEXT[name](pass), if owned then "Owned" elseif pass.id == 0 then "Soon" else `R$ {pass.robux}`, not owned and pass.id ~= 0, function()
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end)
		end
	else
		for i, name in Config.DevProductOrder do
			local product = Config.DevProducts[name]
			shopCard(row, i, name, `Gems{name}`, `{product.gems} gems`, "Spins, shelf slots, the track", if product.id == 0 then "Soon" else `R$ {product.robux}`, product.id ~= 0, function()
				MarketplaceService:PromptProductPurchase(player, product.id)
			end)
		end
	end
end

---------------------------------------------------------------- classes

local function fillClasses()
	local s = screens.Classes
	Widgets.clear(s.body)
	s.title.Text = "Classes"
	local id = viewing or state.activeClass or Config.ClassOrder[1]
	local class = Config.Classes[id]
	local owned = table.find(state.classes, id) ~= nil

	-- The focused class, big, on the left.
	local focus = Widgets.card(s.body, UDim2.new(0.42, -6, 1, 0))
	focus.Name = "Focus"
	local art = make("Frame", { Parent = focus, Name = "Art", Size = UDim2.new(1, -16, 0.42, 0), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.cream, Corner = UDim.new(0, 12) })
	Widgets.stroke(art, C.woodDark, 2)
	local picture = Widgets.icon(art, `Class{id}`, UDim2.fromScale(0.9, 0.9), nil, `Class{id}`)
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	if not owned then
		picture.Visible = false
		text(art, "?", UDim2.fromScale(0.5, 0.8), nil, "L", true).Position = UDim2.fromScale(0.25, 0.1)
	end
	local name = text(focus, class.name, UDim2.new(1, -16, 0.1, 0), nil, "L", true)
	name.Position = UDim2.new(0, 8, 0.44, 4)
	local chip = Widgets.chip(focus, `{class.rarity} · {class.odds}%`, rarityColor(class.rarity), UDim2.new(0.6, 0, 0.07, 0))
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 0.55, 4)
	paragraph(focus, PASSIVE[id](class), UDim2.new(1, -20, 0.14, 0), UDim2.new(0, 10, 0.64, 0), "M")
	local kit = paragraph(focus, startsWith(class), UDim2.new(1, -20, 0.07, 0), UDim2.new(0, 10, 0.78, 0), "S")
	kit.TextColor3 = C.woodMid
	local picked = state.activeClass == id
	button(focus, if not owned then "Not found yet" elseif picked then "Picked" else "Pick", UDim2.new(0.7, 0, 0.11, 0), UDim2.new(0.15, 0, 0.87, 0), owned and not picked, function()
		ask("ClassPick", id)
	end)

	-- All six as cards, top right.
	local gridFrame = make("Frame", { Parent = s.body, Name = "All", Size = UDim2.new(0.58, -6, 1, -74), Position = UDim2.new(0.42, 6, 0, 0), BackgroundTransparency = 1, Corner = false })
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / 3, -8, 0.5, -8)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridFrame
	for i, cid in Config.ClassOrder do
		local c = Config.Classes[cid]
		local has = table.find(state.classes, cid) ~= nil
		local card = Widgets.card(gridFrame, UDim2.new(), i)
		if cid == id then
			local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
			stroke.Color, stroke.Thickness = C.action, 4
		end
		local icon = Widgets.icon(card, `Class{cid}`, UDim2.fromScale(0.62, 0.5), nil, `Class{cid}`)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.fromScale(0.5, 0.05)
		local label = text(card, c.name, UDim2.new(1, -8, 0.18, 0), nil, "S", true)
		label.Position = UDim2.new(0, 4, 0.56, 0)
		local odds = Widgets.chip(card, `{c.odds}%`, rarityColor(c.rarity), UDim2.new(0.6, 0, 0.18, 0))
		odds.AnchorPoint = Vector2.new(0.5, 0)
		odds.Position = UDim2.fromScale(0.5, 0.77)
		if not has then
			local shade = make("Frame", { Parent = card, Name = "Locked", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.woodDark, BackgroundTransparency = 0.45, ZIndex = 3 })
			text(shade, "?", UDim2.fromScale(0.5, 0.5), nil, "L").Position = UDim2.fromScale(0.25, 0.08)
		elseif state.activeClass == cid then
			Widgets.chip(card, "✓", C.action, UDim2.fromOffset(28, 24)).Position = UDim2.fromOffset(-6, -6)
		end
		local tap = make("TextButton", { Parent = card, Name = "Tap", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 4, Corner = false })
		tap.Activated:Connect(function()
			viewing = cid
			fillClasses()
		end)
	end

	-- Spin, bottom right.
	local bar = make("Frame", { Parent = s.body, Name = "Spin", Size = UDim2.new(0.58, -6, 0, 64), Position = UDim2.new(0.42, 6, 1, -64), BackgroundColor3 = C.woodDark, BackgroundTransparency = 0.3 })
	Widgets.icon(bar, "Gems", UDim2.new(0, 40, 0, 40), UDim2.fromOffset(10, 12), "IconGems")
	local gems = text(bar, `{state.gems}`, UDim2.new(0.3, -56, 0.7, 0), nil, "M")
	gems.Position = UDim2.new(0, 56, 0.15, 0)
	gems.TextXAlignment = Enum.TextXAlignment.Left
	button(bar, `Spin · {state.spinCost} gems`, UDim2.new(0.6, 0, 1, -12), UDim2.new(0.4, -6, 0, 6), state.gems >= state.spinCost, function()
		spin:FireServer()
	end)
	if state.runClass and state.runClass ~= state.activeClass then
		local note = Widgets.chip(s.body, "Your pick applies from the next run", C.woodDark, UDim2.new(0.5, 0, 0, 26))
		note.AnchorPoint = Vector2.new(1, 0)
		note.Position = UDim2.new(1, 0, 0, -30)
	end
end

---------------------------------------------------------------- rewards

local function pips(card: Frame, filled: number, total: number)
	local row = make("Frame", { Parent = card, Name = "Pips", AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.new(0.42, 0, 0, 26), Position = UDim2.new(1, -12, 0.5, 0), BackgroundTransparency = 1, Corner = false })
	Widgets.list(row, true, false, 6).HorizontalAlignment = Enum.HorizontalAlignment.Right
	for k = 1, total do
		local pip = make("Frame", { Parent = row, LayoutOrder = k, Size = UDim2.fromOffset(24, 24), BackgroundColor3 = if k <= filled then C.action else C.parchment, Corner = UDim.new(0.5, 0) })
		Widgets.stroke(pip, C.woodDark, 2)
	end
end

local function progress(card: Frame, fraction: number)
	local track = make("Frame", { Parent = card, Name = "Progress", Size = UDim2.new(0.4, 0, 0, 10), Position = UDim2.new(0, 76, 1, -14), BackgroundColor3 = C.parchment, Corner = UDim.new(0.5, 0) })
	Widgets.stroke(track, C.woodDark, 1)
	make("Frame", { Parent = track, Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BackgroundColor3 = C.action, Corner = UDim.new(0.5, 0) })
end

local function fillRewards()
	local s = screens.Rewards
	Widgets.clear(s.body)
	s.title.Text = "Rewards"
	local scroll = Widgets.scroll(s.body, UDim2.fromScale(1, 1))
	Widgets.list(scroll, false, false, 8)
	local order = 0
	local function card(icon, title, detail, buttons)
		order += 1
		return Widgets.rowCard(scroll, order, icon, title, detail, buttons or {})
	end

	local wait = state.dailyWait - (os.clock() - stateAt)
	local _, line = card("Daily", "Daily reward", if wait <= 0 then `{Config.Gems.daily} gems, ready now` else `{Config.Gems.daily} gems in {clock(wait)}`, {
		{ text = "Claim", on = wait <= 0, tap = function()
			ask("DailyClaim")
		end },
	})
	dailyLine = line
	card("Group", "Group reward", `{Config.Gems.groupOneTime} gems, once, for joining the group`, {
		{ text = if state.groupClaimed then "Claimed" else "Claim", on = state.groupReady and not state.groupClaimed, tap = function()
			ask("GroupClaim")
		end },
	})
	local streak = card("Streak", `Login streak · day {state.streakDays}`, `+{Config.Gems.streakPerDay} gems a day in a row`)
	for _, label in streak:GetChildren() do
		if label:IsA("TextLabel") then -- leave the right side to the pips
			label.Size = UDim2.new(0.55, -82, label.Size.Y.Scale, 0)
		end
	end
	pips(streak, math.min(state.streakDays, Config.Gems.streakCapDays), Config.Gems.streakCapDays)
	card("Pockets", `Pockets · level {state.pockets}`, `+{Config.PermanentTrack.Pockets.startCashPerLevel} starting cash a level`, {
		{ text = if state.pocketsCost then `{state.pocketsCost} gems` else "Max", on = state.pocketsCost ~= nil and state.gems >= state.pocketsCost, tap = function()
			ask("TrackBuy", "pockets")
		end },
	})
	card("NightEyes", `Night Eyes · level {state.nightEyes}`, "A brighter Night for you", {
		{ text = if state.nightEyesCost then `{state.nightEyesCost} gems` else "Max", on = state.nightEyesCost ~= nil and state.gems >= state.nightEyesCost, tap = function()
			ask("TrackBuy", "nightEyes")
		end },
	})
	card("BigShelf", `Shelf · {state.shelfSlots} slots`, `+4 slots for {Config.Shelf.gemsPer4Slots} gems, up to {Config.Shelf.gemSlotsMax}`, {
		{ text = if state.shelfSlotsCost then `+4 · {state.shelfSlotsCost}` else "Max", on = state.shelfSlotsCost ~= nil and state.gems >= state.shelfSlotsCost, tap = function()
			ask("ShelfSlots")
		end },
	})
	local tierName = TIER_NAMES[Config.Tiers.order[state.tier]] or ""
	local prestige = card("Prestige", `Tier: {tierName}`, if state.prestigeNeed then `{state.tierRuns} / {state.prestigeNeed} runs to prestige` else "Last tier for now", {
		{ text = "Prestige", on = state.canPrestige, tap = function()
			ask("Prestige")
		end },
	})
	if state.prestigeNeed then
		progress(prestige, state.tierRuns / math.max(state.prestigeNeed, 1))
	end

	-- Next run's tier: one chip per unlocked tier.
	order += 1
	local nextCard = Widgets.card(scroll, UDim2.new(1, -8, 0, 74), order)
	Widgets.icon(nextCard, "Tier", UDim2.fromOffset(56, 56), UDim2.fromOffset(10, 9))
	local nextTitle = text(nextCard, "Next run", UDim2.new(0.25, -76, 0.6, 0), nil, "M", true)
	nextTitle.Position = UDim2.new(0, 76, 0.2, 0)
	nextTitle.TextXAlignment = Enum.TextXAlignment.Left
	local chips = make("Frame", { Parent = nextCard, Size = UDim2.new(0.75, -12, 0, 52), Position = UDim2.new(0.25, 0, 0.5, -26), BackgroundTransparency = 1, Corner = false })
	Widgets.list(chips, true, false, 6).HorizontalAlignment = Enum.HorizontalAlignment.Right
	for t = 1, state.tier do
		local holder = make("Frame", { Parent = chips, LayoutOrder = t, Size = UDim2.new(0.24, -6, 1, 0), BackgroundTransparency = 1, Corner = false })
		local b = Widgets.button(holder, TIER_NAMES[Config.Tiers.order[t]] or "", UDim2.fromScale(1, 1), function()
			ask("TierPick", t)
		end, if state.nextTier == t then "action" else "wood")
		b:SetAttribute("Off", state.nextTier == t)
	end

	card("Vault", `Vault · {#state.vault} items`, `{state.vaultReclaimsLeft} reclaims left this run`)
	for i, item in state.vault do
		card(function(slot)
			Widgets.gift(slot, item.giftId, item.rarity, item.mutation, UDim2.fromScale(1, 1))
		end, `{Gifts.displayName(item.giftId, item.mutation)}{if item.count > 1 then ` ×{item.count}` else ""}`, item.rarity, {
			{ text = "Reclaim", on = state.vaultReclaimsLeft > 0, tap = function()
				ask("VaultReclaim", i)
			end },
		})
	end
end

---------------------------------------------------------------- init

function MetaScreens.init(gui: ScreenGui, toast: (text: string) -> ())
	request = Remotes.get("EconomyRequest")
	spin = Remotes.get("ClassSpin")
	local specs = {
		{ name = "Shop", fill = fillShop, order = 2 },
		{ name = "Classes", fill = fillClasses, order = 3 },
		{ name = "Rewards", fill = fillRewards, order = 4 },
	}
	for _, spec in specs do
		local frame, title, body = Widgets.screen(gui, spec.name)
		local s = { frame = frame, title = title, body = body, fill = spec.fill }
		screens[spec.name] = s
		frame:GetPropertyChangedSignal("Visible"):Connect(function()
			if frame.Visible and state then
				if spec.name == "Classes" then
					viewing = nil -- open on the class you have picked
				end
				s.fill()
			end
		end)
		local function toggle()
			frame.Visible = state ~= nil and not frame.Visible
		end
		Widgets.sideButton(gui, spec.name, spec.name, Config.UI.keys[spec.name], spec.order, toggle)
		Widgets.onKey(Config.UI.keys[spec.name], toggle)
	end

	-- Rejoin a run left mid-way (N10): shown in the lobby while the 2-minute window is open.
	local rejoinEndsAt: number? = nil
	local rejoinHolder = make("Frame", { Parent = gui, Name = "Rejoin", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.03), Size = UDim2.fromScale(0.3, 0.085), BackgroundTransparency = 1, Visible = false, Corner = false })
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize, limit.MaxSize = Vector2.new(220, 48), Vector2.new(360, 70)
	limit.Parent = rejoinHolder
	local rejoinButton = Widgets.button(rejoinHolder, "", UDim2.fromScale(1, 1), function()
		Remotes.get("LobbyRequest"):FireServer("Rejoin")
	end)
	task.spawn(function()
		while true do
			local left = if rejoinEndsAt then math.ceil(rejoinEndsAt - os.clock()) else 0
			rejoinHolder.Visible = left > 0
			rejoinButton.Text = string.format("Rejoin run (%d:%02d)", left // 60, left % 60)
			-- The daily countdown ticks while Rewards is open; at zero the card refills with Claim on.
			local line = dailyLine
			if state and line and line.Parent and screens.Rewards.frame.Visible then
				local wait = state.dailyWait - (os.clock() - stateAt)
				if wait <= 0 and not line.Text:find("ready") then
					fillRewards()
				elseif wait > 0 then
					line.Text = `{Config.Gems.daily} gems in {clock(wait)}`
				end
			end
			task.wait(0.5)
		end
	end)

	Remotes.get("ProfileState").OnClientEvent:Connect(function(new)
		local before = state and state.classes or {}
		state = new
		stateAt = os.clock()
		rejoinEndsAt = if new.rejoinSecondsLeft then os.clock() + new.rejoinSecondsLeft else nil
		if new.message then
			toast(new.message)
		end
		for _, id in new.classes do
			if not table.find(before, id) and #before > 0 then
				viewing = id -- a spin found a new class: show it big
			end
		end
		for _, s in screens do
			if s.frame.Visible then
				s.fill()
			end
		end
	end)
end

-- Opens one screen ("Shop", "Classes", "Rewards"); the others close (lobby booths and the vault crate).
function MetaScreens.open(name: string)
	if state and screens[name] then
		screens[name].frame.Visible = true
	end
end

-- Gems for the HUD, or nil before the profile loads.
function MetaScreens.gems(): number?
	return state and state.gems
end

return MetaScreens
