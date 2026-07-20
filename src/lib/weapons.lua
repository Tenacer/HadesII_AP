---@meta _
---@diagnostic disable: lowercase-global

-- ── Starting weapon enforcement ───────────────────────────────────────────────
-- Ensures the hero starts with the AP-configured weapon via HeroData.DefaultWeapon (fresh saves) plus a CreateNewHero replacement (existing saves).

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

-- Game internal aspect name → AP location name.
HIDDEN_ASPECT_LOCATIONS = {
	StaffRaiseDeadAspect = "Anubis",
	DaggerTripleAspect   = "Morrigan",
	TorchAutofireAspect  = "Supay",
	AxeRallyAspect       = "Nergal",
	LobGunAspect         = "Hel",
	SuitComboAspect      = "Shiva",
}

-- AP item name → game internal aspect name (keys match items.csv exactly).
HIDDEN_ASPECT_ITEM_TO_NAME = {
	["Anubis"]   = "StaffRaiseDeadAspect",
	["Morrigan"] = "DaggerTripleAspect",
	["Supay"]    = "TorchAutofireAspect",
	["Nergal"]   = "AxeRallyAspect",
	["Hel"]      = "LobGunAspect",
	["Shiva"]    = "SuitComboAspect",
}

-- ── Aspect sanity: base + standard aspects (aspectsanity) ─────────────────────

-- Game internal standard aspect trait → AP location name.
STANDARD_ASPECT_LOCATIONS = {
	StaffClearCastAspect     = "Circe",
	StaffSelfHitAspect       = "Momus",
	DaggerBlockAspect        = "Artemis",
	DaggerHomingThrowAspect  = "Pan",
	TorchDetonateAspect      = "Moros",
	TorchSprintRecallAspect  = "Eos",
	AxeArmCastAspect         = "Charon",
	AxePerfectCriticalAspect = "Thanatos",
	LobCloseAttackAspect     = "Medea",
	LobImpulseAspect         = "Persephone",
	SuitMarkCritAspect       = "Nyx",
	SuitHexAspect            = "Selene",
}

-- AP item name → game internal standard aspect trait (keys match items.csv).
STANDARD_ASPECT_ITEM_TO_NAME = {
	["Circe"]      = "StaffClearCastAspect",
	["Momus"]      = "StaffSelfHitAspect",
	["Artemis"]    = "DaggerBlockAspect",
	["Pan"]        = "DaggerHomingThrowAspect",
	["Moros"]      = "TorchDetonateAspect",
	["Eos"]        = "TorchSprintRecallAspect",
	["Charon"]     = "AxeArmCastAspect",
	["Thanatos"]   = "AxePerfectCriticalAspect",
	["Medea"]      = "LobCloseAttackAspect",
	["Persephone"] = "LobImpulseAspect",
	["Nyx"]        = "SuitMarkCritAspect",
	["Selene"]     = "SuitHexAspect",
}

-- Game internal base aspect trait → AP location name.
BASE_ASPECT_LOCATIONS = {
	BaseStaffAspect            = "Staff Melinoe",
	DaggerBackstabAspect       = "Daggers Melinoe",
	TorchSpecialDurationAspect = "Torches Melinoe",
	AxeRecoveryAspect          = "Axe Melinoe",
	LobAmmoBoostAspect         = "Skull Melinoe",
	BaseSuitAspect             = "Coat Melinoe",
}

-- AP item name → game internal base aspect trait (keys match items.csv).
BASE_ASPECT_ITEM_TO_NAME = {
	["Staff Melinoe"]   = "BaseStaffAspect",
	["Daggers Melinoe"] = "DaggerBackstabAspect",
	["Torches Melinoe"] = "TorchSpecialDurationAspect",
	["Axe Melinoe"]     = "AxeRecoveryAspect",
	["Skull Melinoe"]   = "LobAmmoBoostAspect",
	["Coat Melinoe"]    = "BaseSuitAspect",
}

-- Base aspect trait → { weapon, Bones cost } for the injected purchasable shop entry.
BASE_ASPECT_SHOP = {
	BaseStaffAspect            = { weapon = "WeaponStaffSwing", cost = 100 },
	DaggerBackstabAspect       = { weapon = "WeaponDagger",     cost = 150 },
	TorchSpecialDurationAspect = { weapon = "WeaponTorch",      cost = 200 },
	AxeRecoveryAspect          = { weapon = "WeaponAxe",        cost = 250 },
	LobAmmoBoostAspect         = { weapon = "WeaponLob",        cost = 300 },
	BaseSuitAspect             = { weapon = "WeaponSuit",       cost = 350 },
}

-- initial_weapon slot → ordered [base, first standard, second standard] traits.
-- Index into the slot matches the initial_aspect option (0=base, 1/2=standards).
ASPECT_BY_WEAPON = {
	[0] = { "BaseStaffAspect",            "StaffClearCastAspect",  "StaffSelfHitAspect" },
	[1] = { "DaggerBackstabAspect",       "DaggerBlockAspect",     "DaggerHomingThrowAspect" },
	[2] = { "TorchSpecialDurationAspect", "TorchDetonateAspect",   "TorchSprintRecallAspect" },
	[3] = { "AxeRecoveryAspect",          "AxeArmCastAspect",      "AxePerfectCriticalAspect" },
	[4] = { "LobAmmoBoostAspect",         "LobCloseAttackAspect",  "LobImpulseAspect" },
	[5] = { "BaseSuitAspect",             "SuitMarkCritAspect",    "SuitHexAspect" },
}

-- The starting aspect trait (granted, not a check), or nil when aspect sanity is off.
function H2AP_InitialAspectTrait()
	local s = H2AP_LoadSettings()
	if not (s and s.aspectsanity == 1) then return nil end
	local slot = ASPECT_BY_WEAPON[s.initial_weapon or 0]
	return slot and slot[(s.initial_aspect or 0) + 1]
end

-- Returns the ScreenData.WeaponShop category that owns a weapon.
local function weapon_shop_category(weaponName)
	if not (ScreenData and ScreenData.WeaponShop and ScreenData.WeaponShop.ItemCategories) then return nil end
	for _, category in ipairs(ScreenData.WeaponShop.ItemCategories) do
		if category.WeaponName == weaponName then return category end
	end
	return nil
end

-- Inject the base aspects as purchasable shop entries (Bones = MetaCurrency) and stop the
-- free FreeUnlocks grant so each becomes an AP check. Idempotent; the starting aspect is skipped.
function H2AP_InitBaseAspectShop()
	if GameState == nil then return end
	local s = H2AP_LoadSettings()
	if not (s and s.aspectsanity == 1 and WeaponShopItemData) then return end
	local start_trait = H2AP_InitialAspectTrait()
	for trait, data in pairs(BASE_ASPECT_SHOP) do
		if trait ~= start_trait then
			if WeaponShopItemData[trait] == nil then
				WeaponShopItemData[trait] = {
					Name = trait,
					WeaponName = data.weapon,
					HideAfterPurchased = true,
					IconScale = 0.8,
					UnlockTextId = "WeaponShopAspectUnlock",
					Cost = { MetaCurrency = data.cost },
					GameStateRequirements = {
						{ PathTrue = { "GameState", "WorldUpgrades", "WorldUpgradeWeaponUpgradeSystem" } },
					},
				}
			end
			local category = weapon_shop_category(data.weapon)
			if category then
				local present = false
				for _, name in ipairs(category) do
					if name == trait then present = true break end
				end
				if not present then table.insert(category, 1, trait) end
			end
		end
	end
	-- Suppress the free base-aspect auto-grant (WeaponUpgradeLogic.OpenWeaponUpgradeScreen).
	if ScreenData and ScreenData.WeaponUpgradeScreen and ScreenData.WeaponUpgradeScreen.FreeUnlocks then
		for _, data in pairs(BASE_ASPECT_SHOP) do
			ScreenData.WeaponUpgradeScreen.FreeUnlocks[data.weapon] = nil
		end
	end
end

-- Grant the chosen starting aspect for the initial weapon so it is playable, and mark it
-- already-obtained so its shop slot never appears as a check.
function H2AP_GrantInitialAspect()
	if GameState == nil then return end
	local trait = H2AP_InitialAspectTrait()
	if not trait then return end
	GameState.WeaponsUnlocked[trait]        = true
	GameState.WorldUpgradesAdded[trait]     = true
	GameState.WorldUpgradesViewed[trait]    = true
	GameState.WorldUpgradesRevealed[trait]  = true
	if CurrentRun then
		CurrentRun.WeaponsUnlocked = CurrentRun.WeaponsUnlocked or {}
		CurrentRun.WeaponsUnlocked[trait] = true
	end
end

-- QoL: grant the weapon aspect purchase system from the start (aspect_system_unlocked).
function H2AP_ApplyAspectSystemUnlock()
	if GameState == nil then return end
	local s = H2AP_LoadSettings()
	if not (s and s.aspect_system_unlocked == 1) then return end
	GameState.WorldUpgrades.WorldUpgradeWeaponUpgradeSystem         = true
	GameState.WorldUpgradesAdded.WorldUpgradeWeaponUpgradeSystem    = true
	GameState.WorldUpgradesViewed.WorldUpgradeWeaponUpgradeSystem   = true
	GameState.WorldUpgradesRevealed.WorldUpgradeWeaponUpgradeSystem = true
end

local settings = H2AP_LoadSettings()
local target = settings and AP_STARTING_WEAPONS[settings.initial_weapon or 0]

if target and HeroData then
	HeroData.DefaultWeapon = target
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
