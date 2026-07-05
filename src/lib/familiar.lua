---@meta _
---@diagnostic disable: lowercase-global

-- ── Familiar (animal companion) sanity ────────────────────────────────────────
-- Recruiting fires the location check (AP_FamiliarChecked) while the companion unlock is owned by the AP item (AP_FamiliarReceived), so an early item can't hide the encounter.

-- Game internal familiar name → AP location name.
FAMILIAR_LOCATIONS = {
	FrogFamiliar    = "Frinos Familiar Unlock Location",
	RavenFamiliar   = "Raki Familiar Unlock Location",
	CatFamiliar     = "Toula Familiar Unlock Location",
	HoundFamiliar   = "Hecuba Familiar Unlock Location",
	PolecatFamiliar = "Gale Familiar Unlock Location",
}

-- AP item name → game internal familiar name (keys must match items.csv exactly).
FAMILIAR_ITEM_TO_NAME = {
	["Frinos Familiar"] = "FrogFamiliar",
	["Raki Familiar"]   = "RavenFamiliar",
	["Toula Familiar"]  = "CatFamiliar",
	["Hecuba Familiar"] = "HoundFamiliar",
	["Gale Familiar"]   = "PolecatFamiliar",
}

-- Gate the wild encounter on AP_FamiliarChecked instead of FamiliarsUnlocked; idempotent and safe on every SetupMap.
function H2AP_PatchFamiliarGates()
	if GameState == nil then return end
	local settings = H2AP_LoadSettings() or {}
	if settings.familiarsanity ~= 1 then return end

	-- 1. FamiliarData SetupEvents: require AP_FamiliarChecked on the OverwriteSelf swaps so the wild encounter keeps offering the recruit until the check fires.
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

	-- 2. RoomData wild spawns: replace each ActivateFamiliar gate with a minimal AP_FamiliarChecked one so the check is reliably reachable.
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
