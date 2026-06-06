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
--  1. AP-keyed (surface lock or goal incantation under their respective
--     toggles): fire the AP location check, then let base() run so the vanilla
--     WorldUpgrade effect applies normally. The AP item already unlocked the
--     cauldron entry (see H2AP_PatchIncantationGates) — brewing is the natural
--     consummation of that, both granting the effect locally and sending the
--     AP check.
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

	-- AP-keyed: fire check, then vanilla brew applies the effect.
	if H2AP_IsApKeyedIncantation(wu_key, settings) then
		H2AP_CheckLocation(ap_location)
		H2AP_ShowBossRewardBanner()
		return base(screen, button)
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
