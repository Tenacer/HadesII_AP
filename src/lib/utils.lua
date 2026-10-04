---@meta _
---@diagnostic disable: lowercase-global

-- Shared helpers that don't belong to a single feature: AP icon, text labels, check banner and toasts.

-- ═══ Data ════════════════════════════════════════════════════════════════════

-- Animation name for our custom AP logo, packed in Tenacer_AP-HadesII_AP.pkg.
AP_ICON_ANIM = _PLUGIN.guid .. "\\ap_icon"

-- Path of our texture package holding the AP icon.
local AP_ICON_PKG = rom.path.combine(_PLUGIN.plugins_data_mod_folder_path, _PLUGIN.guid)

local NOTIFY_DEFAULTS = {
	delay    = 5.0,
	fontsize = 15,  -- fallback only; the live value is config.notify_font_size
	font     = "LatoBold",
	sound    = "/Leftovers/SFX/AuraOff",
	-- Backing rectangle colour; alpha keeps the text readable over the scene.
	bgcol    = { 0.0745, 0.1020, 0.0980, 0.75 },
}

-- Toast layout: slots stack upward from a fixed anchor near the bottom-left; existing toasts never move.
local NOTIFY_GROUP   = "H2AP_Notify"
local NOTIFY_ROW_H   = 30
local NOTIFY_MAX     = 12
local NOTIFY_BASE_X  = 420
local NOTIFY_BASE_DY = 220   -- pixels above the screen bottom for slot 0

-- Bounded FIFO queue of toasts waiting for a free slot; overflow sheds the oldest.
local NOTIFY_PENDING_MAX = 128
local NOTIFY_RECLAIM_GRACE = 1.0   -- secs past a toast's lifetime before forced reclaim

-- ═══ Logic ═══════════════════════════════════════════════════════════════════

-- Load our texture package; called at startup and every room since the game may evict it.
function H2AP_LoadIconPackage()
	LoadPackages({ Name = AP_ICON_PKG })
end

function sjson_ShellText(data)
	for _, v in ipairs(data.Texts) do
		if v.Id == 'MainMenuScreen_PlayGame' then
			v.DisplayName = 'Play Hades II AP'
			break
		end
	end
end

-- Inject the "AP Check Sent" banner title used by the check banner.
function H2AP_AddCheckSentText(data)
	data.Texts[#data.Texts + 1] = { Id = "APCheckSent", DisplayName = "AP Check Sent" }
end

-- Rewrite a text entry to advertise the scouted AP item at `ap_location`, preserving the vanilla name/description.
function H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
	local item_entry = location_items[ap_location]
	local display = "AP Location Check"
	if type(item_entry) == "table" then
		display = item_entry.display or item_entry.item_name or display
	elseif type(item_entry) == "string" then
		-- Back-compat with the older flat string format.
		display = item_entry
	end
	local vanilla_name = entry.DisplayName
	local vanilla_desc = entry.Description
	local opener = (vanilla_name and vanilla_name ~= "") and vanilla_name or display
	local new_desc = "Archipelago location check for " .. opener .. "."
	if vanilla_desc and vanilla_desc ~= "" then
		new_desc = new_desc .. "\n\nOriginal: " .. vanilla_desc
	end
	entry.DisplayName = display
	entry.Description = new_desc
end

-- Replicate a WeaponShop purchase without the vanilla unlock (the player still pays), then fire the AP check; the AP item delivers the real unlock.
function H2AP_PurchaseShopCheck(screen, button, ap_location)
	local itemData = button.Data
	local item_name = itemData.Name
	if not button.Free and not HasResources(itemData.Cost) then
		ScreenCantAffordPresentation(screen, button)
		return
	end
	if not IsEmpty(itemData.Cost) ~= nil and itemData.PurchaseRequirements ~= nil
		and not IsGameStateEligible(itemData.PurchaseRequirements) then
		CantPurchasePresentation(screen.Components["PurchaseButton" .. button.Index])
		return
	end
	for resourceName, resourceCost in pairs(itemData.Cost) do
		-- Base aspects cost MetaCurrency (Bones), which may lack a cost-icon backing.
		local backing = screen.Components["ResourceIconBacking" .. resourceName]
		SpendResource(resourceName, resourceCost, metaUpgradeName, {
			TargetId = backing and backing.Id,
			UseScreenLocation = true,
			TextOffsetY = 11, TextAnchorOffsetY = -50,
			HoldDuration = 0, FadeOutDuration = 0.2,
			SkipQuestStatusCheck = true,
		})
	end
	WeaponShopItemPurchasedPresentation(button, itemData)
	GameState.WorldUpgradesAdded[item_name] = true
	if CurrentRun then
		CurrentRun.WorldUpgradesAdded[item_name] = true
	end
	RemoveStoreItemPin(item_name, { Purchase = true })
	CreateAnimation({ Name = "ContractorSlotPurchase", DestinationId = screen.Components["PurchaseButton" .. button.Index].Id, OffsetX = 0 })
	Destroy({ Id = screen.Components["PurchaseButton" .. button.Index].Id })
	screen.Components["PurchaseButton" .. button.Index] = nil
	if screen.Components["Icon" .. button.Index] ~= nil then
		Destroy({ Id = screen.Components["Icon" .. button.Index].Id })
		screen.Components["Icon" .. button.Index] = nil
	end
	-- Pass the CloseButton so the camera pans back to Melinoë instead of staying stuck on the shop.
	CloseWeaponShopScreen(screen, screen.Components.CloseButton or button, {})
	H2AP_CheckLocation(ap_location)
	H2AP_ShowCheckSentBanner()
end

-- ═══ Presentation ════════════════════════════════════════════════════════════

-- Show the AP logo banner when a location check fires.
function H2AP_ShowCheckSentBanner()
	thread(function()
		DisplayInfoBanner(nil, {
			TitleText = "APCheckSent",
			FontScale = 0.82,
			Icon = AP_ICON_ANIM,
			IconScale = 1.3,
			IconMoveSpeed = 0.00001,
			IconOffsetY = 6,
			AnimationName = "InfoBannerCauldronIn",
			AnimationOutName = "InfoBannerCauldronOut",
			IconBackingAnimationName = "LocationBackingIrisSmallSubtitleIn",
			IconBackingAnimationOutName = "LocationBackingIrisSmallSubtitleOut",
		})
	end)
end

-- ── Notification toasts (mod-owned, ID-safe) ─────────────────────────────────
-- Deliberately avoids ModUtil.Hades.PrintStack, whose stale-id Destroy churn can delete live world objects (soft-lock); each toast here owns and destroys only its own component.

-- slot index (1..NOTIFY_MAX) → deadline while occupied, nil when free; deadlines (not booleans) let slots self-heal when a map load kills the toast thread before it releases its slot.
local notify_slots = {}

local notify_pending = {}

local function notify_now()
	return _worldTime or 0
end

-- Free any slot whose deadline has elapsed.
local function notify_reclaim()
	local now = notify_now()
	for i = 1, NOTIFY_MAX do
		local deadline = notify_slots[i]
		if deadline ~= nil and now >= deadline then
			notify_slots[i] = nil
		end
	end
end

-- Claim a free slot for a toast of the given lifetime, reclaiming expired slots first.
local function notify_claim_slot(lifetime)
	notify_reclaim()
	for i = 1, NOTIFY_MAX do
		if notify_slots[i] == nil then
			notify_slots[i] = notify_now() + lifetime + NOTIFY_RECLAIM_GRACE
			return i
		end
	end
	return nil
end

-- Forward declaration: the pump and toasts reference each other.
local notify_pump

-- One self-contained toast in a claimed slot: create, fade in, wait, fade out, Destroy, then free the slot and pump the queue.
local function notify_start(slot, t)
	thread(function()
		pcall(function()
			local cx = ScreenCenterX or 480
			local cy = ScreenCenterY or 270
			local x  = NOTIFY_BASE_X
			local y  = 2 * cy - NOTIFY_BASE_DY - (slot - 1) * NOTIFY_ROW_H

			local comp = CreateScreenComponent({ Name = "rectangle01", Group = NOTIFY_GROUP, X = x, Y = y })
			local id = comp.Id
			SetScaleX({ Id = id, Fraction = 10 / 6 })
			SetScaleY({ Id = id, Fraction = 0.1 })
			SetColor({ Id = id, Color = t.bgcol })
			-- Center justification keeps the text inside the single-line backing bar.
			CreateTextBox({
				Id = id, Text = t.text, FontSize = t.fontsize, OffsetX = 0, OffsetY = 0,
				Color = t.color, Font = t.font, Justification = "Center",
			})
			SetAlpha({ Id = id, Fraction = 0 })
			if t.sound and t.sound ~= "" then PlaySound({ Name = t.sound }) end
			SetAlpha({ Id = id, Fraction = 1, Duration = 0.12 })
			wait(t.delay)
			SetAlpha({ Id = id, Fraction = 0, Duration = 0.33 })
			wait(0.33)
			Destroy({ Ids = { id } })
		end)
		-- Always release the slot, then let the next queued toast claim it.
		notify_slots[slot] = nil
		notify_pump()
	end)
end

-- Drain the pending queue into any free slots.
notify_pump = function()
	while #notify_pending > 0 do
		local t = notify_pending[1]
		-- Lifetime mirrors the thread body: fade-in + hold + fade-out.
		local lifetime = 0.12 + (t.delay or 0) + 0.33
		local slot = notify_claim_slot(lifetime)
		if slot == nil then return end  -- all slots busy; wait for one to free
		table.remove(notify_pending, 1)
		notify_start(slot, t)
	end
end

-- Enqueue a toast and immediately try to display it.
local function notify_spawn(text, color, delay, sound, bgcol, fontsize, font)
	if #notify_pending >= NOTIFY_PENDING_MAX then
		table.remove(notify_pending, 1)  -- shed the oldest
	end
	notify_pending[#notify_pending + 1] = {
		text = text, color = color, delay = delay, sound = sound,
		bgcol = bgcol, fontsize = fontsize, font = font,
	}
	notify_pump()
end

-- pcall'd at the boundary too, so a notification can never break a caller.
function H2AP_Notify(text, color, delay, sound)
	if type(text) ~= "string" or text == "" then return end
	if CreateScreenComponent == nil or thread == nil then return end
	pcall(notify_spawn,
		text,
		color or { 1, 1, 1, 1 },
		delay or NOTIFY_DEFAULTS.delay,
		sound or NOTIFY_DEFAULTS.sound,
		NOTIFY_DEFAULTS.bgcol,
		(config and config.notify_font_size) or NOTIFY_DEFAULTS.fontsize,
		NOTIFY_DEFAULTS.font)
end
