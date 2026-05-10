---@meta _
---@diagnostic disable: lowercase-global

import 'lib/json.lua'
import 'lib/ipc.lua'
import 'lib/settings.lua'
import 'lib/state.lua'
import 'lib/IncantationData.lua'
import 'lib/ProphecyData.lua'
import 'lib/hints.lua'
import 'lib/ItemData.lua'
import 'lib/story.lua'
import 'lib/fear.lua'
import 'lib/rivals.lua'
import 'lib/tools.lua'
import 'lib/items.lua'
import 'lib/score.lua'
import 'lib/death.lua'
import 'lib/inbox.lua'
import 'lib/weapons.lua'

-- ── AP icon ───────────────────────────────────────────────────────────────────

-- Animation name for our custom AP logo, packed in Tenacer_AP-HadesII_AP.pkg.
AP_ICON_ANIM = _PLUGIN.guid .. "\\ap_icon"

-- Replace the Icon field on every tracked incantation in WorldUpgradeData so
-- the cauldron screen shows the Archipelago logo instead of per-spell artwork.
function ap_patch_incantation_icons()
	if WorldUpgradeData == nil then return end
	for key, _ in pairs(INCANTATION_LOCATIONS) do
		local data = WorldUpgradeData[key]
		if data then
			data.Icon = AP_ICON_ANIM
		end
	end
end

-- Show the AP logo banner when a keepsake gifting location check fires.
-- Mirrors PlayerReceivedGiftPresentation's sound/voice/color-grading but
-- uses the AP logo and gift-style banner animations instead of the vanilla keepsake icon.
function ap_show_keepsake_check_banner(npc)
	thread(function()
		AdjustColorGrading({ Name = "Mythmaker", Duration = 0.66 })
		PlaySound({ Name = "/Leftovers/Menu Sounds/StarSelectConfirm" })
		thread(PlayVoiceLines, npc.GiftGivenVoiceLines, true)
		thread(PlayVoiceLines, CurrentRun.Hero.GiftReceivedVoiceLines, true)
		DisplayInfoBanner(nil, {
			Icon = AP_ICON_ANIM,
			IconScale = 1.3,
			IconMoveSpeed = 0.00001,
			IconOffsetY = 6,
			HighlightIcon = true,
			TitleText = "APCheckSent",
			FontScale = 0.82,
			AnimationName = "InfoBannerGiftIn",
			AnimationOutName = "InfoBannerGiftOut",
			IconBackingAnimationName = "LocationBackingIrisSmallSubtitleIn",
			IconBackingAnimationOutName = "LocationBackingIrisSmallSubtitleOut",
			IconBackingColor = Color.Lavender,
			IconBackingHSV = { 0.25, -0.2, 0.1 },
		})
		thread(function()
			wait(1.0)
			AdjustColorGrading({ Name = "Off", Duration = 1.0 })
		end)
		if CheckObjectiveSet("KeepsakePrompt") then
			UpdateAffordabilityStatus()
		end
	end)
end

-- Show the AP logo banner when a boss reward location check fires.
-- Uses the same InfoBanner presentation as the cauldron "AP Check Sent" popup.
function ap_show_boss_reward_banner()
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

-- ── Keepsakesanity gifting hook ───────────────────────────────────────────────

-- Hook ReceivedGiftPresentation (called in GiveGift before the GiftPresentation
-- check) to send AP location checks in keepsakesanity mode. This fires regardless
-- of whether give_item already set GiftPresentation, which means we always catch
-- the gifting event and can send the check even if the keepsake was AP-received first.
-- Uses direct Lua replacement (no modutil wrap) to avoid the GC crash on game reset.
if not _ap_orig_ReceivedGiftPresentation then
    _ap_orig_ReceivedGiftPresentation = ReceivedGiftPresentation
end
function ReceivedGiftPresentation(npc, giftAnimation)
    _ap_orig_ReceivedGiftPresentation(npc, giftAnimation)
    if giftAnimation ~= "GiftNPC" then return end
    local settings = ap_load_settings()
    if not (settings and settings.keepsakesanity == 1) then return end
    local name = GetGenusName and GetGenusName(npc)
    local giftData = GiftData and name and GiftData[name]
    if not giftData then return end
    for _, giftLevelData in ipairs(giftData) do
        local gift_id = giftLevelData and giftLevelData.Gift
        if gift_id then
            local location = KEEPSAKE_LOCATION_FOR_GIFT and KEEPSAKE_LOCATION_FOR_GIFT[gift_id]
            if location then
                local state = ap_load_state()
                local already_sent = false
                for _, cl in ipairs(state.checked_locations or {}) do
                    if cl == location then already_sent = true; break end
                end
                ap_check_location(location)
                if GameState and GameState.GiftPresentation then
                    GameState.GiftPresentation[gift_id] = true
                end
                if not already_sent then
                    ap_show_keepsake_check_banner(npc)
                end
            end
        end
    end
end

-- ── Hint dispatch on cauldron / Fated List open ──────────────────────────────

-- Hint each visible incantation when a cauldron category is displayed (initial
-- open + every tab switch). ap_hint_cauldron_visible reads screen.AvailableItems
-- which the original GhostAdminDisplayCategory has just populated, then dedupes
-- via ap_hint_location so each location is hinted at most once.
-- Direct replacement (not modutil wrap) — new wraps trigger the App.Reset GC crash.
if not _ap_orig_GhostAdminDisplayCategory then
    _ap_orig_GhostAdminDisplayCategory = GhostAdminDisplayCategory
end
function GhostAdminDisplayCategory(screen, button)
    _ap_orig_GhostAdminDisplayCategory(screen, button)
    ap_hint_cauldron_visible(screen)
end

-- Hint each visible (non-cashed-out) prophecy when the Fated List opens.
-- Replicates the game's filter independently rather than reading screen state,
-- which is cleaner because OpenQuestLogScreen has waits before it builds buttons.
if not _ap_orig_OpenQuestLogScreen then
    _ap_orig_OpenQuestLogScreen = OpenQuestLogScreen
end
function OpenQuestLogScreen(args)
    local result = _ap_orig_OpenQuestLogScreen(args)
    ap_hint_questlog_visible()
    return result
end

-- ── Weapon / hidden aspect sanity ────────────────────────────────────────────

-- Suppress the vanilla weapon/aspect unlock when the corresponding sanity option
-- is on. Player still pays cost; AddWorldUpgrade and the equip thread are skipped.
-- give_item handles the real unlock when the AP item arrives. WorldUpgradesAdded
-- is set so the slot shows as purchased and can't be re-bought.
-- Direct replacement (not modutil wrap) — new wraps trigger the App.Reset GC crash.
if not _ap_orig_HandleWeaponShopPurchase then
    _ap_orig_HandleWeaponShopPurchase = HandleWeaponShopPurchase
end
function HandleWeaponShopPurchase(screen, button)
    local settings = ap_load_settings()
    local itemData = button and button.Data
    if settings and itemData then
        local item_name = itemData.Name
        local ap_location = nil
        if settings.weaponsanity == 1 and WEAPON_LOCATIONS[item_name] then
            ap_location = WEAPON_LOCATIONS[item_name]
        elseif settings.hidden_aspectsanity == 1 and HIDDEN_ASPECT_LOCATIONS[item_name] then
            ap_location = HIDDEN_ASPECT_LOCATIONS[item_name]
        end
        if ap_location then
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
                SpendResource(resourceName, resourceCost, metaUpgradeName, {
                    TargetId = screen.Components["ResourceIconBacking" .. resourceName].Id,
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
            CloseWeaponShopScreen(screen, button, {})
            ap_check_location(ap_location)
            ap_show_boss_reward_banner()
            return
        end
    end
    return _ap_orig_HandleWeaponShopPurchase(screen, button)
end

-- ── SJSON hook handlers ───────────────────────────────────────────────────────

function sjson_ShellText(data)
	for _, v in ipairs(data.Texts) do
		if v.Id == 'MainMenuScreen_PlayGame' then
			v.DisplayName = 'Play Hades II AP'
			break
		end
	end
end

function sjson_HelpText(data)
	-- Inject the "AP Check Sent" banner title used by the cauldron hook.
	data.Texts[#data.Texts + 1] = { Id = "APCheckSent", DisplayName = "AP Check Sent" }

	-- Replace incantation / Fated List Quest entries with AP info when their
	-- respective sanity option is on. DisplayName comes from ap_location_items.json
	-- (written by the Python client after LocationScouts); falls back to a generic
	-- "AP Location Check" if the file isn't there yet.
	local settings = ap_load_settings() or {}
	local do_cauldron = settings.cauldronsanity == 1
	local do_fate = settings.fatesanity == 1
	if not (do_cauldron or do_fate) then return end

	local location_items = ap_read_location_items() or {}

	for _, entry in ipairs(data.Texts) do
		local id = entry.Id
		if id then
			local ap_location = (do_cauldron and INCANTATION_LOCATIONS[id])
				or (do_fate and PROPHECY_LOCATIONS[id])
			if ap_location then
				local item_entry = location_items[ap_location]
				local display = "AP Location Check"
				if type(item_entry) == "table" then
					display = item_entry.display or item_entry.item_name or display
				elseif type(item_entry) == "string" then
					-- Back-compat with the older flat string format.
					display = item_entry
				end
				entry.DisplayName = display
				entry.Description = "Archipelago location check. Complete this in-game to send a check to the Archipelago server."
			else
				local base_id = id:match("^(.-)_Flavor$")
				if base_id and do_cauldron and INCANTATION_LOCATIONS[base_id] then
					entry.Description = "What you receive in exchange is determined by the Archipelago multiworld randomizer."
				end
			end
		end
	end
end

