---@meta _
---@diagnostic disable: lowercase-global

-- Hooks set up once at startup. Functions called here are defined in reload.lua
-- so that logic changes can be hot-reloaded without restarting the game.

-- ── AP icon package ──────────────────────────────────────────────────────────

-- Load our custom texture package (Tenacer_AP-HadesII_AP.pkg) so the AP icon
-- animation is available. Hell2Modding auto-registers it; LoadPackages activates it.
local ap_icon_pkg = rom.path.combine(_PLUGIN.plugins_data_mod_folder_path, _PLUGIN.guid)
LoadPackages({ Name = ap_icon_pkg })

-- Reload the package on every room transition (game may evict it between rooms).
-- Also patch incantation icons here so they stay overridden after hot-reloads.
local _orig_prefix_SetupMap = prefix_SetupMap
function prefix_SetupMap(...)
	LoadPackages({ Name = ap_icon_pkg })
	ap_patch_incantation_icons()
	if _orig_prefix_SetupMap then return _orig_prefix_SetupMap(...) end
end

-- Patch icons once immediately at startup (covers the hub screen).
ap_patch_incantation_icons()

-- ── Initial state flush ───────────────────────────────────────────────────────

-- Write the outbox immediately so the Python client knows the game is running
-- as soon as the mod loads, without waiting for the first room transition.
ap_flush_outbox()

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

-- All 86 AP-tracked incantations are instant (no CookTime), so they complete
-- inside DoGhostAdminPurchase rather than via UseCauldronCookComplete.
-- We temporarily null OnActivateFinishedFunctionName so the vanilla effect is
-- skipped, then send the AP location check after base() returns.
modutil.mod.Path.Wrap("DoGhostAdminPurchase", function(base, screen, button)
	local settings = ap_load_settings()
	if settings and settings.cauldronsanity == 1 then
		local itemData = button and button.Data
		if itemData then
			local ap_location = INCANTATION_LOCATIONS[itemData.Name]
			if ap_location then
				local savedFn   = itemData.OnActivateFinishedFunctionName
				local savedArgs = itemData.OnActivateFinishedFunctionArgs
				itemData.OnActivateFinishedFunctionName = nil
				base(screen, button)
				itemData.OnActivateFinishedFunctionName = savedFn
				itemData.OnActivateFinishedFunctionArgs = savedArgs
				ap_check_location(ap_location)
				return
			end
		end
	end
	return base(screen, button)
end)

-- Override the "Incantation Complete" banner to show the AP logo and "AP Check Sent"
-- so the player knows the brew triggered an AP check, not a vanilla effect.
modutil.mod.Path.Wrap("PostIncantationPresentationUnlockText", function(base, saleData)
	local settings = ap_load_settings()
	if settings and settings.cauldronsanity == 1 and INCANTATION_LOCATIONS[saleData.Name] then
		local patched = {}
		for k, v in pairs(saleData) do patched[k] = v end
		patched.UnlockTextId = "APCheckSent"
		patched.Icon = AP_ICON_ANIM
		return base(patched)
	end
	return base(saleData)
end)

-- ── Keepsakesanity location check ────────────────────────────────────────────

-- Fires whenever the player visually receives a keepsake from an NPC.
-- Delegates to on_keepsake_received_presentation() which checks the keepsakesanity
-- setting and sends the AP location check if this is a tracked gifting event.
modutil.mod.Path.Wrap("PlayerReceivedGiftPresentation", function(base, npc, giftName)
	local result = base(npc, giftName)
	on_keepsake_received_presentation(npc, giftName)
	return result
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
