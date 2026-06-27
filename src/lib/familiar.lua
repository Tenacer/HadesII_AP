---@meta _
---@diagnostic disable: lowercase-global

-- ── Familiar (animal companion) sanity ────────────────────────────────────────
-- Under familiarsanity, the five recruitable familiars become AP items/locations.
-- The *location check* fires when the player recruits a familiar (the petting /
-- FamiliarRecruitPresentation), and the *companion unlock* is owned by the AP item.
-- These are deliberately decoupled so an early item can't hide the encounter:
--   • GameState.AP_FamiliarChecked[name]  → the location check has been sent
--                                            (set in the recruit wrap, ready.lua)
--   • GameState.AP_FamiliarReceived[name] → the AP item has been received
--                                            (set in H2AP_GiveItem, lib/items.lua)
--   • GameState.FamiliarsUnlocked[name]   → vanilla "owns the companion" flag,
--                                            now driven solely by the AP item.
--
-- Frinos (FrogFamiliar) is the hub/story familiar — DeathLoopData spawns it
-- "always present" with no FamiliarsUnlocked gate, so the RoomData scan below
-- never touches it; its recruit (Crossroads petting) still routes through
-- FamiliarRecruitPresentation, so the same wrap handles it uniformly.

-- Game internal familiar name → AP location name. Keys must match Args.Name on
-- the ActivateFamiliar events / the usee.Name in FamiliarRecruitPresentation.
FAMILIAR_LOCATIONS = {
	FrogFamiliar    = "Frinos Familiar Unlock Location",
	RavenFamiliar   = "Raki Familiar Unlock Location",
	CatFamiliar     = "Toula Familiar Unlock Location",
	HoundFamiliar   = "Hecuba Familiar Unlock Location",
	PolecatFamiliar = "Gale Familiar Unlock Location",
}

-- AP item name → game internal familiar name (for H2AP_GiveItem). Keys must match
-- the bare item names from the apworld's items.csv exactly.
FAMILIAR_ITEM_TO_NAME = {
	["Frinos Familiar"] = "FrogFamiliar",
	["Raki Familiar"]   = "RavenFamiliar",
	["Toula Familiar"]  = "CatFamiliar",
	["Hecuba Familiar"] = "HoundFamiliar",
	["Gale Familiar"]   = "PolecatFamiliar",
}

-- Patch the game's data tables so the wild encounter is gated on whether the AP
-- *check* has been done (AP_FamiliarChecked) rather than whether the companion is
-- *owned* (FamiliarsUnlocked). No-op unless familiarsanity is on. Idempotent via
-- per-entry sentinels, so it's safe to call on every SetupMap. Guarded against the
-- first-launch nil-GameState window like the other early-firing patches.
function H2AP_PatchFamiliarGates()
	if GameState == nil then return end
	local settings = H2AP_LoadSettings() or {}
	if settings.familiarsanity ~= 1 then return end

	-- 1. FamiliarData SetupEvents: the OverwriteSelf entries that swap the wild
	--    gift over to upgrade/costume once FamiliarsUnlocked is true would, in the
	--    item-first case, stop the wild interaction from routing to the recruit
	--    (and so suppress the check). Require AP_FamiliarChecked too, so the wild
	--    encounter keeps offering the recruit until the check has actually fired.
	if FamiliarData ~= nil then
		for name in pairs(FAMILIAR_LOCATIONS) do
			local data = FamiliarData[name]
			if data and data.SetupEvents then
				for _, event in ipairs(data.SetupEvents) do
					if event.FunctionName == "OverwriteSelf"
						and event.Args
						and (event.Args.GiftFunctionName == "GiftFamiliarUpgrade"
							or event.Args.ReceiveGiftFunctionName == "GiftFamiliarCostume")
						and not event._ap_familiar_check_gated then
						event.GameStateRequirements = event.GameStateRequirements or {}
						table.insert(event.GameStateRequirements, {
							PathTrue = { "GameState", "AP_FamiliarChecked", name },
						})
						event._ap_familiar_check_gated = true
					end
				end
			end
		end
	end

	-- 2. RoomData wild spawns: replace each ActivateFamiliar's appearance gate with
	--    a minimal one keyed on AP_FamiliarChecked. We strip the vanilla
	--    prerequisites (FamiliarPoints spent, fishing successes, room-entry counts,
	--    ChanceToPlay, etc.) so the check is reliably reachable once the player is in
	--    the biome — keeping only the bounty / dream-run guard. The matching
	--    ConditionalSubIconRequirements (fated-list sub-icon) is swapped the same way.
	if RoomData ~= nil then
		for _, roomData in pairs(RoomData) do
			if type(roomData) == "table" and roomData.StartThreadedEvents then
				for _, event in ipairs(roomData.StartThreadedEvents) do
					if event.FunctionName == "ActivateFamiliar"
						and event.Args
						and FAMILIAR_LOCATIONS[event.Args.Name]
						and not event._ap_familiar_spawn_gated then
						local name = event.Args.Name
						event.GameStateRequirements = {
							{ PathFalse = { "GameState", "AP_FamiliarChecked", name } },
							{ Path = { "CurrentRun" }, HasNone = { "ActiveBounty", "IsDreamRun" } },
						}
						event._ap_familiar_spawn_gated = true
						-- Swap the room's fated-list sub-icon gate to match.
						if roomData.ConditionalSubIconRequirements
							and not roomData._ap_familiar_subicon_gated then
							for _, req in ipairs(roomData.ConditionalSubIconRequirements) do
								if req.PathFalse
									and req.PathFalse[2] == "FamiliarsUnlocked"
									and req.PathFalse[3] == name then
									req.PathFalse = { "GameState", "AP_FamiliarChecked", name }
								end
							end
							roomData._ap_familiar_subicon_gated = true
						end
					end
				end
			end
		end
	end
end
