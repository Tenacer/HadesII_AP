---@meta _
---@diagnostic disable: lowercase-global

-- Imports every feature module and registers the uncontested hooks; contested wraps and one-time installs live in ready_late.lua.

-- ── Library modules (pure definitions) ────────────────────────────────────────

import 'lib/json.lua'
import 'lib/utils.lua'
import 'lib/ipc.lua'
import 'lib/cauldron.lua'
import 'lib/prophecies.lua'
import 'lib/keepsakes.lua'
import 'lib/fear.lua'
import 'lib/tools.lua'
import 'lib/weapons.lua'
import 'lib/aspects.lua'
import 'lib/familiars.lua'
import 'lib/traps.lua'
import 'lib/qol.lua'
import 'lib/bossrewards.lua'
import 'lib/score.lua'
import 'lib/goal.lua'

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

-- Weapon / tool / aspect shop labels live in TraitText, not HelpText.
local traitfile = rom.path.combine(rom.paths.Content, 'Game/Text/en/TraitText.en.sjson')
sjson.hook(traitfile, function(data)
	H2AP_WeaponRelabelTraitText(data)
	H2AP_ToolRelabelTraitText(data)
	H2AP_AspectRelabelTraitText(data)
end)

-- Register the AP-logo reward-drop animation so SpawnRoomReward visuals can use it.
local animfile = rom.path.combine(rom.paths.Content, 'Game/Animations/Items_General_VFX.sjson')
sjson.hook(animfile, function(data)
	return sjson_ItemAnimations(data)
end)

-- ── Game function wraps ───────────────────────────────────────────────────────

-- Boss rewards
modutil.mod.Path.Wrap("SpawnRoomReward", H2AP_OnSpawnRoomReward)

-- Cauldron
modutil.mod.Path.Wrap("HandleGhostAdminPurchase", H2AP_OnCauldronPurchase)
modutil.mod.Path.Wrap("GhostAdminDisplayCategory", H2AP_OnCauldronDisplayCategory)

-- Keepsakes
modutil.mod.Path.Wrap("PlayerReceivedGiftPresentation", H2AP_OnKeepsakeGifted)
modutil.mod.Path.Wrap("CreateKeepsakeIcon", H2AP_OnCreateKeepsakeIcon)

-- Familiars
modutil.mod.Path.Wrap("FamiliarRecruitPresentation", H2AP_OnFamiliarRecruited)

-- Prophecies
modutil.mod.Path.Wrap("OpenQuestLogScreen", H2AP_OnOpenQuestLog)
modutil.mod.Path.Wrap("CashOutQuest", H2AP_OnCashOutQuest)

-- Aspects
modutil.mod.Path.Wrap("HasAnyAspectUnlocked", H2AP_OnHasAnyAspectUnlocked)

-- Fear
modutil.mod.Path.Wrap("UseShrineObject", H2AP_OnUseShrine)

-- ── Debug helpers ─────────────────────────────────────────────────────────────

-- Press the Gift button to receive a test Ash pack (verifies IPC and AddResource).
-- game.OnControlPressed({'Gift', function()
-- 	H2AP_GiveItem("Ash")
-- end})

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
