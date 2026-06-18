---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- here is where your mod sets up all the things it will do after all other mods load.
-- this file will not be reloaded if it changes during gameplay
-- 	so you will most likely want to have it reference
--	values and functions later defined in `reload_late.lua`.

-- ── Initial startup calls ────────────────────────────────────────────────────

-- These need reload.lua (imported in on_reload before on_ready_late fires).
-- Patch incantation icons + cauldron-visibility gates for the hub screen
-- before the first SetupMap wrap fires.
H2AP_PatchIncantationIcons()
H2AP_PatchIncantationGates()
H2AP_PatchIncantationCosts()
H2AP_PatchGoalIncantationGate()
-- Flush the outbox immediately so the Python client sees the game is running.
H2AP_FlushOutbox()

-- ── GiftData fix ──────────────────────────────────────────────────────────────

-- Clear GameStateRequirements from all GiftData gift-level entries so that AP can
-- trigger keepsake location checks via gifting without needing specific NPC dialogue
-- to have happened first. Runs after all mods have populated GiftData.
--
-- Keepsake gift-levels get a guard instead of an empty requirement: they stay
-- eligible only until GameState.AP_KeepsakeChecked[gift] is set (the moment the AP
-- check fires, see ready.lua). After that GiftLogic skips the level, so
-- PlayerReceivedGiftPresentation is no longer re-called — and the AP banner no longer
-- re-shows — every time the player gifts that NPC again. The guard deliberately keys
-- off our own AP_KeepsakeChecked flag, NOT GiftPresentation, so the keepsake stays
-- "unowned" for bounty/objective/incantation requirements until AP delivers it.
-- (When keepsakesanity is off, AP_KeepsakeChecked is never set, so the guard always
-- passes and behaves exactly like the cleared `{}` requirement.)
for npcName, npcData in pairs(GiftData) do
	if type(npcData) == "table" then
		for i = 1, #npcData do
			local entry = npcData[i]
			if entry then
				local gift = entry.Gift
				if gift and KEEPSAKE_LOCATION_FOR_GIFT[gift] then
					entry.GameStateRequirements = {
						{ PathFalse = { "GameState", "AP_KeepsakeChecked", gift } },
					}
				elseif entry.GameStateRequirements then
					entry.GameStateRequirements = {}
				end
			end
		end
	end
end

-- ── Contested game-function wraps ─────────────────────────────────────────────
-- These three globals are also hooked by several other installed mods, so we
-- register our wraps here (on_ready_late, i.e. after on_all_mods_loaded) rather
-- than in ready.lua's early on_ready phase. That keeps our position in the wrap
-- chain deterministic relative to the other mods and avoids the load-order GC
-- instability described in ModUtil issue #12. The callbacks reference H2AP_*
-- globals resolved at call time (defined in reload.lua), so late registration is
-- safe. Recompute ap_icon_pkg here since ready.lua's local isn't in scope.
local ap_icon_pkg = rom.path.combine(_PLUGIN.plugins_data_mod_folder_path, _PLUGIN.guid)

-- Runs at the start of every room load: processes the AP inbox (grant queued items).
-- The inbox polling thread is started here on the first SetupMap call because
-- thread() requires SessionMapState to exist, which is only true once a map loads.
local _polling_started = false
modutil.mod.Path.Wrap("SetupMap", function(base, ...)
	-- Reload the package each room (game may evict it) and re-patch icons
	-- (hot-reloads of reload.lua reset WorldUpgradeData icon fields).
	LoadPackages({ Name = ap_icon_pkg })
	H2AP_PatchIncantationIcons()
	H2AP_PatchIncantationGates()
	H2AP_PatchIncantationCosts()
	H2AP_SetupMap()
	if not _polling_started then
		_polling_started = true
		-- Persist=true survives LoadMap/KillNonPersistentThreads so we only need to start once.
		thread(function()
			while true do
				wait(0.5, "AP_Inbox_Poll", true)
				H2AP_ProcessInbox()
			end
		end)
	end
	return base(...)
end)

-- Fires when all enemies in a room are dead: score a room clear or a boss kill.
modutil.mod.Path.Wrap("OnAllEnemiesDead", function(base, currentRoom, currentEncounter)
	local result = base(currentRoom, currentEncounter)
	H2AP_OnRoomCleared(currentRoom, currentEncounter)
	return result
end)

-- Arachne cocoon rooms never call OnAllEnemiesDead: their encounter event set is
-- { BeginArachneEncounter, WaitForArachneRewardFound } (see EncounterSets.lua),
-- ending when the reward cocoon's death fires the "ArachneRewardFound" notify that
-- WaitForArachneRewardFound is blocked on — there's no CheckForAllEnemiesDead in the
-- chain. So we score these rooms here, once WaitForArachneRewardFound unblocks (the
-- room is cleared). No double-count risk since OnAllEnemiesDead never runs for them.
modutil.mod.Path.Wrap("WaitForArachneRewardFound", function(base, encounter)
	local result = base(encounter)
	H2AP_OnRoomCleared(CurrentRun and CurrentRun.CurrentRoom, encounter)
	return result
end)

-- KillHero is the hero-specific death handler in DeathLoopLogic.lua.
-- Kill() calls it only when victim == CurrentRun.Hero, so this fires exactly
-- once per Melinoë death and not for enemy deaths.
modutil.mod.Path.Wrap("KillHero", function(base, victim, triggerArgs)
	local result = base(victim, triggerArgs)
	H2AP_OnMelinoeDied()
	return result
end)

-- Weapon / hidden aspect / tool sanity: suppress the vanilla weapon/aspect/tool
-- unlock when the corresponding sanity option is on. Player still pays cost;
-- AddWorldUpgrade and the equip thread are skipped. H2AP_GiveItem handles the real
-- unlock when the AP item arrives. WorldUpgradesAdded is set so the slot shows as
-- purchased and can't be re-bought. Tools (ToolPickaxe etc.) sell through this same
-- WeaponShop screen, so they ride the same interception when toolsanity is on.
-- Contested: BountyAPI / Zagreus_Journey also touch the shop, so this registers late.
modutil.mod.Path.Wrap("HandleWeaponShopPurchase", function(base, screen, button)
	local settings = H2AP_LoadSettings()
	local itemData = button and button.Data
	if settings and itemData then
		local item_name = itemData.Name
		local ap_location = nil
		if settings.weaponsanity == 1 and WEAPON_LOCATIONS[item_name] then
			ap_location = WEAPON_LOCATIONS[item_name]
		elseif settings.hidden_aspectsanity == 1 and HIDDEN_ASPECT_LOCATIONS[item_name] then
			ap_location = HIDDEN_ASPECT_LOCATIONS[item_name]
		elseif settings.toolsanity == 1 and TOOL_LOCATIONS[item_name] then
			-- Tools share the WeaponShop screen; item_name is the internal tool key
			-- (e.g. "ToolPickaxe"). Suppress the vanilla unlock and fire the check;
			-- H2AP_GiveItem grants the actual tool when the AP item arrives.
			ap_location = TOOL_LOCATIONS[item_name]
		end
		if ap_location then
			if not button.Free and not HasResources(itemData.Cost) then
				ScreenCantAffordPresentation(screen, button)
				return
			end
			if not IsEmpty(itemData.Cost) ~= nil and itemData.PurchaseRequirements ~= nil
				and not IsGameStateEligible(itemData.PurchaseRequirements) then
				CantPurchasePresentation(screen.Components["PurchaseButton" .. button.Index])
				return
			end
			for resourceName, resourceCost in pairs(itemData.Cost) do
				SpendResource(resourceName, resourceCost, metaUpgradeName, {
					TargetId = screen.Components["ResourceIconBacking" .. resourceName].Id,
					UseScreenLocation = true,
					TextOffsetY = 11, TextAnchorOffsetY = -50,
					HoldDuration = 0, FadeOutDuration = 0.2,
					SkipQuestStatusCheck = true,
				})
			end
			WeaponShopItemPurchasedPresentation(button, itemData)
			GameState.WorldUpgradesAdded[item_name] = true
			if CurrentRun then
				CurrentRun.WorldUpgradesAdded[item_name] = true
			end
			RemoveStoreItemPin(item_name, { Purchase = true })
			CreateAnimation({ Name = "ContractorSlotPurchase", DestinationId = screen.Components["PurchaseButton" .. button.Index].Id, OffsetX = 0 })
			Destroy({ Id = screen.Components["PurchaseButton" .. button.Index].Id })
			screen.Components["PurchaseButton" .. button.Index] = nil
			if screen.Components["Icon" .. button.Index] ~= nil then
				Destroy({ Id = screen.Components["Icon" .. button.Index].Id })
				screen.Components["Icon" .. button.Index] = nil
			end
			-- Pass the CloseButton (not the purchase button) so
			-- WeaponShopScreenCloseFinishedPresentation takes the close-button
			-- branch and pans the camera back to Melinoë. Passing the purchase
			-- button skips that branch and the camera stays stuck on the shop.
			-- (Same root cause + fix as the cauldron CloseGhostAdminScreen case.)
			CloseWeaponShopScreen(screen, screen.Components.CloseButton or button, {})
			H2AP_CheckLocation(ap_location)
			H2AP_ShowBossRewardBanner()
			return
		end
	end
	return base(screen, button)
end)

-- StartNewRun: apply persistent run-start helpers after vanilla finishes.
--   • Initial Money helper: extra Money on top of CalculateStartingMoney
--   • Max Health helper: re-sync the cumulative bonus onto the fresh hero
-- Contested — MelSkin, Zagreus_Journey and BountyAPI all wrap StartNewRun — so
-- this registers in ready_late for deterministic chain order.
modutil.mod.Path.Wrap("StartNewRun", function(base, prevRun, args)
	local result = base(prevRun, args)
	pcall(H2AP_ApplyMaxHealthHelper)
	pcall(H2AP_ApplyInitialMoneyHelper)
	return result
end)

-- GetRarityChances: add an additive percentage to the Rare and Epic buckets only,
-- from the accumulated Boon Boost Helpers. We deliberately leave the other rarities
-- alone — Duo/Legendary/Heroic carry their own gameplay balance and Common is the
-- inert fallback. Contested by boon-rarity mods, so registered late.
local AP_BOON_BOOST_RARITIES = { "Rare", "Epic" }
modutil.mod.Path.Wrap("GetRarityChances", function(base, loot)
	local rarityChances = base(loot)
	local boost = H2AP_BoonBoostPct and H2AP_BoonBoostPct() or 0
	if boost > 0 and rarityChances then
		for _, rarityName in ipairs(AP_BOON_BOOST_RARITIES) do
			if rarityChances[rarityName] ~= nil then
				rarityChances[rarityName] = rarityChances[rarityName] + boost
			end
		end
	end
	return rarityChances
end)

