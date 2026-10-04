---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- here is where your mod sets up all the things it will do after all other mods load.
-- this file will not be reloaded if it changes during gameplay.

-- ── Library modules with import-time side effects ─────────────────────────────
-- rivals.lua and weapons.lua do install work at import time, so they load here exactly once.
import 'lib/rivals.lua'
import 'lib/weapons.lua'

-- ── Initial startup calls ────────────────────────────────────────────────────

-- Patch incantation icons and gates before the first SetupMap wrap fires.
H2AP_PatchIncantationIcons()
H2AP_PatchSurfaceIncantationReveal()
H2AP_PatchIncantationCosts()
H2AP_PatchGoalIncantationGate()
H2AP_PatchFamiliarGates()
-- Flush the outbox immediately so the Python client sees the game is running.
H2AP_FlushOutbox()

-- ── GiftData fix ──────────────────────────────────────────────────────────────

-- Replace AP-mapped keepsake gift-level prerequisites with an AP_KeepsakeChecked guard so gifting works without story dialogue; unmapped (post-ending) gifts keep vanilla requirements.
for npcName, npcData in pairs(GiftData) do
	if type(npcData) == "table" then
		for i = 1, #npcData do
			local entry = npcData[i]
			if entry and entry.Gift and KEEPSAKE_LOCATION_FOR_GIFT[entry.Gift] then
				entry.GameStateRequirements = {
					{ PathFalse = { "GameState", "AP_KeepsakeChecked", entry.Gift } },
				}
			end
		end
	end
end

-- ── Contested game-function wraps ─────────────────────────────────────────────
-- Globals also hooked by other installed mods register here (after on_all_mods_loaded) for deterministic wrap-chain order.

-- Start-of-room processing in a fixed order; each callee guards against a nil GameState on first launch.
modutil.mod.Path.Wrap("SetupMap", function(base, ...)
	H2AP_LoadIconPackage()
	H2AP_PatchIncantationIcons()
	H2AP_PatchSurfaceIncantationReveal()
	H2AP_PatchIncantationCosts()
	H2AP_PatchFamiliarGates()
	H2AP_LogProgress()
	H2AP_ApplyShrineLevels()
	H2AP_PatchVowRequirements()
	H2AP_InitWeaponState()
	H2AP_ApplyAspectSystemUnlock()
	H2AP_InitBaseAspectShop()
	H2AP_GrantInitialAspect()
	H2AP_ApplyUnlockBroker()
	H2AP_ProcessInbox()
	H2AP_CheckQuestCompletions()
	H2AP_ProcessTrapQueue()
	H2AP_StartInboxPolling()
	return base(...)
end)

-- Fires when all enemies in a room are dead: score a room clear or a boss kill.
modutil.mod.Path.Wrap("OnAllEnemiesDead", function(base, currentRoom, currentEncounter)
	local result = base(currentRoom, currentEncounter)
	H2AP_OnRoomCleared(currentRoom, currentEncounter)
	return result
end)

-- Room-based systems count depths here since DoUnlockRoomExits fires for non-combat rooms too.
modutil.mod.Path.Wrap("DoUnlockRoomExits", function(base, run, room)
	local result = base(run, room)
	H2AP_OnRoomExitsUnlocked(room)
	return result
end)

-- Arachne cocoon rooms never call OnAllEnemiesDead, so score them when WaitForArachneRewardFound unblocks.
modutil.mod.Path.Wrap("WaitForArachneRewardFound", function(base, encounter)
	local result = base(encounter)
	local room = CurrentRun and CurrentRun.CurrentRoom
	H2AP_OnRoomCleared(room, encounter)
	H2AP_OnRoomExitsUnlocked(room)
	return result
end)

-- KillHero fires exactly once per Melinoë death.
modutil.mod.Path.Wrap("KillHero", function(base, victim, triggerArgs)
	local result = base(victim, triggerArgs)
	H2AP_OnMelinoeDied()
	return result
end)

-- Weapon/aspect/tool sanity: suppress the vanilla shop unlock (player still pays), fire the check, and let H2AP_GiveItem deliver the real unlock.
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
		elseif settings.aspectsanity == 1 and STANDARD_ASPECT_LOCATIONS[item_name] then
			ap_location = STANDARD_ASPECT_LOCATIONS[item_name]
		elseif settings.aspectsanity == 1 and BASE_ASPECT_LOCATIONS[item_name] then
			ap_location = BASE_ASPECT_LOCATIONS[item_name]
		elseif settings.toolsanity == 1 and TOOL_LOCATIONS[item_name] then
			-- Tools share the WeaponShop screen.
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
				-- Base aspects cost MetaCurrency (Bones), which may lack a cost-icon backing.
				local backing = screen.Components["ResourceIconBacking" .. resourceName]
				SpendResource(resourceName, resourceCost, metaUpgradeName, {
					TargetId = backing and backing.Id,
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
			-- Pass the CloseButton so the camera pans back to Melinoë instead of staying stuck on the shop.
			CloseWeaponShopScreen(screen, screen.Components.CloseButton or button, {})
			H2AP_CheckLocation(ap_location)
			H2AP_ShowCheckSentBanner()
			return
		end
	end
	return base(screen, button)
end)

-- StartNewRun: apply the Money and Max Health helpers after vanilla finishes.
modutil.mod.Path.Wrap("StartNewRun", function(base, prevRun, args)
	local result = base(prevRun, args)
	pcall(H2AP_ApplyMaxHealthHelper)
	pcall(H2AP_ApplyInitialMoneyHelper)
	return result
end)

-- GetRarityChances: add the accumulated Boon Boost percentage to the Rare and Epic buckets only.
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

