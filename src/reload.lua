---@meta _
---@diagnostic disable: lowercase-global

-- Hot-reloadable AP-icon / text-label helpers and SJSON hook handlers; library modules import from ready.lua / ready_late.lua instead.

-- ── SJSON hook handlers ───────────────────────────────────────────────────────

-- initial_weapon slot value → internal weapon name; kept local because the SJSON hooks can fire before lib/weapons.lua loads.
local STARTING_WEAPON_NAMES = {
	[0] = "WeaponStaffSwing",
	[1] = "WeaponDagger",
	[2] = "WeaponTorch",
	[3] = "WeaponAxe",
	[4] = "WeaponLob",
	[5] = "WeaponSuit",
}

-- initial_weapon slot → [base, first standard, second standard] traits (local for the same reason).
local ASPECT_TRAITS_BY_WEAPON = {
	[0] = { "BaseStaffAspect",            "StaffClearCastAspect",  "StaffSelfHitAspect" },
	[1] = { "DaggerBackstabAspect",       "DaggerBlockAspect",     "DaggerHomingThrowAspect" },
	[2] = { "TorchSpecialDurationAspect", "TorchDetonateAspect",   "TorchSprintRecallAspect" },
	[3] = { "AxeRecoveryAspect",          "AxeArmCastAspect",      "AxePerfectCriticalAspect" },
	[4] = { "LobAmmoBoostAspect",         "LobCloseAttackAspect",  "LobImpulseAspect" },
	[5] = { "BaseSuitAspect",             "SuitMarkCritAspect",    "SuitHexAspect" },
}

function sjson_TraitText(data)
	local settings = H2AP_LoadSettings() or {}
	local do_weapon = settings.weaponsanity == 1
	local do_tool = settings.toolsanity == 1
	local do_aspect = settings.hidden_aspectsanity == 1
	local do_base_std = settings.aspectsanity == 1
	if not (do_weapon or do_tool or do_aspect or do_base_std) then return end

	-- The starting weapon / starting aspect shop slots are not AP checks, so keep vanilla names.
	local start_weapon = STARTING_WEAPON_NAMES[settings.initial_weapon or 0]
	local start_slot = ASPECT_TRAITS_BY_WEAPON[settings.initial_weapon or 0]
	local start_aspect = start_slot and start_slot[(settings.initial_aspect or 0) + 1]

	-- weapons.lua may not have loaded when this hook fires; the tables are needed for the relabel.
	do_base_std = do_base_std and STANDARD_ASPECT_LOCATIONS ~= nil

	local location_items = H2AP_ReadLocationItems() or {}
	for _, entry in ipairs(data.Texts) do
		local id = entry.Id
		if id then
			local ap_location = (do_weapon and id ~= start_weapon and WEAPON_LOCATIONS[id])
				or (do_tool and TOOL_LOCATIONS[id])
				or (do_aspect and HIDDEN_ASPECT_LOCATIONS[id])
				or (do_base_std and id ~= start_aspect
					and (STANDARD_ASPECT_LOCATIONS[id] or BASE_ASPECT_LOCATIONS[id]))
			if ap_location then
				H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
			end
		end
	end
end
