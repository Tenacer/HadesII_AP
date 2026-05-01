---@meta _
---@diagnostic disable: lowercase-global

-- Hooks set up once at startup. Functions called here are defined in reload.lua
-- so that logic changes can be hot-reloaded without restarting the game.

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

-- ── Debug keybind ─────────────────────────────────────────────────────────────

-- Press the Gift button to receive a test Ash pack (verifies IPC and AddResource).
game.OnControlPressed({'Gift', function()
	give_item("Ash")
end})

-- ── Room / map hooks ─────────────────────────────────────────────────────────

-- Runs at the start of every room load: processes the AP inbox (grant queued items).
-- The inbox polling thread is started here on the first SetupMap call because
-- thread() requires SessionMapState to exist, which is only true once a map loads.
local _polling_started = false
modutil.mod.Path.Wrap("SetupMap", function(base, ...)
	-- Reload the package each room (game may evict it) and re-patch icons
	-- (hot-reloads of reload.lua reset WorldUpgradeData icon fields).
	LoadPackages({ Name = ap_icon_pkg })
	ap_patch_incantation_icons()
	prefix_SetupMap()
	if not _polling_started then
		_polling_started = true
		-- Persist=true survives LoadMap/KillNonPersistentThreads so we only need to start once.
		thread(function()
			while true do
				wait(0.5, "AP_Inbox_Poll", true)
				ap_process_inbox()
			end
		end)
	end
	return base(...)
end)

-- Fires when all enemies in a room are dead: score a room clear or a boss kill.
modutil.mod.Path.Wrap("OnAllEnemiesDead", function(base, currentRoom, currentEncounter)
	local result = base(currentRoom, currentEncounter)
	on_room_cleared(currentRoom, currentEncounter)
	return result
end)

-- Suppress the vanilla boss reward spawn for rooms we're intercepting.
-- Show the AP logo banner in its place so the player sees visual feedback.
modutil.mod.Path.Wrap("SpawnRoomReward", function(base, eventSource, args)
	if should_replace_reward(CurrentRun and CurrentRun.CurrentRoom) then
		print("[HadesII_AP] Boss reward suppressed — location check sent instead")
		ap_show_boss_reward_banner()
		return
	end
	return base(eventSource, args)
end)

-- ── Cauldron interception ────────────────────────────────────────────────────

-- The real purchase entry point is HandleGhostAdminPurchase, not DoGhostAdminPurchase.
-- HandleGhostAdminPurchase calls AddWorldUpgrade (vanilla effect) and THEN threads
-- DoGhostAdminPurchase (presentation callbacks). Wrapping only DoGhostAdminPurchase
-- was too late — the upgrade was already active in GameState.
--
-- Fix: wrap HandleGhostAdminPurchase to (1) suppress DoGhostAdminPurchase via a flag
-- and (2) undo the AddWorldUpgrade side-effects before sending the AP check.
local _ap_suppressed_purchases = {}

modutil.mod.Path.Wrap("HandleGhostAdminPurchase", function(base, screen, button)
	local settings = ap_load_settings()
	if settings and settings.cauldronsanity == 1 then
		local itemData = button and button.Data
		if itemData then
			local ap_location = INCANTATION_LOCATIONS[itemData.Name]
			if ap_location then
				_ap_suppressed_purchases[itemData.Name] = true
				base(screen, button)
				-- Undo only the active-effect flag. Keep WorldUpgradesAdded = true
				-- so the cauldron UI shows the incantation as already purchased.
				if GameState then
					GameState.WorldUpgrades[itemData.Name] = nil
				end
				ap_check_location(ap_location)
				return
			end
		end
	end
	return base(screen, button)
end)

-- DoGhostAdminPurchase runs in a thread created by HandleGhostAdminPurchase.
-- Skip it entirely for AP incantations so OnActivateFunctionName,
-- OnActivateFinishedFunctionName, and resource callbacks don't fire.
modutil.mod.Path.Wrap("DoGhostAdminPurchase", function(base, screen, button)
	local itemData = button and button.Data
	if itemData and _ap_suppressed_purchases[itemData.Name] then
		_ap_suppressed_purchases[itemData.Name] = nil
		print("[HadesII_AP] DoGhostAdminPurchase suppressed for: " .. itemData.Name)
		ap_show_boss_reward_banner()
		return
	end
	return base(screen, button)
end)

-- ── Keepsakesanity location check ────────────────────────────────────────────

-- Intercepts the vanilla keepsake-received presentation when keepsakesanity is on.
-- GiftLogic.lua sets GiftPresentation[gift]=true and NewKeepsakeItem[gift]=true just
-- before calling us, so we undo those to prevent the vanilla keepsake being granted.
-- We then show our own AP banner (Archipelago logo, gift animations) and send the
-- AP location check. CheckAchievement still runs after we return but is harmless
-- since we cleared GiftPresentation[giftName].
modutil.mod.Path.Wrap("PlayerReceivedGiftPresentation", function(base, npc, giftName)
	local settings = ap_load_settings()
	if settings and settings.keepsakesanity == 1 then
		local location = KEEPSAKE_LOCATION_FOR_GIFT[giftName]
		if location then
			GameState.GiftPresentation[giftName] = nil
			GameState.NewKeepsakeItem[giftName]  = nil
			ap_show_keepsake_check_banner(npc)
			ap_check_location(location)
			return
		end
	end
	return base(npc, giftName)
end)

-- ── Keepsake equip screen unlock fix ─────────────────────────────────────────

-- ready_late.lua clears all GiftData.GameStateRequirements so the player can
-- gift any NPC without story prerequisites. The side effect is that the keepsake
-- rack screen uses those same (now-empty) requirements to compute Unlocked, so
-- every keepsake appears available. Override Unlocked here with a direct
-- GiftPresentation lookup — the same field GiftLogic and give_item both write.
modutil.mod.Path.Wrap("CreateKeepsakeIcon", function(base, screen, components, args)
	local settings = ap_load_settings()
	if settings and args and args.UpgradeData and args.UpgradeData.Gift then
		local gift_id = args.UpgradeData.Gift
		args.UpgradeData.Unlocked = (GameState.GiftPresentation[gift_id] == true)
	end
	return base(screen, components, args)
end)

-- ── Death hook ────────────────────────────────────────────────────────────────

-- KillHero is the hero-specific death handler in DeathLoopLogic.lua.
-- Kill() calls it only when victim == CurrentRun.Hero, so this fires exactly
-- once per Melinoë death and not for enemy deaths.
modutil.mod.Path.Wrap("KillHero", function(base, victim, triggerArgs)
	local result = base(victim, triggerArgs)
	on_melinoe_died()
	return result
end)

-- ── Shrine access block ───────────────────────────────────────────────────────

-- In reverse_Fear and minimal_Fear modes, vow levels are managed by the mod.
-- Prevent the player from opening the shrine screen to avoid confusion.
modutil.mod.Path.Wrap("UseShrineObject", function(base, usee, args)
	local settings = ap_load_settings()
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
