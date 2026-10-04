---@meta _
---@diagnostic disable: lowercase-global

-- Keepsakes: keepsakesanity gifting checks and keepsake item delivery.

-- ═══ Data ════════════════════════════════════════════════════════════════════

-- Maps AP item name → internal Gift ID for direct GameState unlock on receive.
KEEPSAKE_GIFT_IDS = {
	["Hecate Keepsake"]           = "ManaOverTimeRefundKeepsake",
	["Odysseus Keepsake"]         = "BossPreDamageKeepsake",
	["Schelemeus Keepsake"]       = "ReincarnationKeepsake",
	["Dora Keepsake"]             = "DoorHealReserveKeepsake",
	["Nemesis Keepsake"]          = "DeathVengeanceKeepsake",
	["Moros Keepsake"]            = "BlockDeathKeepsake",
	["Eris Keepsake"]             = "EscalatingKeepsake",
	["Charon Keepsake"]           = "BonusMoneyKeepsake",
	["Hermes Keepsake"]           = "TimedBuffKeepsake",
	["Artemis Keepsake"]          = "LowHealthCritKeepsake",
	["Selene Keepsake"]           = "SpellTalentKeepsake",
	["Zeus Keepsake"]             = "ForceZeusBoonKeepsake",
	["Hera Keepsake"]             = "ForceHeraBoonKeepsake",
	["Poseidon Keepsake"]         = "ForcePoseidonBoonKeepsake",
	["Demeter Keepsake"]          = "ForceDemeterBoonKeepsake",
	["Apollo Keepsake"]           = "ForceApolloBoonKeepsake",
	["Aphrodite Keepsake"]        = "ForceAphroditeBoonKeepsake",
	["Hephaestus Keepsake"]       = "ForceHephaestusBoonKeepsake",
	["Hestia Keepsake"]           = "ForceHestiaBoonKeepsake",
	["Ares Keepsake"]             = "ForceAresBoonKeepsake",
	["Athena Keepsake"]           = "AthenaEncounterKeepsake",
	["Dionysus Keepsake"]         = "SkipEncounterKeepsake",
	["Arachne Keepsake"]          = "ArmorGainKeepsake",
	["Narcissus Keepsake"]        = "FountainRarityKeepsake",
	["Echo Keepsake"]             = "UnpickedBoonKeepsake",
	["Heracles Keepsake"]         = "DecayingBoostKeepsake",
	["Medea Keepsake"]            = "DamagedDamageBoostKeepsake",
	["Circe Keepsake"]            = "BossMetaUpgradeKeepsake",
	["Icarus Keepsake"]           = "TempHammerKeepsake",
	["Chaos Keepsake"]            = "RandomBlessingKeepsake",
	-- post-ending keepsakes: items only, no corresponding AP location check
	["Zagreus Keepsake"]          = "RarifyKeepsake",
	["Hades/Persephone Keepsake"] = "HadesAndPersephoneKeepsake",
	["Chronos Keepsake"]          = "GoldifyKeepsake",
}

-- Reverse map: Gift ID → AP location name for keepsakesanity location checks.
-- Post-ending keepsakes (no AP location) are intentionally absent.
KEEPSAKE_LOCATION_FOR_GIFT = {
	["ManaOverTimeRefundKeepsake"]  = "Hecate Keepsake",
	["BossPreDamageKeepsake"]       = "Odysseus Keepsake",
	["ReincarnationKeepsake"]       = "Schelemeus Keepsake",
	["DoorHealReserveKeepsake"]     = "Dora Keepsake",
	["DeathVengeanceKeepsake"]      = "Nemesis Keepsake",
	["BlockDeathKeepsake"]          = "Moros Keepsake",
	["EscalatingKeepsake"]          = "Eris Keepsake",
	["BonusMoneyKeepsake"]          = "Charon Keepsake",
	["TimedBuffKeepsake"]           = "Hermes Keepsake",
	["LowHealthCritKeepsake"]       = "Artemis Keepsake",
	["SpellTalentKeepsake"]         = "Selene Keepsake",
	["ForceZeusBoonKeepsake"]       = "Zeus Keepsake",
	["ForceHeraBoonKeepsake"]       = "Hera Keepsake",
	["ForcePoseidonBoonKeepsake"]   = "Poseidon Keepsake",
	["ForceDemeterBoonKeepsake"]    = "Demeter Keepsake",
	["ForceApolloBoonKeepsake"]     = "Apollo Keepsake",
	["ForceAphroditeBoonKeepsake"]  = "Aphrodite Keepsake",
	["ForceHephaestusBoonKeepsake"] = "Hephaestus Keepsake",
	["ForceHestiaBoonKeepsake"]     = "Hestia Keepsake",
	["ForceAresBoonKeepsake"]       = "Ares Keepsake",
	["AthenaEncounterKeepsake"]     = "Athena Keepsake",
	["SkipEncounterKeepsake"]       = "Dionysus Keepsake",
	["ArmorGainKeepsake"]           = "Arachne Keepsake",
	["FountainRarityKeepsake"]      = "Narcissus Keepsake",
	["UnpickedBoonKeepsake"]        = "Echo Keepsake",
	["DecayingBoostKeepsake"]       = "Heracles Keepsake",
	["DamagedDamageBoostKeepsake"]  = "Medea Keepsake",
	["BossMetaUpgradeKeepsake"]     = "Circe Keepsake",
	["TempHammerKeepsake"]          = "Icarus Keepsake",
	["RandomBlessingKeepsake"]      = "Chaos Keepsake",
}

-- ═══ Logic ═══════════════════════════════════════════════════════════════════

-- Replace AP-mapped keepsake gift-level prerequisites with an AP_KeepsakeChecked guard so gifting works without story dialogue; unmapped (post-ending) gifts keep vanilla requirements.
function H2AP_PatchKeepsakeGiftRequirements()
	for npcName, npcData in pairs(GiftData) do
		if type(npcData) == "table" then
			for i = 1, #npcData do
				local entry = npcData[i]
				if entry and entry.Gift and KEEPSAKE_LOCATION_FOR_GIFT[entry.Gift] then
					entry.GameStateRequirements = {
						{ PathFalse = { "GameState", "AP_KeepsakeChecked", entry.Gift } },
					}
				end
			end
		end
	end
end

-- PlayerReceivedGiftPresentation wrap: undo the vanilla keepsake grant, send the check, and flag AP_KeepsakeChecked so GiftLogic doesn't re-fire this presentation.
function H2AP_OnKeepsakeGifted(base, npc, giftName)
	local settings = H2AP_LoadSettings()
	if settings and settings.keepsakesanity == 1 then
		local location = KEEPSAKE_LOCATION_FOR_GIFT[giftName]
		if location then
			GameState.GiftPresentation[giftName] = nil
			GameState.NewKeepsakeItem[giftName]  = nil
			GameState.AP_KeepsakeChecked = GameState.AP_KeepsakeChecked or {}
			GameState.AP_KeepsakeChecked[giftName] = true
			H2AP_ShowKeepsakeCheckBanner(npc)
			H2AP_CheckLocation(location)
			return
		end
	end
	return base(npc, giftName)
end

-- CreateKeepsakeIcon wrap: the rack screen computes Unlocked from the (emptied) GiftData requirements, so recompute it from GiftPresentation / AP receipt.
function H2AP_OnCreateKeepsakeIcon(base, screen, components, args)
	local settings = H2AP_LoadSettings()
	if settings and args and args.UpgradeData and args.UpgradeData.Gift then
		local gift_id = args.UpgradeData.Gift
		local from_gift = (GameState.GiftPresentation[gift_id] == true)
		local from_ap   = (GameState.AP_KeepsakeReceived
			and GameState.AP_KeepsakeReceived[gift_id] == true)
		args.UpgradeData.Unlocked = from_gift or from_ap
	end
	return base(screen, components, args)
end

-- Keepsakes: track the AP unlock in AP_KeepsakeReceived so GiftPresentation stays clear and the gifting check remains reachable; returns nil for other items.
function H2AP_KeepsakeGiveItem(item_name)
	local gift_id = KEEPSAKE_GIFT_IDS[item_name]
	if not gift_id then return nil end
	GameState.AP_KeepsakeReceived = GameState.AP_KeepsakeReceived or {}
	GameState.AP_KeepsakeReceived[gift_id] = true
	print("[HadesII_AP] Gave keepsake: " .. item_name)
	return true
end

-- ═══ Presentation ════════════════════════════════════════════════════════════

-- Show the AP logo banner when a keepsake gifting location check fires.
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
