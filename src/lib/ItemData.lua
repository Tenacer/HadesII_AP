---@meta _
---@diagnostic disable: lowercase-global

-- ── Filler items ──────────────────────────────────────────────────────────────

-- Key = AP item name (as written in items.csv).
-- resource = internal AddResource name.
-- setting  = slot-data key for how much to grant per pack.
FILLER_ITEMS = {
	["Ash"]        = { resource = "MetaCardPointsCommon", setting = "ash_pack_value" },
	["Psyche"]     = { resource = "MemPointsCommon",      setting = "psyche_pack_value" },
	["Bones"]      = { resource = "MetaCurrency",         setting = "bones_pack_value" },
	["Nightmare"]  = { resource = "WeaponPointsRare",     setting = "nightmare_pack_value" },
	["Nectar"]     = { resource = "GiftPoints",           setting = "nectar_pack_value" },
	["Ambrosia"]   = { resource = "GiftPointsRare",       setting = "ambrosia_pack_value" },
	["Fate Fabric"]= { resource = "MetaFabric",           setting = "fate_fabric_pack_value" },
	["Moon Dust"]  = { resource = "CardUpgradePoints",    setting = "moon_dust_pack_value" },
}

-- ── Keepsake tables ───────────────────────────────────────────────────────────

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

-- ── Story meeting flags ───────────────────────────────────────────────────────

-- One flag injected per Zodiac Sand received, in order.
-- Meeting05 is reserved for Gigaros (see story.lua).
ZAGREUS_MEETING_FLAGS = {
	"ZagreusPastMeeting02",
	"ZagreusPastMeeting02_2",
	"ZagreusPastMeeting03",
	"ZagreusPastMeeting04",
	"ZagreusPastMeeting04_2",
	"ZagreusPastMeeting04_3",
}

-- One flag injected per Void Lens received, in order.
ZEUS_MEETING_FLAGS = {
	"ZeusPalaceMeeting02",
	"ZeusPalaceMeeting03_A",
	"ZeusPalaceMeeting04",
	"ZeusPalaceMeeting04_B",
}
