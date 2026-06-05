---@meta _
---@diagnostic disable: lowercase-global

-- ── Starting weapon enforcement ───────────────────────────────────────────────
-- Ensures the hero starts with the weapon configured in AP slot data.
-- Two complementary approaches cover every case:
--   1. HeroData.DefaultWeapon mutation — used by CreateNewHero when prevRun == nil
--      (truly fresh save). Safe to do here because HeroData is populated by the
--      time this file is imported (game scripts load before on_ready fires).
--   2. Direct CreateNewHero replacement — intercepts the prevRun != nil path so
--      that existing saves that already have the staff also get corrected.
--      _ap_orig_CreateNewHero is only captured once; the guard prevents hot-reloads
--      from stacking additional layers.

-- Maps initial_weapon slot data value to internal weapon name.
-- Order matches Options.py: Staff=0, Daggers=1, Torches=2, Axe=3, Skull=4, Coat=5
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
	WeaponStaffSwing = "Staff Weapon Unlock Location",
	WeaponDagger     = "Daggers Weapon Unlock Location",
	WeaponTorch      = "Torches Weapon Unlock Location",
	WeaponAxe        = "Axe Weapon Unlock Location",
	WeaponLob        = "Skull Weapon Unlock Location",
	WeaponSuit       = "Coat Weapon Unlock Location",
}

-- AP item name → game internal weapon name (for H2AP_GiveItem).
-- Keys must match the bare item names from the apworld's items.csv exactly (no
-- " Item" suffix — that suffix only exists on the location names).
WEAPON_ITEM_TO_NAME = {
	["Staff Weapon Unlock"]   = "WeaponStaffSwing",
	["Daggers Weapon Unlock"] = "WeaponDagger",
	["Torches Weapon Unlock"] = "WeaponTorch",
	["Axe Weapon Unlock"]     = "WeaponAxe",
	["Skull Weapon Unlock"]   = "WeaponLob",
	["Coat Weapon Unlock"]    = "WeaponSuit",
}

-- Game internal aspect name → AP location name (third aspect entry per weapon
-- in WeaponShopData; gated by CharacterGrantsHiddenAspect01 text-line records).
HIDDEN_ASPECT_LOCATIONS = {
	StaffRaiseDeadAspect = "Staff Weapon Anubis Aspect Unlock Location",
	DaggerTripleAspect   = "Daggers Weapon Morrigan Aspect Unlock Location",
	TorchAutofireAspect  = "Torches Weapon Supay Aspect Unlock Location",
	AxeRallyAspect       = "Axe Weapon Nergal Aspect Unlock Location",
	LobGunAspect         = "Skull Weapon Hel Aspect Unlock Location",
	SuitComboAspect      = "Coat Weapon Shiva Aspect Unlock Location",
}

-- AP item name → game internal aspect name (for H2AP_GiveItem).
-- Keys are the bare apworld item names (items.csv) — these carry neither the
-- weapon prefix nor the " Item" suffix that the location names use.
HIDDEN_ASPECT_ITEM_TO_NAME = {
	["Anubis Aspect Unlock"]   = "StaffRaiseDeadAspect",
	["Morrigan Aspect Unlock"] = "DaggerTripleAspect",
	["Supay Aspect Unlock"]    = "TorchAutofireAspect",
	["Nergal Aspect Unlock"]   = "AxeRallyAspect",
	["Hel Aspect Unlock"]      = "LobGunAspect",
	["Shiva Aspect Unlock"]    = "SuitComboAspect",
}

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

	-- Make staff purchasable with 1 silver so it appears as a buyable item
	-- rather than the free default. Done here (not at load time) to avoid
	-- mutating game data tables during Lua initialisation, which triggers
	-- the App::Reset GC crash.
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
