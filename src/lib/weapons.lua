---@meta _
---@diagnostic disable: lowercase-global

-- Weapons: starting weapon, weaponsanity shop checks, weapon clears and weapon item delivery.

-- ═══ Data ════════════════════════════════════════════════════════════════════

-- Maps initial_weapon slot data value to internal weapon name (order matches Options.py).
AP_STARTING_WEAPONS = {
	[0] = "WeaponStaffSwing",
	[1] = "WeaponDagger",
	[2] = "WeaponTorch",
	[3] = "WeaponAxe",
	[4] = "WeaponLob",
	[5] = "WeaponSuit",
}

-- Game internal weapon name → AP location name (for HandleWeaponShopPurchase wrap).
WEAPON_LOCATIONS = {
	WeaponStaffSwing = "Witch's Staff",
	WeaponDagger     = "Sister Blades",
	WeaponTorch      = "Umbral Flames",
	WeaponAxe        = "Moonstone Axe",
	WeaponLob        = "Argent Skull",
	WeaponSuit       = "Black Coat",
}

-- Game internal weapon name → AP "<Weapon> Clear" location name (fired on that weapon's first final-boss clear).
WEAPON_CLEAR_LOCATIONS = {
	WeaponStaffSwing = "Staff Weapon Clear",
	WeaponDagger     = "Daggers Weapon Clear",
	WeaponTorch      = "Torches Weapon Clear",
	WeaponAxe        = "Axe Weapon Clear",
	WeaponLob        = "Skull Weapon Clear",
	WeaponSuit       = "Coat Weapon Clear",
}

-- Weapon short tokens for room_weapon_based location names; MUST match ROOM_WEAPON_TOKENS in Locations.py.
WEAPON_SHORT = {
	WeaponStaffSwing = "Staff",
	WeaponDagger     = "Daggers",
	WeaponTorch      = "Torches",
	WeaponAxe        = "Axe",
	WeaponLob        = "Skull",
	WeaponSuit       = "Coat",
}

-- AP item name → game internal weapon name (keys match items.csv exactly).
WEAPON_ITEM_TO_NAME = {
	["Witch's Staff"]   = "WeaponStaffSwing",
	["Sister Blades"] = "WeaponDagger",
	["Umbral Flames"] = "WeaponTorch",
	["Moonstone Axe"]     = "WeaponAxe",
	["Argent Skull"]   = "WeaponLob",
	["Black Coat"]    = "WeaponSuit",
}

-- ═══ Logic ═══════════════════════════════════════════════════════════════════

-- ── Starting weapon ───────────────────────────────────────────────────────────
-- Ensures the hero starts with the AP-configured weapon via HeroData.DefaultWeapon (fresh saves) plus a CreateNewHero replacement (existing saves).

-- Point HeroData.DefaultWeapon at the configured starting weapon; called once from ready_late.
function H2AP_ApplyStartingWeapon()
	local settings = H2AP_LoadSettings()
	local target = settings and AP_STARTING_WEAPONS[settings.initial_weapon or 0]

	if target and HeroData then
		HeroData.DefaultWeapon = target
	end
end

-- Fixes GameState weapon unlock flags and WeaponShopItemData so the Training
-- Grounds UI reflects the correct state between runs. Safe to call many times.
function H2AP_InitWeaponState()
	if not GameState then return end
	local s = H2AP_LoadSettings()
	local t = s and AP_STARTING_WEAPONS[s.initial_weapon or 0]
	if not t or t == "WeaponStaffSwing" then return end

	-- Make staff purchasable with 1 silver; done here (not at load time) to avoid the App::Reset GC crash.
	if WeaponShopItemData and WeaponShopItemData["WeaponStaffSwing"] then
		WeaponShopItemData["WeaponStaffSwing"].Cost = { OreFSilver = 1 }
		WeaponShopItemData["WeaponStaffSwing"].OnActivateFunctionName = "ActivateWeaponKit"
	end

	-- Staff: remove from unlock tables so it shows as purchasable in the shop.
	GameState.WeaponsUnlocked["WeaponStaffSwing"] = nil
	GameState.WeaponsTouched["WeaponStaffSwing"] = nil
	GameState.WorldUpgrades["WeaponStaffSwing"] = nil
	GameState.WorldUpgradesAdded["WeaponStaffSwing"] = nil
	GameState.WorldUpgradesViewed["WeaponStaffSwing"] = nil
	GameState.WorldUpgradesRevealed["WeaponStaffSwing"] = nil

	-- Starting weapon: mark as unlocked and purchased so it shows as owned.
	GameState.WeaponsUnlocked[t] = true
	GameState.WeaponsTouched[t] = true
	GameState.WorldUpgrades[t] = true
	GameState.WorldUpgradesAdded[t] = true
	GameState.WorldUpgradesViewed[t] = true
	GameState.WorldUpgradesRevealed[t] = true
end

-- Replace CreateNewHero so existing saves swap the staff for the starting weapon; called once from ready_late.
function H2AP_InstallCreateNewHeroOverride()
	-- Capture the original exactly once so hot-reloads don't keep wrapping.
	if not _ap_orig_CreateNewHero then
		_ap_orig_CreateNewHero = CreateNewHero
	end

	function CreateNewHero(prevRun, args)
		local hero = _ap_orig_CreateNewHero(prevRun, args)
		local s = H2AP_LoadSettings()
		local t = s and AP_STARTING_WEAPONS[s.initial_weapon or 0]
		if not t or t == "WeaponStaffSwing" then return hero end
		if hero.Weapons[t] and not hero.Weapons["WeaponStaffSwing"] then return hero end
		hero.Weapons["WeaponStaffSwing"] = nil
		hero.Weapons["WeaponStaffBall"] = nil
		GameState.WeaponsUnlocked["WeaponStaffSwing"] = nil
		GameState.WeaponsTouched["WeaponStaffSwing"] = nil
		GameState.WorldUpgradesAdded["WeaponStaffSwing"] = nil
		hero.Weapons[t] = true
		local wdata = WeaponData[t]
		if wdata and wdata.SecondaryWeapon then
			hero.Weapons[wdata.SecondaryWeapon] = true
		end
		GameState.WeaponsUnlocked[t] = true
		GameState.WeaponsTouched[t] = true
		GameState.WorldUpgradesAdded[t] = true
		return hero
	end
end

-- ── Shop checks and weapon clears ────────────────────────────────────────────

-- AP location for a weapon shop slot, or nil when weaponsanity is off or the slot isn't a weapon.
function H2AP_WeaponShopLocation(item_name)
	local settings = H2AP_LoadSettings()
	if settings.weaponsanity == 1 then return WEAPON_LOCATIONS[item_name] end
	return nil
end

-- Record a distinct weapon clear on a final-boss kill and fire its "<Weapon> Clear" check under weaponsanity.
function H2AP_RecordWeaponClear()
	if type(GetEquippedWeapon) ~= "function" then return end
	local state = H2AP_LoadState()
	local weapon = GetEquippedWeapon()
	if weapon and not state.weapon_clears[weapon] then
		state.weapon_clears[weapon] = true
		local settings = H2AP_LoadSettings() or {}
		local loc = WEAPON_CLEAR_LOCATIONS[weapon]
		if loc and (settings.weaponsanity == true or settings.weaponsanity == 1) then
			H2AP_CheckLocation(loc)
		end
		H2AP_SaveState()
	end
end

-- Number of distinct weapons that have cleared a final boss (weapons goal).
function H2AP_DistinctWeaponClears()
	local n = 0
	for _ in pairs(H2AP_LoadState().weapon_clears) do n = n + 1 end
	return n
end

-- Weapons: set WeaponsUnlocked only (same shop-slot reasoning as tools), then refresh the live kit if the player is at it. Returns nil for other items.
function H2AP_WeaponGiveItem(item_name)
	local weapon = WEAPON_ITEM_TO_NAME[item_name]
	if not weapon then return nil end
	GameState.WeaponsUnlocked[weapon]        = true
	GameState.WeaponsTouched[weapon]         = true
	if CurrentRun then
		CurrentRun.WeaponsUnlocked = CurrentRun.WeaponsUnlocked or {}
		CurrentRun.WeaponsUnlocked[weapon] = true
	end
	pcall(function()
		local kit = GetWeaponKit and GetWeaponKit(weapon)
		if kit then
			kit.OnUsedFunctionName = "UseWeaponKit"
			if SetWeaponKitUseText then SetWeaponKitUseText(kit) end
			UseableOn({ Id = kit.ObjectId })
			SetAlpha({ Id = kit.ObjectId, Fraction = 1.0 })
		end
	end)
	print("[HadesII_AP] Gave weapon: " .. item_name .. " (" .. weapon .. ")")
	return true
end

-- ═══ Presentation ════════════════════════════════════════════════════════════

-- Replace weapon shop labels in TraitText under weaponsanity; the starting weapon slot is not a check, so it keeps its vanilla name.
function H2AP_WeaponRelabelTraitText(data)
	local settings = H2AP_LoadSettings() or {}
	if settings.weaponsanity ~= 1 then return end
	local start_weapon = AP_STARTING_WEAPONS[settings.initial_weapon or 0]
	local location_items = H2AP_ReadLocationItems() or {}
	for _, entry in ipairs(data.Texts) do
		local id = entry.Id
		local ap_location = id and id ~= start_weapon and WEAPON_LOCATIONS[id]
		if ap_location then
			H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
		end
	end
end
