---@meta _
---@diagnostic disable: lowercase-global

-- Hooks set up once at startup. The AP-icon and SJSON-label helpers they call
-- are still defined in reload.lua so those (text/icon) logic tweaks can be
-- hot-reloaded; the library modules below are pure definitions, so they are
-- imported here (loaded once, survive App.Reset) rather than from reload.lua,
-- where they would needlessly re-run on every hot-reload. The two library files
-- with import-time side effects (lib/rivals.lua, lib/weapons.lua) are imported
-- from ready_late.lua so their installs run exactly once.

-- ── Library modules (pure definitions) ────────────────────────────────────────

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
import 'lib/tools.lua'
import 'lib/familiar.lua'
import 'lib/traphelper.lua'
import 'lib/broker.lua'
import 'lib/items.lua'
import 'lib/score.lua'
import 'lib/death.lua'
import 'lib/inbox.lua'

-- ── AP icon package ──────────────────────────────────────────────────────────

-- Load our custom texture package (Tenacer_AP-HadesII_AP.pkg) so the AP icon
-- animation is available. Hell2Modding auto-registers it; LoadPackages activates it.
local ap_icon_pkg = rom.path.combine(_PLUGIN.plugins_data_mod_folder_path, _PLUGIN.guid)
LoadPackages({ Name = ap_icon_pkg })

-- ── Text patches ──────────────────────────────────────────────────────────────

local file = rom.path.combine(rom.paths.Content, 'Game/Text/en/ShellText.en.sjson')
sjson.hook(file, function(data)
	return sjson_ShellText(data)
end)

local helpfile = rom.path.combine(rom.paths.Content, 'Game/Text/en/HelpText.en.sjson')
sjson.hook(helpfile, function(data)
	return sjson_HelpText(data)
end)

-- Weapon / tool / hidden-aspect shop labels live in TraitText, not HelpText.
local traitfile = rom.path.combine(rom.paths.Content, 'Game/Text/en/TraitText.en.sjson')
sjson.hook(traitfile, function(data)
	return sjson_TraitText(data)
end)

-- ── Debug keybind ─────────────────────────────────────────────────────────────

-- Press the Gift button to receive a test Ash pack (verifies IPC and AddResource).
-- game.OnControlPressed({'Gift', function()
-- 	H2AP_GiveItem("Ash")
-- end})

-- ── Room / map hooks ─────────────────────────────────────────────────────────
-- Note: the SetupMap and OnAllEnemiesDead wraps live in ready_late.lua so they
-- register after on_all_mods_loaded — several other installed mods (DamageMeter,
-- Cosmetics_API, MelSkin, SharedKeepsakePort, PonyMenu) also hook SetupMap, and
-- late registration keeps our wrap's position in the chain deterministic
-- (see ModUtil issue #12). KillHero is moved there too for the same reason.

-- Boss reward dispatcher. Branches on H2AP_BossRewardAction (set in lib/score.lua):
--   ap_check  → spawn an interactable for the AP item placed at this location
--               (resource-obstacle visual when local + recognised, AP icon
--               otherwise). The AP check fires when the player picks it up.
--   fallback  → past per-boss kill count; spawn Nightmare + Gemstones drops
--   vanilla   → BossDefeats mode (or non-boss room); let vanilla reward through
modutil.mod.Path.Wrap("SpawnRoomReward", function(base, eventSource, args)
	local currentRoom = CurrentRun and CurrentRun.CurrentRoom
	local action = H2AP_BossRewardAction(currentRoom)
	if action == "ap_check" then
		local boss_key = H2AP_BossForRoom(currentRoom)
		local ap_location = H2AP_BossCurrentLocationName(boss_key)
		if ap_location then
			print("[HadesII_AP] Spawning boss-reward pickup for " .. ap_location)
			H2AP_SpawnApBossReward(ap_location)
		end
		return
	end
	if action == "fallback" then
		print("[HadesII_AP] Boss kills past AP-check range — spawning Nightmare + Gemstones drops")
		H2AP_SpawnConsumableDrop("WeaponPointsRareDrop", 30,  110)
		H2AP_SpawnConsumableDrop("GemPointsBigDrop",     150, 110)
		return
	end
	return base(eventSource, args)
end)

-- ── Cauldron interception ────────────────────────────────────────────────────

-- Three-way dispatch on the brewed incantation:
--  1. Surface-lock (AP-keyed under lock_surface_incantations): brewing is the AP
--     location CHECK. The effect was delivered by the received AP item
--     (items.lua), so we suppress the vanilla brew effect (no base()) and mark
--     AP_SurfaceIncantationChecked — exactly like cauldronsanity, but the recipe
--     is revealed by the vanilla Moros/Hermes story rather than the AP item.
--  2. Cauldronsanity (the 86 non-special incantations): intercept and suppress
--     the vanilla effect. The AP item delivers the effect when received.
--     We don't call base() because CloseGhostAdminScreen with the purchase
--     button takes the incantation-animation branch (no camera pan); instead
--     we replicate only what we need and pass screen.Components.CloseButton so
--     the camera correctly returns to Melinoë.
--  3. Otherwise: vanilla, no AP involvement.
modutil.mod.Path.Wrap("HandleGhostAdminPurchase", function(base, screen, button)
	local settings = H2AP_LoadSettings()
	local itemData = button and button.Data
	if not (settings and itemData) then return base(screen, button) end

	local wu_key = itemData.Name
	local ap_location = INCANTATION_LOCATIONS[wu_key]
	if not ap_location then return base(screen, button) end

	-- Broker is granted for free at start when unlock_broker is on, so it's
	-- never an AP location. The cauldron won't offer an already-brewed
	-- incantation, but guard anyway so a stray re-brew runs vanilla, not AP.
	if settings.unlock_broker == 1 and wu_key == "WorldUpgradeMarket" then
		return base(screen, button)
	end

	-- Surface-lock: brewing IS the location check; the effect comes from the AP
	-- item (items.lua), so suppress the vanilla WorldUpgrade grant (no base()) —
	-- otherwise brewing alone would unlock the surface, defeating the shuffle.
	-- AP_SurfaceIncantationChecked records that the check fired so the cauldron
	-- offer mask (GhostAdminDisplayCategory wrap) demotes the recipe to "brewed"
	-- and never re-fires the check.
	if H2AP_IsApKeyedIncantation(wu_key, settings) then
		GhostAdminItemPurchasedPresentation(button, itemData)
		GameState.AP_SurfaceIncantationChecked = GameState.AP_SurfaceIncantationChecked or {}
		GameState.AP_SurfaceIncantationChecked[wu_key] = true
		-- AltRunDoor's WorldUpgradesAdded is purely a "brewed" record — the door
		-- itself is WorldUpgrades-gated and granted by the AP item — so set it on
		-- brew to mirror vanilla: it ends the pre-brew Hermes/Hecate beats
		-- (PathFalse-WorldUpgradesAdded) and fires the surface-door-unlocked prompt
		-- (CurrentRun.WorldUpgradesAdded). SurfacePenaltyCure's WorldUpgradesAdded
		-- IS most of its cure effect, so we must NOT set it here — brewing must not
		-- grant the cure without the AP item; its done-state rides
		-- AP_SurfaceIncantationChecked + the offer mask instead.
		if wu_key == "WorldUpgradeAltRunDoor" then
			GameState.WorldUpgradesAdded[wu_key] = true
			if CurrentRun and CurrentRun.WorldUpgradesAdded then
				CurrentRun.WorldUpgradesAdded[wu_key] = true
			end
		end
		CloseGhostAdminScreen(screen, screen.Components.CloseButton, {})
		H2AP_CheckLocation(ap_location)
		H2AP_ShowBossRewardBanner()
		return
	end

	-- Cauldronsanity: intercept the 86 non-special incantations.
	if settings.cauldronsanity == 1
		and not H2AP_IsSurfaceLockIncantation(wu_key)
		and not H2AP_IsGoalIncantation(wu_key) then
		GhostAdminItemPurchasedPresentation(button, itemData)
		if GameState then
			GameState.WorldUpgradesAdded[wu_key] = true
		end
		if CurrentRun then
			CurrentRun.WorldUpgradesAdded[wu_key] = true
		end
		CloseGhostAdminScreen(screen, screen.Components.CloseButton, {})
		H2AP_CheckLocation(ap_location)
		H2AP_ShowBossRewardBanner()
		return
	end

	return base(screen, button)
end)

-- ── Keepsakesanity location check ────────────────────────────────────────────

-- Intercepts the vanilla keepsake-received presentation when keepsakesanity is on.
-- GiftLogic.lua sets GiftPresentation[gift]=true and NewKeepsakeItem[gift]=true just
-- before calling us, so we undo those to prevent the vanilla keepsake being granted —
-- GiftPresentation is the game's canonical "owns this keepsake" flag (read by
-- bounty/objective/incantation requirements), so it MUST stay clear until AP delivers
-- the keepsake item. We then show our own AP banner and send the AP location check.
--
-- We also set GameState.AP_KeepsakeChecked[gift]. The matching GiftData guard in
-- ready_late.lua makes the keepsake gift-level ineligible once that flag is set, so
-- GiftLogic stops re-calling this presentation on every subsequent gift. Without it,
-- clearing GiftPresentation made the game think the keepsake was never received and
-- re-fired the AP banner each time the player gifted the NPC.
modutil.mod.Path.Wrap("PlayerReceivedGiftPresentation", function(base, npc, giftName)
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
end)

-- ── Familiarsanity location check ─────────────────────────────────────────────

-- Recruiting a familiar (the petting sequence) is the AP location check. We fire
-- the check up front so it registers immediately, let the full vanilla recruit
-- presentation play for feedback, then undo the vanilla FamiliarsUnlocked grant —
-- ownership of the companion is owned by the AP item (H2AP_GiveItem), not the
-- recruit. The AP_FamiliarReceived guard protects the item-first case: if the AP
-- item already granted the familiar, we leave FamiliarsUnlocked alone so the
-- player keeps the companion they already own. AP_FamiliarChecked stops the wild
-- encounter respawning (see H2AP_PatchFamiliarGates). Frinos (hub) routes through
-- this same function, so all five familiars are handled uniformly.
modutil.mod.Path.Wrap("FamiliarRecruitPresentation", function(base, usee, args)
	local settings = H2AP_LoadSettings()
	local name = usee and usee.Name
	if not (settings and settings.familiarsanity == 1 and name and FAMILIAR_LOCATIONS[name]) then
		return base(usee, args)
	end
	GameState.AP_FamiliarChecked = GameState.AP_FamiliarChecked or {}
	GameState.AP_FamiliarChecked[name] = true
	H2AP_CheckLocation(FAMILIAR_LOCATIONS[name])
	base(usee, args)
	local received = GameState.AP_FamiliarReceived and GameState.AP_FamiliarReceived[name]
	if not received then
		GameState.FamiliarsUnlocked[name] = nil
		if CurrentRun and CurrentRun.FamiliarsUnlocked then
			CurrentRun.FamiliarsUnlocked[name] = nil
		end
	end
	H2AP_ShowBossRewardBanner()
end)

-- ── Keepsake equip screen unlock fix ─────────────────────────────────────────

-- ready_late.lua clears all GiftData.GameStateRequirements so the player can
-- gift any NPC without story prerequisites. The side effect is that the keepsake
-- rack screen uses those same (now-empty) requirements to compute Unlocked, so
-- every keepsake appears available. Override Unlocked here with a direct
-- GiftPresentation lookup — the same field GiftLogic and H2AP_GiveItem both write.
modutil.mod.Path.Wrap("CreateKeepsakeIcon", function(base, screen, components, args)
	local settings = H2AP_LoadSettings()
	if settings and args and args.UpgradeData and args.UpgradeData.Gift then
		local gift_id = args.UpgradeData.Gift
		local from_gift = (GameState.GiftPresentation[gift_id] == true)
		local from_ap   = (GameState.AP_KeepsakeReceived
			and GameState.AP_KeepsakeReceived[gift_id] == true)
		args.UpgradeData.Unlocked = from_gift or from_ap
	end
	return base(screen, components, args)
end)

-- ── Hint dispatch on cauldron / Fated List open ──────────────────────────────

-- Hint each visible incantation when a cauldron category is displayed (initial
-- open + every tab switch). H2AP_HintCauldronVisible reads screen.AvailableItems
-- which base() has just populated, then dedupes via H2AP_HintLocation so each
-- location is hinted at most once. Uncontested — no other installed mod hooks
-- GhostAdminDisplayCategory — so this install-once wrap lives here in ready.lua.
-- Keep the AP-controlled surface-lock recipes brewable until their check fires.
-- The cauldron classifies "brewed vs offered" from GameState.WorldUpgradesAdded,
-- which the cure's effect-grant may have set on receive (SurfacePenaltyCure). We
-- mask that flag to our AP_SurfaceIncantationChecked truth for the build, then
-- restore it so the granted effect persists. (Also hints visible incantations.)
modutil.mod.Path.Wrap("GhostAdminDisplayCategory", function(base, screen, button)
	local settings = H2AP_LoadSettings()
	local masked = settings and H2AP_MaskSurfaceIncantationsForOffer(settings) or nil
	base(screen, button)
	if masked then H2AP_UnmaskSurfaceIncantations(masked) end
	H2AP_HintCauldronVisible(screen)
end)

-- Hint each visible (non-cashed-out) prophecy when the Fated List opens.
-- Replicates the game's filter independently rather than reading screen state,
-- which is cleaner because OpenQuestLogScreen has waits before it builds buttons.
modutil.mod.Path.Wrap("OpenQuestLogScreen", function(base, args)
	local result = base(args)
	H2AP_HintQuestlogVisible()
	return result
end)

-- ── Fatesanity: intercept prophecy cashout ───────────────────────────────────

-- For prophecies that are AP locations (fatesanity on), suppress the vanilla
-- AddResource — the resource is granted instead by H2AP_GiveItem when the AP item
-- comes back from the server. The body is inline-replicated from
-- QuestLogLogic.lua:211 so we can drop just the one AddResource line; see
-- the cauldron-incantation pattern (HandleGhostAdminPurchase) for the same idea.
modutil.mod.Path.Wrap("CashOutQuest", function(base, screen, button)
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
end)

-- ── Hidden aspect unlock tracking ────────────────────────────────────────────

-- Under hidden_aspectsanity the aspect's WorldUpgradesAdded flag is owned by the
-- shop location check (HandleWeaponShopPurchase in ready_late.lua), not by ownership.
-- Vanilla HasAnyAspectUnlocked reads WorldUpgradesAdded, so the kit's aspect-select
-- prompt would only light after the *check* fires, not after the AP aspect *item*
-- arrives. Re-point it at WeaponsUnlocked — the same flag the per-aspect list uses
-- (WeaponUpgradeLogic.lua:71), and the one H2AP_GiveItem sets — so the prompt tracks
-- the item and stays fully decoupled from the shop slot. Reading WeaponsUnlocked is
-- vanilla-faithful (vanilla sets it too, else :71 could never show the aspect).
-- The settings gate is checked at call time (not install time) so this wrap can live
-- here in ready.lua, where lib/settings.lua isn't loaded yet when the file executes.
modutil.mod.Path.Wrap("HasAnyAspectUnlocked", function(base, weaponName)
	local settings = H2AP_LoadSettings()
	if not (settings and settings.hidden_aspectsanity == 1) then
		return base(weaponName)
	end
	for traitName, traitData in pairs(TraitSetData.Aspects) do
		if traitData.RequiredWeapon == weaponName and GameState.WeaponsUnlocked[traitName] then
			return true
		end
	end
	return false
end)

-- ── Death hook ────────────────────────────────────────────────────────────────
-- The KillHero wrap lives in ready_late.lua (4 other installed mods also hook it).

-- ── Shrine access block ───────────────────────────────────────────────────────

-- In reverse_Fear and minimal_Fear modes, vow levels are managed by the mod.
-- Prevent the player from opening the shrine screen to avoid confusion.
modutil.mod.Path.Wrap("UseShrineObject", function(base, usee, args)
	local settings = H2AP_LoadSettings()
	if settings and settings.fear_system ~= nil and settings.fear_system ~= 3 then
		print("[HadesII_AP] Shrine interaction blocked (fear system active)")
		return
	end
	return base(usee, args)
end)

-- ── Unlock all grasp ──────────────────────────────────────────────────────────

-- Uncomment to remove all Arcana Grasp costs (useful for testing progression).
-- modutil.mod.Path.Set("MetaUpgradeCostData.MetaUpgradeLevelData", {
-- 		{ CostIncrease = 2, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 2, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 2, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 2, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 2, ResourceCost = { MemPointsCommon = 0 }},

-- 		{ CostIncrease = 1, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 1, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 1, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 1, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 1, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 1, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 1, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 1, ResourceCost = { MemPointsCommon = 0 }},
-- 		{ CostIncrease = 1, ResourceCost = { MemPointsCommon = 0 }},

-- 		{ CostIncrease = 1, ResourceCost = { MemPointsCommon = 0 }},
-- 	})
