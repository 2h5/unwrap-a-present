--[=[
	MetaScreens (client, part of HUD)
	Owns: the Classes, Rewards and Shop (Robux) screens and their right-edge buttons (Art bible B:
	Shelf, Shop, Classes, Rewards). Rewards holds the daily and group rewards, the streak, the
	permanent track, shelf slots, prestige, the next run's tier and the vault.
	Must never: Compute a value it displays. Costs, waits and what is allowed come in ProfileState;
	every tap goes up as EconomyRequest / ClassSpin, or a Roblox purchase prompt.
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

local player = Players.LocalPlayer
local state: any = nil
local screens: { [string]: { frame: Frame, title: TextLabel, body: ScrollingFrame, fill: () -> () } } = {}
local request: RemoteEvent
local spin: RemoteEvent

local function ask(kind: string, arg: any?)
	request:FireServer(kind, arg)
end

local function clock(seconds: number): string
	return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

---------------------------------------------------------------- screens

local function fillClasses()
	local s = screens.Classes
	Widgets.clear(s.body)
	s.title.Text = `Classes   ·   Gems {state.gems}`
	Widgets.row(s.body, 1, `Spin for a class · {state.spinCost} gems`, {
		{ text = "Spin", on = state.gems >= state.spinCost, tap = function()
			spin:FireServer()
		end },
	})
	for i, id in Config.ClassOrder do
		local class = Config.Classes[id]
		local owned = table.find(state.classes, id) ~= nil
		local label = `{class.name} ({class.rarity}, {class.odds}%)`
		local buttons = {}
		if owned then
			local picked = state.activeClass == id
			table.insert(buttons, { text = if picked then "Picked" else "Pick", on = not picked, tap = function()
				ask("ClassPick", id)
			end })
		end
		Widgets.row(s.body, 1 + i, if owned then label else `{label} · not owned`, buttons)
	end
	if state.runClass and state.runClass ~= state.activeClass then
		Widgets.text(s.body, "Your pick applies from the next run.", UDim2.new(1, 0, 0, 30), 99)
	end
end

local function fillRewards()
	local s = screens.Rewards
	Widgets.clear(s.body)
	s.title.Text = `Rewards   ·   Gems {state.gems}`
	local order = 0
	local function row(label, buttons)
		order += 1
		Widgets.row(s.body, order, label, buttons or {})
	end
	local ready = state.dailyWait <= 0
	row(if ready then `Daily: {Config.Gems.daily} gems` else `Daily in {clock(state.dailyWait)}`, {
		{ text = "Claim", on = ready, tap = function()
			ask("DailyClaim")
		end },
	})
	row(`Group: {Config.Gems.groupOneTime} gems, once`, {
		{ text = if state.groupClaimed then "Claimed" else "Claim", on = state.groupReady and not state.groupClaimed, tap = function()
			ask("GroupClaim")
		end },
	})
	row(`Login streak: day {state.streakDays}`)
	row(`Pockets lv {state.pockets}: +{Config.PermanentTrack.Pockets.startCashPerLevel} start cash a level`, {
		{ text = if state.pocketsCost then `{state.pocketsCost} gems` else "Max", on = state.pocketsCost ~= nil and state.gems >= state.pocketsCost, tap = function()
			ask("TrackBuy", "pockets")
		end },
	})
	row(`Night Eyes lv {state.nightEyes}: brighter Night`, {
		{ text = if state.nightEyesCost then `{state.nightEyesCost} gems` else "Max", on = state.nightEyesCost ~= nil and state.gems >= state.nightEyesCost, tap = function()
			ask("TrackBuy", "nightEyes")
		end },
	})
	row(`Shelf: {state.shelfSlots} slots`, {
		{ text = if state.shelfSlotsCost then `+4 · {state.shelfSlotsCost} gems` else "Max", on = state.shelfSlotsCost ~= nil and state.gems >= state.shelfSlotsCost, tap = function()
			ask("ShelfSlots")
		end },
	})
	local tierName = Config.Tiers.order[state.tier]
	row(if state.prestigeNeed then `{tierName}: {state.tierRuns} / {state.prestigeNeed} runs to prestige` else `{tierName}: last tier for now`, {
		{ text = "Prestige", on = state.canPrestige, tap = function()
			ask("Prestige")
		end },
	})
	local tierButtons = {}
	for t = 1, state.tier do
		table.insert(tierButtons, { text = Config.Tiers.order[t], on = state.nextTier ~= t, tap = function()
			ask("TierPick", t)
		end })
	end
	row("Next run", tierButtons)
	row(`Vault: {#state.vault} items · {state.vaultReclaimsLeft} reclaims left`)
	for i, item in state.vault do
		row(`{Gifts.displayName(item.giftId, item.mutation)} ({item.rarity}){if item.count > 1 then ` ×{item.count}` else ""}`, {
			{ text = "Reclaim", on = state.vaultReclaimsLeft > 0, tap = function()
				ask("VaultReclaim", i)
			end },
		})
	end
end

local function fillShop()
	local s = screens.Shop
	Widgets.clear(s.body)
	s.title.Text = "Shop (Robux)"
	local order = 0
	for _, name in Config.GamepassOrder do
		local pass = Config.Gamepasses[name]
		order += 1
		local owned = state.passes[name]
		Widgets.row(s.body, order, `{pass.name} · R$ {pass.robux}`, {
			{ text = if owned then "Owned" elseif pass.id == 0 then "Soon" else "Buy", on = not owned and pass.id ~= 0, tap = function()
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end },
		})
	end
	for _, name in Config.DevProductOrder do
		local product = Config.DevProducts[name]
		order += 1
		Widgets.row(s.body, order, `{product.gems} gems · R$ {product.robux}`, {
			{ text = if product.id == 0 then "Soon" else "Buy", on = product.id ~= 0, tap = function()
				MarketplaceService:PromptProductPurchase(player, product.id)
			end },
		})
	end
end

---------------------------------------------------------------- init

function MetaScreens.init(gui: ScreenGui, toast: (text: string) -> ())
	request = Remotes.get("EconomyRequest")
	spin = Remotes.get("ClassSpin")
	local specs = {
		{ name = "Shop", fill = fillShop, y = 0.36 },
		{ name = "Classes", fill = fillClasses, y = 0.45 },
		{ name = "Rewards", fill = fillRewards, y = 0.54 },
	}
	for _, spec in specs do
		local frame, title, body = Widgets.screen(gui, spec.name, Widgets.PANEL)
		local s = { frame = frame, title = title, body = body, fill = spec.fill }
		screens[spec.name] = s
		frame:GetPropertyChangedSignal("Visible"):Connect(function()
			if frame.Visible and state then
				s.fill()
			end
		end)
		local open = Widgets.button(gui, spec.name, UDim2.fromScale(0.1, 0.08), function()
			for _, other in screens do
				if other ~= s then
					other.frame.Visible = false
				end
			end
			frame.Visible = state ~= nil and not frame.Visible
		end)
		open.Name = `{spec.name}Button`
		open.Position = UDim2.fromScale(0.88, spec.y)
	end
	Remotes.get("ProfileState").OnClientEvent:Connect(function(new)
		state = new
		if new.message then
			toast(new.message)
		end
		for _, s in screens do
			if s.frame.Visible then
				s.fill()
			end
		end
	end)
end

-- Gems for the HUD bar, or nil before the profile loads.
function MetaScreens.gems(): number?
	return state and state.gems
end

return MetaScreens
