---@meta _
---@diagnostic disable: lowercase-global

-- Prophecies (Fated List quests): fatesanity location checks, hints and reward delivery.

-- ═══ Data ════════════════════════════════════════════════════════════════════

-- Maps internal Quest ID → AP location name (= Fated List Quest display name + " Check").
PROPHECY_LOCATIONS = {
	["QuestDarkSorceries"]                       = "Gifts of the Moon Check",
	["QuestPurchasePinnedItems"]                 = "Note to Self Check",
	-- QuestRescueFates stages intentionally excluded: the final stage is post-True-Ending and soft-lock-prone.
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
	-- QuestHelpOdysseus intentionally excluded (post-goal gate); its retired AP item ID 114 / location ID 2644 must not be reused.
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

-- Reverse: AP item name ("<location minus ' Check'> Reward") → quest id.
PROPHECY_QUEST_FOR_ITEM = {}
for quest_id, location in pairs(PROPHECY_LOCATIONS) do
	local base = location:gsub(" Check$", "")
	PROPHECY_QUEST_FOR_ITEM[base .. " Reward"] = quest_id
end

-- ═══ Logic ═══════════════════════════════════════════════════════════════════

-- CashOutQuest wrap: under fatesanity, replicate CashOutQuest minus its AddResource, which the AP item delivers instead.
function H2AP_OnCashOutQuest(base, screen, button)
	local settings = H2AP_LoadSettings()
	local questData = button and button.Data
	local quest_name = questData and questData.Name
	local ap_location = quest_name and PROPHECY_LOCATIONS[quest_name]
	if not (settings and settings.fatesanity == 1 and ap_location) then
		return base(screen, button)
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

-- OpenQuestLogScreen wrap: hint each visible prophecy when the Fated List opens.
function H2AP_OnOpenQuestLog(base, args)
	local result = base(args)
	H2AP_HintQuestlogVisible()
	return result
end

-- Hint visible (non-cashed-out) prophecies.
function H2AP_HintQuestlogVisible()
	local settings = H2AP_LoadSettings()
	if not (settings and settings.fatesanity == 1) then return end
	if not (QuestOrderData and QuestData and GameState and GameState.QuestStatus) then return end
	for _, questName in ipairs(QuestOrderData) do
		local questData = QuestData[questName]
		if questData then
			local ap_location = PROPHECY_LOCATIONS[questData.Name]
			if ap_location and GameState.QuestStatus[questData.Name] ~= "CashedOut" then
				if IsGameStateEligible(questData, questData.UnlockGameStateRequirements) then
					H2AP_HintLocation(ap_location)
				end
			end
		end
	end
end

-- Backstop for the CashOutQuest override, catching any cashout that slipped through.
function H2AP_CheckQuestCompletions()
	local settings = H2AP_LoadSettings()
	if not (settings and settings.fatesanity == 1) then return end
	if not (GameState and GameState.QuestStatus) then return end
	for quest_id, location in pairs(PROPHECY_LOCATIONS) do
		if GameState.QuestStatus[quest_id] == "CashedOut" then
			H2AP_CheckLocation(location)
		end
	end
end

-- Prophecy rewards grant the resource the vanilla cashout would have awarded; returns nil when the item isn't a prophecy reward.
function H2AP_ProphecyGiveItem(item_name)
	local quest_id = PROPHECY_QUEST_FOR_ITEM[item_name]
	if not quest_id then return nil end
	local questData = QuestData and QuestData[quest_id]
	local resource = questData and questData.RewardResourceName
	local amount = questData and questData.RewardResourceAmount
	if resource and amount then
		AddResource(resource, amount, _PLUGIN.guid, { SkipVoiceLines = true })
		print("[HadesII_AP] Gave prophecy reward: " .. item_name
			.. " (" .. amount .. "x " .. resource .. ")")
	else
		print("[HadesII_AP] Prophecy reward missing data: " .. item_name
			.. " (quest=" .. tostring(quest_id) .. ")")
	end
	return true
end

-- ═══ Presentation ════════════════════════════════════════════════════════════

-- Replace prophecy names/descriptions in HelpText with the scouted AP item under fatesanity.
function H2AP_ProphecyRelabelHelpText(data)
	local settings = H2AP_LoadSettings() or {}
	if settings.fatesanity ~= 1 then return end
	local location_items = H2AP_ReadLocationItems() or {}
	for _, entry in ipairs(data.Texts) do
		local ap_location = entry.Id and PROPHECY_LOCATIONS[entry.Id]
		if ap_location then
			H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
		end
	end
end
