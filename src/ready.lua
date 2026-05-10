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

-- Boss reward dispatcher. Branches on ap_boss_reward_action (set in lib/score.lua):
--   ap_check  → spawn an interactable for the AP item placed at this location
--               (resource-obstacle visual when local + recognised, AP icon
--               otherwise). The AP check fires when the player picks it up.
--   fallback  → past per-boss kill count; spawn Nightmare + Gemstones drops
--   vanilla   → BossDefeats mode (or non-boss room); let vanilla reward through
modutil.mod.Path.Wrap("SpawnRoomReward", function(base, eventSource, args)
	local currentRoom = CurrentRun and CurrentRun.CurrentRoom
	local action = ap_boss_reward_action(currentRoom)
	if action == "ap_check" then
		local boss_key = ap_boss_for_room(currentRoom)
		local ap_location = ap_boss_current_location_name(boss_key)
		if ap_location then
			print("[HadesII_AP] Spawning boss-reward pickup for " .. ap_location)
			ap_spawn_ap_boss_reward(ap_location)
		end
		return
	end
	if action == "fallback" then
		print("[HadesII_AP] Boss kills past AP-check range — spawning Nightmare + Gemstones drops")
		ap_spawn_consumable_drop("WeaponPointsRareDrop", 30,  110)
		ap_spawn_consumable_drop("GemPointsBigDrop",     150, 110)
		return
	end
	return base(eventSource, args)
end)

-- ── Cauldron interception ────────────────────────────────────────────────────

-- Don't call base() for AP incantations. Calling base() would invoke
-- CloseGhostAdminScreen with the purchase button, which causes
-- GhostAdminScreenClosedPresentation to take the incantation-animation branch
-- (sets up CauldronBackgroundIllustration, no camera pan). The camera pan to
-- hero only happens via the close-button branch of that function.
-- Instead we replicate only what we need and pass screen.Components.CloseButton
-- to CloseGhostAdminScreen so the camera correctly returns to Melinoe.
modutil.mod.Path.Wrap("HandleGhostAdminPurchase", function(base, screen, button)
	local settings = ap_load_settings()
	if settings and settings.cauldronsanity == 1 then
		local itemData = button and button.Data
		if itemData then
			local ap_location = INCANTATION_LOCATIONS[itemData.Name]
			if ap_location then
				GhostAdminItemPurchasedPresentation(button, itemData)
				if GameState then
					GameState.WorldUpgradesAdded[itemData.Name] = true
				end
				if CurrentRun then
					CurrentRun.WorldUpgradesAdded[itemData.Name] = true
				end
				CloseGhostAdminScreen(screen, screen.Components.CloseButton, {})
				ap_check_location(ap_location)
				ap_show_boss_reward_banner()
				return
			end
		end
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
