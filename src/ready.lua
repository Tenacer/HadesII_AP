---@meta _
---@diagnostic disable: lowercase-global

-- Hooks and pure library imports installed once at startup; side-effecting libraries (rivals, weapons) load from ready_late.lua instead.

-- ── Library modules (pure definitions) ────────────────────────────────────────

import 'lib/json.lua'
import 'lib/utils.lua'
import 'lib/ipc.lua'
import 'lib/cauldron.lua'
import 'lib/prophecies.lua'
import 'lib/keepsakes.lua'
import 'lib/ItemData.lua'
import 'lib/story.lua'
import 'lib/fear.lua'
import 'lib/tools.lua'
import 'lib/familiars.lua'
import 'lib/traphelper.lua'
import 'lib/qol.lua'
import 'lib/bossreward.lua'
import 'lib/score.lua'
import 'lib/death.lua'

-- ── AP icon package ──────────────────────────────────────────────────────────

-- Load our texture package so the AP icon animation is available.
H2AP_LoadIconPackage()

-- ── Text patches ──────────────────────────────────────────────────────────────

local file = rom.path.combine(rom.paths.Content, 'Game/Text/en/ShellText.en.sjson')
sjson.hook(file, function(data)
	return sjson_ShellText(data)
end)

local helpfile = rom.path.combine(rom.paths.Content, 'Game/Text/en/HelpText.en.sjson')
sjson.hook(helpfile, function(data)
	H2AP_AddCheckSentText(data)
	H2AP_CauldronRelabelHelpText(data)
	H2AP_ProphecyRelabelHelpText(data)
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
modutil.mod.Path.Wrap("HandleGhostAdminPurchase", H2AP_OnCauldronPurchase)
-- ── Keepsakesanity location check ────────────────────────────────────────────

-- Keepsakesanity: undo the vanilla keepsake grant, send the check, and flag AP_KeepsakeChecked so GiftLogic doesn't re-fire this presentation.
modutil.mod.Path.Wrap("PlayerReceivedGiftPresentation", H2AP_OnKeepsakeGifted)

-- ── Familiarsanity location check ─────────────────────────────────────────────

-- Familiarsanity: recruiting sends the check, then the vanilla FamiliarsUnlocked grant is undone unless the AP item already delivered it.
modutil.mod.Path.Wrap("FamiliarRecruitPresentation", H2AP_OnFamiliarRecruited)

-- ── Keepsake equip screen unlock fix ─────────────────────────────────────────

-- The rack screen computes Unlocked from the (emptied) GiftData requirements, so recompute it from GiftPresentation / AP receipt.
modutil.mod.Path.Wrap("CreateKeepsakeIcon", H2AP_OnCreateKeepsakeIcon)

-- ── Hint dispatch on cauldron / Fated List open ──────────────────────────────

-- Mask surface-lock incantations to their AP-checked state while the offer list builds, then hint every visible incantation.
modutil.mod.Path.Wrap("GhostAdminDisplayCategory", H2AP_OnCauldronDisplayCategory)
-- Hint each visible prophecy when the Fated List opens.
modutil.mod.Path.Wrap("OpenQuestLogScreen", H2AP_OnOpenQuestLog)
-- ── Fatesanity: intercept prophecy cashout ───────────────────────────────────

-- Fatesanity: replicate CashOutQuest minus its AddResource, which the AP item delivers instead.
modutil.mod.Path.Wrap("CashOutQuest", H2AP_OnCashOutQuest)
-- ── Hidden aspect unlock tracking ────────────────────────────────────────────

-- Aspect sanity: re-point HasAnyAspectUnlocked at WeaponsUnlocked so the kit prompt tracks the AP item, not the shop check.
modutil.mod.Path.Wrap("HasAnyAspectUnlocked", function(base, weaponName)
	local settings = H2AP_LoadSettings()
	if not (settings and (settings.hidden_aspectsanity == 1 or settings.aspectsanity == 1)) then
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
