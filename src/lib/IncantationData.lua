---@meta _
---@diagnostic disable: lowercase-global

-- ── Incantation locations ─────────────────────────────────────────────────────

-- Maps internal WorldUpgrade key → AP location name (= incantation display name).
-- Used to intercept cauldron completions and to apply effects when received.
-- Generated from HelpText.en.sjson cross-referenced with locations.csv.
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

-- ── AP-keyed (surface-lock) incantations ─────────────────────────────────────
-- The surface-unlock incantations (WorldUpgradeAltRunDoor +
-- WorldUpgradeSurfacePenaltyCure) are "AP-keyed" under `lock_surface_incantations`
-- (independent of `cauldronsanity`). Their model: the received AP item delivers
-- the incantation EFFECT (items.lua), and brewing the recipe fires the AP
-- location CHECK with the vanilla effect suppressed (ready.lua) — the same
-- intercept as cauldronsanity, except the recipe is revealed by the vanilla
-- Hermes/Hecate (door) and Moros (penalty cure) story rather than the AP item.
-- See reload.lua's H2AP_PatchSurfaceIncantationReveal +
-- H2AP_MaskSurfaceIncantationsForOffer for the two support pieces that keep the
-- reveal and the cauldron offer working once the effect is granted early.
--
-- The goal incantations (WorldUpgradeTimeStop + WorldUpgradeStormStop) are NOT
-- AP-keyed: under true_ending they brew via the vanilla cauldron flow, gated
-- only by their (patched) ingredient costs — see H2AP_PatchIncantationCosts.
-- GOAL_INCANTATION_KEYS / H2AP_IsGoalIncantation are kept solely to keep those
-- two out of the cauldronsanity icon/intercept so they stay vanilla even when
-- cauldronsanity is on.
SURFACE_LOCK_INCANTATION_KEYS = {
	WorldUpgradeAltRunDoor        = true,
	WorldUpgradeSurfacePenaltyCure = true,
}

GOAL_INCANTATION_KEYS = {
	WorldUpgradeTimeStop  = true,
	WorldUpgradeStormStop = true,
}

function H2AP_IsSurfaceLockIncantation(wu_key)
	return SURFACE_LOCK_INCANTATION_KEYS[wu_key] == true
end

function H2AP_IsGoalIncantation(wu_key)
	return GOAL_INCANTATION_KEYS[wu_key] == true
end

-- Build the runtime set of AP-keyed WorldUpgrade keys based on the current
-- settings dict. Caller passes an `H2AP_LoadSettings()` result (or nil for an
-- empty result). Returns a set keyed by WorldUpgrade name.
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

-- True Ending ordering gate: keep Dissolution of Time (WorldUpgradeTimeStop)
-- un-brewable in the cauldron until the player has genuinely defeated Typhon with
-- Disintegration of Monstrosity active. Vanilla enforced this implicitly — Time
-- Stop's recipe needs Entropy, which only drops from that kill — but the AP mod
-- hands Entropy out as a free item (items.lua) and fakes
-- GameState.TyphonDefeatedWithStormStop (story.lua), so the implicit gate is gone.
-- We re-add it explicitly, keyed on AP_TyphonKilledWithStormStop, which is set
-- ONLY on the real in-game kill (score.lua's H2AP_OnRoomCleared) and is never
-- touched by the Entropy grant.
--
-- Installed once at ready_late startup — GameStateRequirements survive App.Reset
-- (unlike the Icon fields that force the other incantation patches to re-run in
-- the SetupMap wrap), so this deliberately does NOT ride that per-room path.
-- Idempotent via the `_ap_te_gate_patched` sentinel regardless.
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
