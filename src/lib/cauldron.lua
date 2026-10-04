---@meta _
---@diagnostic disable: lowercase-global

-- Cauldron incantations: cauldronsanity, surface-lock incantations and the True Ending goal incantations.

-- ═══ Data ════════════════════════════════════════════════════════════════════

-- Maps internal WorldUpgrade key → AP location name (= incantation display name).
INCANTATION_LOCATIONS = {
	["WorldUpgradeSurfacePenaltyCure"]         = "Unraveling a Fateful Bond",
	["WorldUpgradeAltRunDoor"]                 = "Permeation of Witching-Wards",
	["WorldUpgradeQuestLog"]                   = "Fated Intervention",
	["WorldUpgradeMorosUnlock"]                = "Doomed Beckoning",
	["WorldUpgradeNarcissusWaters"]            = "Purification of Crystal Clarity",
	["WorldUpgradeDoraMemory"]                 = "Return of Latent Memories",
	["WorldUpgradeMedeaTears"]                 = "Essence of Sorrow",
	["WorldUpgradeSkellyHealth"]               = "Augmentation of Bone Density",
	["WorldUpgradeWakeHypnos"]                 = "End to Deepest Slumber",
	["WorldUpgradeWakeHypnosT2"]               = "End to Dearest Slumber",
	["WorldUpgradeWakeHypnosT3"]               = "End to Dumbest Slumber",
	["WorldUpgradeWeaponUpgradeSystem"]        = "Aspects of Night and Darkness",
	["WorldUpgradeCardUpgradeSystem"]          = "Consecration of Ashes",
	["WorldUpgradeBountyBoard"]                = "Abyssal Insight",
	["WorldUpgradeBountyBoardRepeat"]          = "Abyssal Reflection",
	["WorldUpgradeFamiliarSystem"]             = "Faith of Familiar Spirits",
	["WorldUpgradeFamiliarUpgradeSystem"]      = "Bravery of Familiar Spirits",
	["WorldUpgradeFamiliarCostumeSystem"]      = "Alteration of Familiar Forms",
	["WorldUpgradeToolUpgradeSystem"]          = "Greater Favor of Gaia",
	["WorldUpgradeBadgeSeller"]                = "Long Arm of the Unseen",
	["WorldUpgradeChangeNextRunRNG"]           = "Acceptance of Another Fate",
	["WorldUpgradeToolsShop"]                  = "Night's Craftwork",
	["WorldUpgradeElementalBoons"]             = "Divination of the Elements",
	["WorldUpgradePinning"]                    = "Forget-Me-Not",
	["WorldUpgradePinningBoons"]               = "Path to Desired Blessings",
	["WorldUpgradeMetaUpgradeSaveLayout"]      = "Spreading of Ashes",
	["WorldUpgradeKeepsakeSaveFirst"]          = "Favored of All Keepsakes",
	["WorldUpgradeResourceFinder"]             = "Reagent Sensing",
	["WorldUpgradeBoonList"]                   = "Insight into Offerings",
	["WorldUpgradeMarket"]                     = "Summoning of Mercantile Fortune",
	["WorldUpgradeSellShop"]                   = "Deathly Fortune",
	["WorldUpgradeGiftsShop"]                  = "Kinship Fortune",
	["WorldUpgradeExchangeShop"]               = "Earthly Fortune",
	["WorldUpgradeBossDifficultyT2"]           = "Rivals of Depth and Sea",
	["WorldUpgradeBossDifficultyT3"]           = "Rivals of Plain and Peak",
	["WorldUpgradeBossDifficultyT4"]           = "Rivals of Old and Rot",
	["WorldUpgradeFountainUpgrade1"]           = "Cleansing of Fountain-Waters",
	["WorldUpgradeFountainUpgrade2"]           = "Purification of Fountain-Waters",
	["WorldUpgradeWellShops"]                  = "Rise of Stygian Wells",
	["WorldUpgradePostBossWellShops"]          = "Surge of Stygian Wells",
	["WorldUpgradeSurfaceShops"]               = "Rush of Fresh Air",
	["WorldUpgradePostBossSurfaceShops"]       = "Surge of Fresh Air",
	["WorldUpgradeRestoreSellTraitShop"]       = "Revival of a Desecrating Pool",
	["WorldUpgradePostBossSellTraitShops"]     = "Surge of Desecrating Pools",
	["WorldUpgradeErebusReprieve"]             = "Woodsy Lifespring",
	["WorldUpgradeOceanusReprieve"]            = "Briny Lifespring",
	["WorldUpgradeTartarusReprieve"]           = "Golden Lifespring",
	["WorldUpgradeThessalyReprieve"]           = "Sandy Lifespring",
	["WorldUpgradeOlympusReprieve"]            = "Frozen Lifespring",
	["WorldUpgradeBreakableValue1"]            = "Propensity Toward Gold",
	["WorldUpgradeEphyraZoomOut"]              = "Summoning a Colony of Bats",
	["WorldUpgradeFieldsRewardFinder"]         = "Reviving a Mournful Husk",
	["WorldUpgradeTimeSlowChronosFight"]       = "Temporal Fluctuation",
	["WorldUpgradePauseChronosFight"]          = "Power to Pause and Reflect",
	["WorldUpgradeUnusedWeaponBonus"]          = "Gathering of Ancient Bones",
	["WorldUpgradeUnusedWeaponBonusT2"]        = "Gathering of Subterranean Riches",
	["WorldUpgradePostBossGiftRack"]           = "Kindred Keepsakes",
	["WorldUpgradeDoubleAdvanceKeepsakes"]     = "Quickening of Sentimental Value",
	["WorldUpgradeOlympusStatues"]             = "Rage of the Elements",
	["WorldUpgradeErebusSafeZones"]            = "Circles of Protection",
	["WorldUpgradeSafeZoneSpellCharge"]        = "Circles of the Moon",
	["WorldUpgradeShadeMercs"]                 = "Necromantic Influence",
	["WorldUpgradeChallengeSwitches1"]         = "Exhumed Troves",
	["WorldUpgradeChallengeSwitchesExtra1"]    = "Eyes of Night and Darkness",
	["WorldUpgradeChallengeSwitchesSurface1"]  = "Arisen Troves",
	["WorldUpgradeMetaRewardStands"]           = "Bounties of the Infinite Abyss",
	["WorldUpgradeMetaCardPointsCommonRunProgress"] = "Ashen Memories of Life",
	["WorldUpgradeMetaCurrencyRunProgress"]    = "Bones of Arcane Wisdom",
	["WorldUpgradeGiftDropRunProgress"]        = "Nectar of Godly Savor",
	["WorldUpgradeTaverna"]                    = "Rite of Social Solidarity",
	["WorldUpgradeBathHouse"]                  = "Rite of Vapor-Cleansing",
	["WorldUpgradeFishingPoint"]               = "Rite of River-Fording",
	["WorldUpgradeHarvestUpgrade"]             = "Observance of Gaia's Secrets",
	["WorldUpgradeGarden"]                     = "Flourishing Soil",
	["WorldUpgradeGardenT2"]                   = "Rich Soil",
	["WorldUpgradeGardenT3"]                   = "Verdant Soil",
	["WorldUpgradeGardenHarvestAll"]           = "Green Hand of Gaia",
	["WorldUpgradeGardenMultiPlant"]           = "Greater Sowing of Gardens",
	["WorldUpgradeAutoHarvestOnExit"]          = "Greatest Gift of Gaia",
	["WorldUpgradeRelationshipBar"]            = "Empath's Intuition",
	["WorldUpgradeMusicPlayer"]                = "Summoning of Musical Rhapsody",
	["WorldUpgradeMusicPlayerShuffle"]         = "Shuffling of Noted Ballads",
	["WorldUpgradeRunHistory"]                 = "Summoning of Historic Travails",
	["WorldUpgradeGameStats"]                  = "Summoning of Personal Insights",
	["WorldUpgradeStoryReset"]                 = "Returning to a Real Possibility",
	["WorldUpgradeErisTrashPickup"]            = "Greater Removal of Rubbish",
	["WorldUpgradeTimeStop"]                   = "Dissolution of Time",
	["WorldUpgradeStormStop"]                  = "Disintegration of Monstrosity",
}

-- Reverse lookup: AP item/location name → WorldUpgrade key (for receiving).
INCANTATION_KEY_FOR_NAME = {}
for key, name in pairs(INCANTATION_LOCATIONS) do
	INCANTATION_KEY_FOR_NAME[name] = key
end

-- Surface-lock incantations are effect-on-receive / check-on-brew; the goal incantations stay vanilla and are only excluded from the cauldronsanity intercept.
SURFACE_LOCK_INCANTATION_KEYS = {
	WorldUpgradeAltRunDoor        = true,
	WorldUpgradeSurfacePenaltyCure = true,
}

GOAL_INCANTATION_KEYS = {
	WorldUpgradeTimeStop  = true,
	WorldUpgradeStormStop = true,
}

-- ═══ Logic ═══════════════════════════════════════════════════════════════════

-- ── Incantation classification ───────────────────────────────────────────────

function H2AP_IsSurfaceLockIncantation(wu_key)
	return SURFACE_LOCK_INCANTATION_KEYS[wu_key] == true
end

function H2AP_IsGoalIncantation(wu_key)
	return GOAL_INCANTATION_KEYS[wu_key] == true
end

-- Build the runtime set of AP-keyed WorldUpgrade keys for the current settings.
function H2AP_KeyedIncantations(settings)
	local out = {}
	if not settings then return out end
	if settings.lock_surface_incantations == 1 then
		for key in pairs(SURFACE_LOCK_INCANTATION_KEYS) do out[key] = true end
	end
	return out
end

function H2AP_IsApKeyedIncantation(wu_key, settings)
	if H2AP_IsSurfaceLockIncantation(wu_key) then
		return settings and settings.lock_surface_incantations == 1 or false
	end
	return false
end

-- True when cauldronsanity intercepts this incantation (the 86 non-special ones).
local function is_cauldronsanity_incantation(wu_key, settings)
	return settings.cauldronsanity == 1
		and not H2AP_IsSurfaceLockIncantation(wu_key)
		and not H2AP_IsGoalIncantation(wu_key)
end

-- True when this incantation is an AP location under the current settings.
local function is_ap_incantation(wu_key, settings)
	return H2AP_IsApKeyedIncantation(wu_key, settings) or is_cauldronsanity_incantation(wu_key, settings)
end

-- ── Surface-lock incantation model (effect-on-receive, check-on-brew) ─────────

-- Widen Moros' reveal requirement so a player already cured by the AP item can still trigger the Unraveling recipe reveal; re-applied each room since the game reloads NamedRequirementsData.
function H2AP_PatchSurfaceIncantationReveal()
	if NamedRequirementsData == nil or NamedRequirementsData._ap_moros_reveal_patched then return end
	local settings = H2AP_LoadSettings() or {}
	if settings.lock_surface_incantations ~= 1 then return end
	-- OrRequirements must sit at the top level; net effect is (cursed OR reached-surface-this-run) AND the untouched clauses.
	NamedRequirementsData.MorosFirstSurfaceAppearance = {
		OrRequirements = {
			{ { Path = { "CurrentRun", "Hero", "TraitDictionary" }, HasAny = { "SurfacePenalty" } } },
			{ { Path = { "CurrentRun", "BiomesReached" }, HasAny = { "N" } } },
		},
		{ PathTrue = { "GameState", "TextLinesRecord", "MorosSecondAppearance" } },
		{ PathFalse = { "CurrentRun", "WorldUpgradesAdded", "WorldUpgradeMorosUnlock" } },
	}
	NamedRequirementsData._ap_moros_reveal_patched = true
end

-- Temporarily mask WorldUpgradesAdded to the AP-checked truth while the cauldron builds its offer list; returns a save-list for the unmask.
local function mask_surface_incantations_for_offer(settings)
	local saved = {}
	if not (GameState and GameState.WorldUpgradesAdded) then return saved end
	local checked = GameState.AP_SurfaceIncantationChecked or {}
	for key in pairs(SURFACE_LOCK_INCANTATION_KEYS) do
		if H2AP_IsApKeyedIncantation(key, settings) then
			saved[#saved + 1] = { key = key, orig = GameState.WorldUpgradesAdded[key] }
			GameState.WorldUpgradesAdded[key] = checked[key] or nil
		end
	end
	return saved
end

local function unmask_surface_incantations(saved)
	if not (GameState and GameState.WorldUpgradesAdded) then return end
	for _, e in ipairs(saved) do
		GameState.WorldUpgradesAdded[e.key] = e.orig
	end
end

-- ── Goal incantations (True Ending) ──────────────────────────────────────────

-- Rewrite the goal incantations' brewing costs to match the per-seed thresholds.
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

-- Keep Dissolution of Time un-brewable until Typhon is genuinely defeated with Storm Stop (the AP Entropy grant removed vanilla's implicit gate).
function H2AP_PatchGoalIncantationGate()
	if WorldUpgradeData == nil then return end
	local settings = H2AP_LoadSettings() or {}
	if settings.true_ending ~= 1 then return end
	local d = WorldUpgradeData["WorldUpgradeTimeStop"]
	if d and not d._ap_te_gate_patched then
		d.GameStateRequirements = d.GameStateRequirements or {}
		table.insert(d.GameStateRequirements, {
			PathTrue = { "GameState", "AP_TyphonKilledWithStormStop" },
		})
		d._ap_te_gate_patched = true
	end
end

-- Record an un-fakeable "Typhon beaten with Storm Stop" flag; vanilla's TyphonDefeatedWithStormStop can't be trusted since the Entropy grant fakes it.
function H2AP_RecordStormStopKill(boss_key)
	if boss_key == "typhon"
			and GameState and GameState.WorldUpgradesAdded
			and GameState.WorldUpgradesAdded.WorldUpgradeStormStop then
		GameState.AP_TyphonKilledWithStormStop = true
	end
end

-- ── Brewing (location check) ─────────────────────────────────────────────────

-- HandleGhostAdminPurchase wrap: surface-lock and cauldronsanity brews send the AP check and suppress the vanilla effect, everything else runs vanilla.
function H2AP_OnCauldronPurchase(base, screen, button)
	local settings = H2AP_LoadSettings()
	local itemData = button and button.Data
	if not (settings and itemData) then return base(screen, button) end

	local wu_key = itemData.Name
	local ap_location = INCANTATION_LOCATIONS[wu_key]
	if not ap_location then return base(screen, button) end

	-- Broker is granted for free when unlock_broker is on, so a stray re-brew runs vanilla.
	if settings.unlock_broker == 1 and wu_key == "WorldUpgradeMarket" then
		return base(screen, button)
	end

	-- Surface-lock: brewing is the location check; the effect comes from the AP item, so suppress the vanilla grant.
	if H2AP_IsApKeyedIncantation(wu_key, settings) then
		GhostAdminItemPurchasedPresentation(button, itemData)
		GameState.AP_SurfaceIncantationChecked = GameState.AP_SurfaceIncantationChecked or {}
		GameState.AP_SurfaceIncantationChecked[wu_key] = true
		-- Set the "brewed" record for AltRunDoor only; SurfacePenaltyCure's flag IS its cure effect and must stay unset until the AP item arrives.
		if wu_key == "WorldUpgradeAltRunDoor" then
			GameState.WorldUpgradesAdded[wu_key] = true
			if CurrentRun and CurrentRun.WorldUpgradesAdded then
				CurrentRun.WorldUpgradesAdded[wu_key] = true
			end
		end
		CloseGhostAdminScreen(screen, screen.Components.CloseButton, {})
		H2AP_CheckLocation(ap_location)
		H2AP_ShowCheckSentBanner()
		return
	end

	-- Cauldronsanity: intercept the 86 non-special incantations.
	if is_cauldronsanity_incantation(wu_key, settings) then
		GhostAdminItemPurchasedPresentation(button, itemData)
		if GameState then
			GameState.WorldUpgradesAdded[wu_key] = true
		end
		if CurrentRun then
			CurrentRun.WorldUpgradesAdded[wu_key] = true
		end
		CloseGhostAdminScreen(screen, screen.Components.CloseButton, {})
		H2AP_CheckLocation(ap_location)
		H2AP_ShowCheckSentBanner()
		return
	end

	return base(screen, button)
end

-- GhostAdminDisplayCategory wrap: mask surface-lock incantations to their AP-checked state while the offer list builds, then hint every visible incantation.
function H2AP_OnCauldronDisplayCategory(base, screen, button)
	local settings = H2AP_LoadSettings()
	local masked = settings and mask_surface_incantations_for_offer(settings) or nil
	base(screen, button)
	if masked then unmask_surface_incantations(masked) end
	H2AP_HintCauldronVisible(screen)
end

-- Hint every visible AP-controlled incantation on category display.
function H2AP_HintCauldronVisible(screen)
	local settings = H2AP_LoadSettings()
	if not settings then return end
	local do_cauldron = settings.cauldronsanity == 1
	local keyed = H2AP_KeyedIncantations(settings)
	if not (do_cauldron or next(keyed)) then return end
	if not (screen and screen.AvailableItems) then return end
	for _, itemData in ipairs(screen.AvailableItems) do
		local name = itemData and itemData.Name
		local ap_location = name and INCANTATION_LOCATIONS[name]
		-- Hint AP-keyed incantations always, the other 86 only under cauldronsanity.
		if ap_location and is_ap_incantation(name, settings) then
			H2AP_HintLocation(ap_location)
		end
	end
end

-- ── Receiving (incantation effect) ───────────────────────────────────────────

-- Incantations deliver their effect from the received AP item; returns nil when the item isn't an incantation.
function H2AP_CauldronGiveItem(item_name)
	local wu_key = INCANTATION_KEY_FOR_NAME[item_name]
	if not wu_key then return nil end
	local settings = H2AP_LoadSettings()
	if H2AP_IsApKeyedIncantation(wu_key, settings) then
		-- Surface-lock: grant only WorldUpgrades so the brew/story sequence stays alive; SurfacePenaltyCure also needs WorldUpgradesAdded since part of its cure is gated on it.
		GameState.WorldUpgrades[wu_key]       = true
		GameState.WorldUpgradesViewed[wu_key] = true
		if wu_key == "WorldUpgradeSurfacePenaltyCure" then
			GameState.WorldUpgradesAdded[wu_key]    = true
			GameState.WorldUpgradesRevealed[wu_key] = true
			if CurrentRun and CurrentRun.WorldUpgradesAdded then
				CurrentRun.WorldUpgradesAdded[wu_key] = true
			end
		end
		print("[HadesII_AP] Incantation effect granted: " .. item_name)
		return true
	end
	-- Cauldronsanity 86: apply effect directly (vanilla brew is suppressed).
	GameState.WorldUpgrades[wu_key]         = true
	GameState.WorldUpgradesAdded[wu_key]    = true
	GameState.WorldUpgradesViewed[wu_key]   = true
	GameState.WorldUpgradesRevealed[wu_key] = true
	local itemData = WorldUpgradeData and WorldUpgradeData[wu_key]
	if itemData and itemData.OnActivateFinishedFunctionName then
		pcall(CallFunctionName, itemData.OnActivateFinishedFunctionName, itemData.OnActivateFinishedFunctionArgs)
	end
	print("[HadesII_AP] Incantation unlocked: " .. item_name)
	return true
end

-- ═══ Presentation ════════════════════════════════════════════════════════════

-- Show the Archipelago logo instead of per-spell artwork on every AP-controlled incantation.
function H2AP_PatchIncantationIcons()
	if WorldUpgradeData == nil then return end
	local settings = H2AP_LoadSettings() or {}
	for key, _ in pairs(INCANTATION_LOCATIONS) do
		local data = WorldUpgradeData[key]
		if data and is_ap_incantation(key, settings) then
			data.Icon = AP_ICON_ANIM
		end
	end
end

-- Replace AP-controlled incantation names/descriptions in HelpText, blanking their flavor text down to the vanilla original.
function H2AP_CauldronRelabelHelpText(data)
	local settings = H2AP_LoadSettings() or {}
	if not (settings.cauldronsanity == 1 or next(H2AP_KeyedIncantations(settings))) then return end
	local location_items = H2AP_ReadLocationItems() or {}
	for _, entry in ipairs(data.Texts) do
		local id = entry.Id
		if id then
			if INCANTATION_LOCATIONS[id] and is_ap_incantation(id, settings) then
				H2AP_ApplyApLocationLabel(entry, INCANTATION_LOCATIONS[id], location_items)
			else
				local base_id = id:match("^(.-)_Flavor$")
				if base_id and INCANTATION_LOCATIONS[base_id] and is_ap_incantation(base_id, settings) then
					local new_desc = ""
					local vanilla_flavor = entry.Description
					if vanilla_flavor and vanilla_flavor ~= "" then
						new_desc = "\n\nOriginal: " .. vanilla_flavor
					end
					entry.Description = new_desc
				end
			end
		end
	end
end
