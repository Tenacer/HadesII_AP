---@meta _
---@diagnostic disable: lowercase-global

-- ── Prophecy (Fated List Quest) locations ─────────────────────────────────────

-- Maps internal Quest ID → AP location name (= Fated List Quest display name + " Check").
-- Used in sjson_HelpText to patch DisplayName + Description for prophecy entries
-- when fatesanity is on. Generated from HelpText.en.sjson Quest* entries
-- cross-referenced with locations.csv (category = "prophecy").
PROPHECY_LOCATIONS = {
	["QuestDarkSorceries"]                       = "Gifts of the Moon Check",
	["QuestPurchasePinnedItems"]                 = "Note to Self Check",
	-- QuestRescueFates / *PostTrueEnding / *Progress / *True intentionally
	-- excluded: it's a single QuestData entry whose Name field rotates through
	-- 4 stages via SetupEvents, and the final Find Us stage requires the
	-- post-True-Ending FatesEpilogue01 text-line — i.e. post-goal, soft-lock-prone.
	["QuestZeusUpgrades"]                        = "Master of the Heavens Check",
	["QuestPoseidonUpgrades"]                    = "Master of the Sea Check",
	["QuestApolloUpgrades"]                      = "Master of Light Check",
	["QuestDemeterUpgrades"]                     = "Mistress of Seasons Check",
	["QuestHestiaUpgrades"]                      = "Mistress of the Hearth Check",
	["QuestAphroditeUpgrades"]                   = "Mistress of Beauty Check",
	["QuestHephaestusUpgrades"]                  = "Master of the Forge Check",
	["QuestHeraUpgrades"]                        = "Mistress of Wedlock Check",
	["QuestHermesUpgrades"]                      = "Master of Swiftness Check",
	["QuestAresUpgrades"]                        = "Master of War Check",
	["QuestArtemisUpgrades"]                     = "Mistress of the Hunt Check",
	["QuestAthenaUpgrades"]                      = "Mistress of Battle Check",
	["QuestDionysusUpgrades"]                    = "Master of Revelry Check",
	["QuestChaosBlessings"]                      = "Original Virtues Check",
	["QuestChaosCurses"]                         = "Original Sins Check",
	["QuestHadesUpgrades"]                       = "Master of the Dead Check",
	["QuestSynergyUpgrades"]                     = "Combined Might Check",
	["QuestSeleneDuos"]                          = "Godsent Favor Check",
	["QuestLegendaryUpgrades"]                   = "Power Beyond Legend Check",
	["QuestArachneUpgrades"]                     = "Weaver of Fineries Check",
	["QuestNarcissusUpgrades"]                   = "Denier of Suitors Check",
	["QuestEchoUpgrades"]                        = "Voice of Truth Check",
	["QuestMedeaCurses"]                         = "Witch of Shadows Check",
	["QuestCirceUpgrades"]                       = "Witch of Changing Check",
	["QuestIcarusUpgrades"]                      = "Wings of Freedom Check",
	["QuestStaffHammerUpgrades"]                 = "The Witch's Staff Check",
	["QuestDaggerHammerUpgrades"]                = "The Sister Blades Check",
	["QuestTorchHammerUpgrades"]                 = "The Umbral Flames Check",
	["QuestAxeHammerUpgrades"]                   = "The Moonstone Axe Check",
	["QuestLobHammerUpgrades"]                   = "The Argent Skull Check",
	["QuestSuitHammerUpgrades"]                  = "The Black Coat Check",
	["QuestWellShopItems"]                       = "Valued Customer Check",
	["QuestMaxWeaponUpgrade"]                    = "Awakened Aspect Check",
	["QuestMeetOlympians"]                       = "Family in Need Check",
	["QuestUnlockMoros"]                         = "Harbinger of Doom Check",
	["QuestPetFrog"]                             = "Familiar Confidant Check",
	["QuestMeetCyclopsWithOdysseusKeepsake"]     = "Nobody but Nobody Check",
	-- QuestHelpOdysseus intentionally excluded: UnlockGameStateRequirements
	-- requires ReachedTrueEnding (post-goal in TrueEnding mode, unreachable in
	-- BossDefeats mode). Same precedent as the removed RescueFates stages —
	-- AP item ID 114 and location ID 2644 retired (do not reuse).
	["QuestHelpArachne"]                         = "Silk and Spitefulness Check",
	["QuestHelpNarcissusAndEcho"]                = "Voice and Vanity Check",
	["QuestHelpDora"]                            = "Haunted by the Past Check",
	["QuestWakeHypnos"]                          = "Soundest of Slumbers Check",
	["QuestHelpMedea"]                           = "Bitter Tears Check",
	["QuestHelpCirce"]                           = "Drowned Ambitions Check",
	["QuestUnlockBountyBoard"]                   = "Visions of Victory Check",
	["QuestClearBountiesSmall"]                  = "Whims of Chaos Check",
	["QuestShadeMercRecruits"]                   = "Spectral Forms Check",
	["QuestCauldronSpellsSmall"]                 = "The Invoker Check",
	["QuestCatchFish"]                           = "Denizen of the Depths Check",
	["QuestRecruitFamiliars"]                    = "Close Companions Check",
	["QuestUpgradeFamiliars"]                    = "Beyond Familiar Check",
	["QuestCodexSmall"]                          = "Keeper of Shadows Check",
	["QuestCosmeticsSmall"]                      = "Home in the Crossroads Check",
	["QuestToolsUnlocks"]                        = "Tools of the Unseen Check",
	["QuestToolsUpgrades"]                       = "Precision Instrument Check",
	["QuestUnlockAllCards"]                      = "Breadth of Knowledge Check",
	["QuestMaxCardUpgrade"]                      = "Major Arcana Check",
	["QuestBeatHecate"]                          = "Witch of the Crossroads Check",
	["QuestBeatHecateWithoutArcana"]             = "Natural Talent Check",
	["QuestFirstUnderworldClear"]                = "Temporary Setback Check",
	["QuestFirstSurfaceClear"]                   = "Storm in the Heavens Check",
	["QuestChaosKeepsakeFullRun"]                = "Born to Win Check",
	["QuestRandomBountyClearStreak"]             = "Improbable Outcomes Check",
	["QuestBeatChronosWithArcana"]               = "Arcana of the Ages Check",
	["QuestBeatTyphonWithWeapons"]               = "Sword of the Night Check",
	["QuestClearedWithAllAspects"]               = "Bearing Dark Gifts Check",
	["QuestClearedWithAllFamiliars"]             = "Den Mother Check",
	["QuestMeetShrineAltBosses"]                 = "Unrivaled Prowess Check",
	["QuestDeliverAnubisAspect"]                 = "The Jackal's Aspect Check",
	["QuestDeliverMorriganAspect"]               = "The Crow's Aspect Check",
	["QuestDeliverSupayAspect"]                  = "The Shadow's Aspect Check",
	["QuestDeliverNergalAspect"]                 = "The Warrior's Aspect Check",
	["QuestDeliverHelAspect"]                    = "The Grave's Aspect Check",
	["QuestDeliverShivaAspect"]                  = "The Destroyer's Aspect Check",
	["QuestMiniBossKills"]                       = "Shadow of Death Check",
	["QuestMiniBossKillsSurface"]                = "Shadow of Doom Check",
	["QuestUnlockDagger"]                        = "Blades of Pure Silver Check",
	["QuestUnlockAllWeapons"]                    = "The Arms of Night Check",
	["QuestUnlockAllWeaponAspects"]              = "The Unseen Sentinel Check",
	["QuestSpendCharonPoints"]                   = "Weight in Gold Check",
	["QuestGiftNectar"]                          = "Customary Gift Check",
	["QuestMemLevel10"]                          = "Mindful Craft Check",
	["QuestEliteAttributeKills"]                 = "Bared Fangs Check",
}

-- Reverse: AP item name → quest id. Item names follow the pattern
-- "<location minus ' Check'> Reward" — see worlds/hades_ii/data/items.csv.
PROPHECY_QUEST_FOR_ITEM = {}
for quest_id, location in pairs(PROPHECY_LOCATIONS) do
	local base = location:gsub(" Check$", "")
	PROPHECY_QUEST_FOR_ITEM[base .. " Reward"] = quest_id
end
