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
import 'lib/notify.lua'
import 'lib/story.lua'
import 'lib/fear.lua'
import 'lib/rivals.lua'
import 'lib/tools.lua'
import 'lib/traphelper.lua'
import 'lib/items.lua'
import 'lib/score.lua'
import 'lib/death.lua'
import 'lib/inbox.lua'
import 'lib/weapons.lua'

-- ── AP icon ───────────────────────────────────────────────────────────────────

-- Animation name for our custom AP logo, packed in Tenacer_AP-HadesII_AP.pkg.
AP_ICON_ANIM = _PLUGIN.guid .. "\\ap_icon"

-- Replace the Icon field on every AP-controlled incantation so the cauldron
-- screen shows the Archipelago logo instead of per-spell artwork. The set of
-- AP-controlled keys depends on settings:
--  • cauldronsanity → the 86 non-surface, non-goal incantations
--  • lock_surface_incantations → the two surface-unlock incantations
--  • true_ending → the two goal incantations
function ap_patch_incantation_icons()
	if WorldUpgradeData == nil then return end
	local settings = ap_load_settings() or {}
	local do_cauldron = settings.cauldronsanity == 1
	for key, _ in pairs(INCANTATION_LOCATIONS) do
		local data = WorldUpgradeData[key]
		if data then
			local is_ap = is_ap_keyed_incantation(key, settings)
				or (do_cauldron and not is_surface_lock_incantation(key)
					and not is_goal_incantation(key))
			if is_ap then
				data.Icon = AP_ICON_ANIM
			end
		end
	end
end

-- Append a `PathTrue` requirement to each AP-keyed incantation's
-- GameStateRequirements so the cauldron entry stays hidden until the player
-- receives the AP item (which sets the corresponding TextLinesRecord flag).
-- Idempotent: a sentinel `_ap_cauldron_gate_patched` on each entry prevents
-- double-application across hot-reload / SetupMap calls.
function ap_patch_incantation_gates()
	if WorldUpgradeData == nil then return end
	local settings = ap_load_settings() or {}
	local keyed = ap_keyed_incantations(settings)
	for key in pairs(keyed) do
		local data = WorldUpgradeData[key]
		if data and not data._ap_cauldron_gate_patched then
			data.GameStateRequirements = data.GameStateRequirements or {}
			table.insert(data.GameStateRequirements, {
				PathTrue = { "GameState", "TextLinesRecord", ap_unlock_flag_for(key) },
			})
			data._ap_cauldron_gate_patched = true
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
-- Override installed via modutil.mod.Path.Set so the write lands in _G — bare
-- `function ReceivedGiftPresentation(...)` here would silently no-op (LuaENVY-private env).
if not _ap_orig_ReceivedGiftPresentation then
    _ap_orig_ReceivedGiftPresentation = ReceivedGiftPresentation
end
local function ap_received_gift_presentation(npc, giftAnimation)
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
modutil.mod.Path.Set("ReceivedGiftPresentation", ap_received_gift_presentation)
print("[HadesII_AP] ReceivedGiftPresentation override installed")

-- ── Hint dispatch on cauldron / Fated List open ──────────────────────────────

-- Hint each visible incantation when a cauldron category is displayed (initial
-- open + every tab switch). ap_hint_cauldron_visible reads screen.AvailableItems
-- which the original GhostAdminDisplayCategory has just populated, then dedupes
-- via ap_hint_location so each location is hinted at most once.
-- Override installed via modutil.mod.Path.Set so the write lands in _G — bare
-- `function GhostAdminDisplayCategory(...)` here would silently no-op (LuaENVY-private env).
if not _ap_orig_GhostAdminDisplayCategory then
    _ap_orig_GhostAdminDisplayCategory = GhostAdminDisplayCategory
end
local function ap_ghost_admin_display_category(screen, button)
    _ap_orig_GhostAdminDisplayCategory(screen, button)
    ap_hint_cauldron_visible(screen)
end
modutil.mod.Path.Set("GhostAdminDisplayCategory", ap_ghost_admin_display_category)
print("[HadesII_AP] GhostAdminDisplayCategory override installed")

-- Hint each visible (non-cashed-out) prophecy when the Fated List opens.
-- Replicates the game's filter independently rather than reading screen state,
-- which is cleaner because OpenQuestLogScreen has waits before it builds buttons.
-- Override installed via modutil.mod.Path.Set (see note above).
if not _ap_orig_OpenQuestLogScreen then
    _ap_orig_OpenQuestLogScreen = OpenQuestLogScreen
end
local function ap_open_quest_log_screen(args)
    local result = _ap_orig_OpenQuestLogScreen(args)
    ap_hint_questlog_visible()
    return result
end
modutil.mod.Path.Set("OpenQuestLogScreen", ap_open_quest_log_screen)
print("[HadesII_AP] OpenQuestLogScreen override installed")

-- ── Fatesanity: intercept prophecy cashout ───────────────────────────────────

-- For prophecies that are AP locations (fatesanity on), suppress the vanilla
-- AddResource — the resource is granted instead by give_item when the AP item
-- comes back from the server. The function body is inline-replicated from
-- QuestLogLogic.lua:211 so we can drop just the one AddResource line; see
-- the cauldron-incantation pattern (HandleGhostAdminPurchase) for the same idea.
if not _ap_orig_CashOutQuest then
    _ap_orig_CashOutQuest = CashOutQuest
end
local function ap_cash_out_quest(screen, button)
    local settings = ap_load_settings()
    local questData = button and button.Data
    local quest_name = questData and questData.Name
    local ap_location = quest_name and PROPHECY_LOCATIONS[quest_name]
    if not (settings and settings.fatesanity == 1 and ap_location) then
        return _ap_orig_CashOutQuest(screen, button)
    end
    if questData.CompleteGameStateRequirements ~= nil
            and not IsGameStateEligible(questData, questData.CompleteGameStateRequirements) then
        return
    end
    button.OnPressedFunctionName = nil
    if GameState.QuestStatus[quest_name] ~= "CashedOut" then
        ap_check_location(ap_location)
        GameState.QuestStatus[quest_name] = "CashedOut"
        QuestCashedOutPresentation(screen, button)
    end
    StopFlashing({ Id = button.Id })
    local justCashedOutFormat = screen.JustCashedOutFormat
    justCashedOutFormat.Id = button.Id
    ModifyTextBox(justCashedOutFormat)
    SetAlpha({ Id = screen.Components.RewardText.Id, Fraction = 0.0, Duration = 0.2 })
    local animationName = screen.Components.RewardClaimedIcon.AnimationName
    if questData.InterstitialData ~= nil then
        animationName = screen.Components.RewardClaimedIcon.SpecialAnimationName
    end
    SetAnimation({ DestinationId = screen.Components.RewardClaimedIcon.Id, Name = animationName })
    SetAlpha({ Id = screen.Components.RewardClaimedIcon.Id, Fraction = 1.0, Duration = 0.2 })
end
modutil.mod.Path.Set("CashOutQuest", ap_cash_out_quest)
print("[HadesII_AP] CashOutQuest override installed")

-- ── Weapon / hidden aspect sanity ────────────────────────────────────────────

-- Suppress the vanilla weapon/aspect unlock when the corresponding sanity option
-- is on. Player still pays cost; AddWorldUpgrade and the equip thread are skipped.
-- give_item handles the real unlock when the AP item arrives. WorldUpgradesAdded
-- is set so the slot shows as purchased and can't be re-bought.
-- Override installed via modutil.mod.Path.Set so the write lands in _G — bare
-- `function HandleWeaponShopPurchase(...)` here would silently no-op (LuaENVY-private env).
if not _ap_orig_HandleWeaponShopPurchase then
    _ap_orig_HandleWeaponShopPurchase = HandleWeaponShopPurchase
end
local function ap_handle_weapon_shop_purchase(screen, button)
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
modutil.mod.Path.Set("HandleWeaponShopPurchase", ap_handle_weapon_shop_purchase)
print("[HadesII_AP] HandleWeaponShopPurchase override installed")

-- ── Trap & Helper hooks ─────────────────────────────────────────────────────

-- StartNewRun: apply persistent run-start helpers after vanilla finishes.
--   • Initial Money helper: extra Money on top of CalculateStartingMoney
--   • Max Health helper: re-sync the cumulative bonus onto the fresh hero
-- Path.Set + _ap_orig_* pattern (Path.Wrap crashes on App.Reset; bare
-- `function StartNewRun(...)` would silently no-op via LuaENVY).
if not _ap_orig_StartNewRun then
	_ap_orig_StartNewRun = StartNewRun
end
local function ap_start_new_run(prevRun, args)
	local result = _ap_orig_StartNewRun(prevRun, args)
	pcall(ap_apply_max_health_helper)
	pcall(ap_apply_initial_money_helper)
	return result
end
modutil.mod.Path.Set("StartNewRun", ap_start_new_run)
print("[HadesII_AP] StartNewRun override installed")

-- GetRarityChances: add an additive percentage to every rarity bucket from
-- the accumulated Boon Boost Helpers. Hot in loot rolls, but Path.Set is
-- just a regular function call (no wrap-machinery overhead).
if not _ap_orig_GetRarityChances then
	_ap_orig_GetRarityChances = GetRarityChances
end
local function ap_get_rarity_chances(loot)
	local rarityChances = _ap_orig_GetRarityChances(loot)
	local boost = ap_boon_boost_pct and ap_boon_boost_pct() or 0
	if boost > 0 and rarityChances then
		for k, v in pairs(rarityChances) do
			rarityChances[k] = v + boost
		end
	end
	return rarityChances
end
modutil.mod.Path.Set("GetRarityChances", ap_get_rarity_chances)
print("[HadesII_AP] GetRarityChances override installed")

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
	local keyed = ap_keyed_incantations(settings)
	local has_keyed = next(keyed) ~= nil
	if not (do_cauldron or do_fate or has_keyed) then return end

	local location_items = ap_read_location_items() or {}

	-- Resolve an incantation key to the AP location name it represents, only
	-- when that key is AP-controlled in the current settings. The 86
	-- cauldronsanity keys are owned by cauldronsanity; the surface 2 and goal 2
	-- are owned by their respective toggles regardless of cauldronsanity.
	local function incantation_location_for(id)
		if keyed[id] then return INCANTATION_LOCATIONS[id] end
		if do_cauldron
			and not is_surface_lock_incantation(id)
			and not is_goal_incantation(id) then
			return INCANTATION_LOCATIONS[id]
		end
		return nil
	end

	for _, entry in ipairs(data.Texts) do
		local id = entry.Id
		if id then
			local ap_location = incantation_location_for(id)
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
				if base_id and incantation_location_for(base_id) then
					entry.Description = "What you receive in exchange is determined by the Archipelago multiworld randomizer."
				end
			end
		end
	end
end

