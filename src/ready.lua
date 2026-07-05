---@meta _
---@diagnostic disable: lowercase-global

-- Hooks and pure library imports installed once at startup; side-effecting libraries (rivals, weapons) load from ready_late.lua instead.

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
import 'lib/bossreward.lua'
import 'lib/score.lua'
import 'lib/death.lua'
import 'lib/inbox.lua'

-- ── AP icon package ──────────────────────────────────────────────────────────

-- Load our texture package so the AP icon animation is available.
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

-- Register the AP-logo reward-drop animation so SpawnRoomReward visuals can use it.
local animfile = rom.path.combine(rom.paths.Content, 'Game/Animations/Items_General_VFX.sjson')
sjson.hook(animfile, function(data)
	return sjson_ItemAnimations(data)
end)

-- ── Debug keybind ─────────────────────────────────────────────────────────────

-- Press the Gift button to receive a test Ash pack (verifies IPC and AddResource).
-- game.OnControlPressed({'Gift', function()
-- 	H2AP_GiveItem("Ash")
-- end})

-- ── Room / map hooks ─────────────────────────────────────────────────────────
-- SetupMap, OnAllEnemiesDead and KillHero wraps live in ready_late.lua for deterministic chain order with other mods.

-- Boss reward dispatcher: ap_check spawns an AP pickup, fallback drops Nightmare + Gemstones, vanilla passes through.
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

-- Three-way cauldron dispatch: surface-lock and cauldronsanity brews send the AP check and suppress the vanilla effect, everything else runs vanilla.
modutil.mod.Path.Wrap("HandleGhostAdminPurchase", function(base, screen, button)
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

-- Keepsakesanity: undo the vanilla keepsake grant, send the check, and flag AP_KeepsakeChecked so GiftLogic doesn't re-fire this presentation.
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

-- Familiarsanity: recruiting sends the check, then the vanilla FamiliarsUnlocked grant is undone unless the AP item already delivered it.
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

-- The rack screen computes Unlocked from the (emptied) GiftData requirements, so recompute it from GiftPresentation / AP receipt.
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

-- Mask surface-lock incantations to their AP-checked state while the offer list builds, then hint every visible incantation.
modutil.mod.Path.Wrap("GhostAdminDisplayCategory", function(base, screen, button)
	local settings = H2AP_LoadSettings()
	local masked = settings and H2AP_MaskSurfaceIncantationsForOffer(settings) or nil
	base(screen, button)
	if masked then H2AP_UnmaskSurfaceIncantations(masked) end
	H2AP_HintCauldronVisible(screen)
end)

-- Hint each visible prophecy when the Fated List opens.
modutil.mod.Path.Wrap("OpenQuestLogScreen", function(base, args)
	local result = base(args)
	H2AP_HintQuestlogVisible()
	return result
end)

-- ── Fatesanity: intercept prophecy cashout ───────────────────────────────────

-- Fatesanity: replicate CashOutQuest minus its AddResource, which the AP item delivers instead.
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

-- Hidden aspectsanity: re-point HasAnyAspectUnlocked at WeaponsUnlocked so the kit prompt tracks the AP item, not the shop check.
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

-- Block the shrine screen when the mod manages vow levels (reverse/minimal fear).
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
