---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- here is where your mod sets up all the things it will do after all other mods load.
-- this file will not be reloaded if it changes during gameplay.

-- ── One-time installs ─────────────────────────────────────────────────────────

H2AP_InstallReverseRivals()
-- Starting weapon for fresh saves and existing saves.
H2AP_ApplyStartingWeapon()
H2AP_InstallCreateNewHeroOverride()

-- ── Initial startup calls ────────────────────────────────────────────────────

-- Patch incantation icons and gates before the first SetupMap wrap fires.
H2AP_PatchIncantationIcons()
H2AP_PatchSurfaceIncantationReveal()
H2AP_PatchIncantationCosts()
H2AP_PatchGoalIncantationGate()
H2AP_PatchFamiliarGates()
H2AP_PatchKeepsakeGiftRequirements()
-- Flush the outbox immediately so the Python client sees the game is running.
H2AP_FlushOutbox()

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
	local item_name = button and button.Data and button.Data.Name
	local ap_location = item_name and (H2AP_WeaponShopLocation(item_name)
		or H2AP_AspectShopLocation(item_name)
		or H2AP_ToolShopLocation(item_name))
	if ap_location then
		return H2AP_PurchaseShopCheck(screen, button, ap_location)
	end
	return base(screen, button)
end)

-- StartNewRun: apply the Money and Max Health helpers after vanilla finishes.
modutil.mod.Path.Wrap("StartNewRun", H2AP_OnStartNewRun)

-- GetRarityChances: add the accumulated Boon Boost percentage to the Rare and Epic buckets only.
modutil.mod.Path.Wrap("GetRarityChances", H2AP_OnGetRarityChances)

