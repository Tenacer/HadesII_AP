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
import 'lib/broker.lua'
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
function H2AP_PatchIncantationIcons()
	if WorldUpgradeData == nil then return end
	local settings = H2AP_LoadSettings() or {}
	local do_cauldron = settings.cauldronsanity == 1
	for key, _ in pairs(INCANTATION_LOCATIONS) do
		local data = WorldUpgradeData[key]
		if data then
			local is_ap = H2AP_IsApKeyedIncantation(key, settings)
				or (do_cauldron and not H2AP_IsSurfaceLockIncantation(key)
					and not H2AP_IsGoalIncantation(key))
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
function H2AP_PatchIncantationGates()
	if WorldUpgradeData == nil then return end
	local settings = H2AP_LoadSettings() or {}
	local keyed = H2AP_KeyedIncantations(settings)
	for key in pairs(keyed) do
		local data = WorldUpgradeData[key]
		if data and not data._ap_cauldron_gate_patched then
			data.GameStateRequirements = data.GameStateRequirements or {}
			table.insert(data.GameStateRequirements, {
				PathTrue = { "GameState", "TextLinesRecord", H2AP_UnlockFlagFor(key) },
			})
			data._ap_cauldron_gate_patched = true
		end
	end
end

-- Rewrite the brewing costs of the two True Ending goal incantations so they
-- match the per-seed thresholds. Vanilla costs (8 total Z-Sand, 4 V-Lens) would
-- consume the entire item pool — patching to the threshold leaves the rest
-- free for Arcana upgrades. Gigaros + Entropy stay at 1× each.
-- Idempotent via `_ap_cost_patched` sentinel.
function H2AP_PatchIncantationCosts()
	if WorldUpgradeData == nil then return end
	local settings = H2AP_LoadSettings() or {}
	if settings.true_ending ~= 1 then return end
	local zsand = tonumber(settings.zodiac_sand_needed) or 4
	local vlens = tonumber(settings.void_lens_needed) or 2
	local d = WorldUpgradeData["WorldUpgradeTimeStop"]
	if d and not d._ap_cost_patched then
		d.Cost = { MixerIBoss = zsand, MixerMythic = 1 }
		d._ap_cost_patched = true
	end
	local s = WorldUpgradeData["WorldUpgradeStormStop"]
	if s and not s._ap_cost_patched then
		s.Cost = { MixerQBoss = vlens, HadesSpearPoints = 1 }
		s._ap_cost_patched = true
	end
end

-- Show the AP logo banner when a keepsake gifting location check fires.
-- Mirrors PlayerReceivedGiftPresentation's sound/voice/color-grading but
-- uses the AP logo and gift-style banner animations instead of the vanilla keepsake icon.
function H2AP_ShowKeepsakeCheckBanner(npc)
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
function H2AP_ShowBossRewardBanner()
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

-- ── Hint dispatch on cauldron / Fated List open ──────────────────────────────

-- Hint each visible incantation when a cauldron category is displayed (initial
-- open + every tab switch). H2AP_HintCauldronVisible reads screen.AvailableItems
-- which the original GhostAdminDisplayCategory has just populated, then dedupes
-- via H2AP_HintLocation so each location is hinted at most once.
-- Override installed via modutil.mod.Path.Set so the write lands in _G — bare
-- `function GhostAdminDisplayCategory(...)` here would silently no-op (LuaENVY-private env).
if not _ap_orig_GhostAdminDisplayCategory then
    _ap_orig_GhostAdminDisplayCategory = GhostAdminDisplayCategory
end
local function ap_ghost_admin_display_category(screen, button)
    _ap_orig_GhostAdminDisplayCategory(screen, button)
    H2AP_HintCauldronVisible(screen)
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
    H2AP_HintQuestlogVisible()
    return result
end
modutil.mod.Path.Set("OpenQuestLogScreen", ap_open_quest_log_screen)
print("[HadesII_AP] OpenQuestLogScreen override installed")

-- ── Fatesanity: intercept prophecy cashout ───────────────────────────────────

-- For prophecies that are AP locations (fatesanity on), suppress the vanilla
-- AddResource — the resource is granted instead by H2AP_GiveItem when the AP item
-- comes back from the server. The function body is inline-replicated from
-- QuestLogLogic.lua:211 so we can drop just the one AddResource line; see
-- the cauldron-incantation pattern (HandleGhostAdminPurchase) for the same idea.
if not _ap_orig_CashOutQuest then
    _ap_orig_CashOutQuest = CashOutQuest
end
local function ap_cash_out_quest(screen, button)
    local settings = H2AP_LoadSettings()
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
        H2AP_CheckLocation(ap_location)
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
-- H2AP_GiveItem handles the real unlock when the AP item arrives. WorldUpgradesAdded
-- is set so the slot shows as purchased and can't be re-bought.
-- Override installed via modutil.mod.Path.Set so the write lands in _G — bare
-- `function HandleWeaponShopPurchase(...)` here would silently no-op (LuaENVY-private env).
if not _ap_orig_HandleWeaponShopPurchase then
    _ap_orig_HandleWeaponShopPurchase = HandleWeaponShopPurchase
end
local function ap_handle_weapon_shop_purchase(screen, button)
    local settings = H2AP_LoadSettings()
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
            H2AP_CheckLocation(ap_location)
            H2AP_ShowBossRewardBanner()
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
	pcall(H2AP_ApplyMaxHealthHelper)
	pcall(H2AP_ApplyInitialMoneyHelper)
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
	local boost = H2AP_BoonBoostPct and H2AP_BoonBoostPct() or 0
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
	local settings = H2AP_LoadSettings() or {}
	local do_cauldron = settings.cauldronsanity == 1
	local do_fate = settings.fatesanity == 1
	local keyed = H2AP_KeyedIncantations(settings)
	local has_keyed = next(keyed) ~= nil
	if not (do_cauldron or do_fate or has_keyed) then return end

	local location_items = H2AP_ReadLocationItems() or {}

	-- Resolve an incantation key to the AP location name it represents, only
	-- when that key is AP-controlled in the current settings. The 86
	-- cauldronsanity keys are owned by cauldronsanity; the surface 2 and goal 2
	-- are owned by their respective toggles regardless of cauldronsanity.
	local function incantation_location_for(id)
		if keyed[id] then return INCANTATION_LOCATIONS[id] end
		if do_cauldron
			and not H2AP_IsSurfaceLockIncantation(id)
			and not H2AP_IsGoalIncantation(id) then
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
				-- Capture vanilla fields before overwriting so the player can still
				-- see which incantation/prophecy this check is attached to.
				local vanilla_name = entry.DisplayName
				local vanilla_desc = entry.Description
				local opener = (vanilla_name and vanilla_name ~= "") and vanilla_name or display
				local new_desc = "Archipelago location check for " .. opener .. ".\nComplete this in-game to send a check to the Archipelago server."
				if vanilla_desc and vanilla_desc ~= "" then
					new_desc = new_desc .. "\n\nOriginal: " .. vanilla_desc
				end
				entry.DisplayName = display
				entry.Description = new_desc
			else
				local base_id = id:match("^(.-)_Flavor$")
				if base_id and incantation_location_for(base_id) then
					local vanilla_flavor = entry.Description
					local new_desc = "What you receive in exchange is determined by the Archipelago multiworld randomizer."
					if vanilla_flavor and vanilla_flavor ~= "" then
						new_desc = new_desc .. "\n\nOriginal: " .. vanilla_flavor
					end
					entry.Description = new_desc
				end
			end
		end
	end
end

