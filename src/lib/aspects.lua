---@meta _
---@diagnostic disable: lowercase-global

-- Aspects: hidden, base and standard aspect sanity shop checks and aspect item delivery.

-- ═══ Data ════════════════════════════════════════════════════════════════════

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

-- ═══ Logic ═══════════════════════════════════════════════════════════════════

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

-- AP location for an aspect shop slot, or nil when its aspect sanity is off or the slot isn't an aspect.
function H2AP_AspectShopLocation(item_name)
	local settings = H2AP_LoadSettings()
	if settings.hidden_aspectsanity == 1 and HIDDEN_ASPECT_LOCATIONS[item_name] then
		return HIDDEN_ASPECT_LOCATIONS[item_name]
	end
	if settings.aspectsanity == 1 then
		return STANDARD_ASPECT_LOCATIONS[item_name] or BASE_ASPECT_LOCATIONS[item_name]
	end
	return nil
end

-- HasAnyAspectUnlocked wrap: under aspect sanity, re-point it at WeaponsUnlocked so the kit prompt tracks the AP item, not the shop check.
function H2AP_OnHasAnyAspectUnlocked(base, weaponName)
	local settings = H2AP_LoadSettings()
	if not (settings and (settings.hidden_aspectsanity == 1 or settings.aspectsanity == 1)) then
		return base(weaponName)
	end
	for traitName, traitData in pairs(TraitSetData.Aspects) do
		if traitData.RequiredWeapon == weaponName and GameState.WeaponsUnlocked[traitName] then
			return true
		end
	end
	return false
end

-- Aspects: set WeaponsUnlocked only (same shop-slot reasoning as tools) and refresh the kit prompt. Returns nil for other items.
function H2AP_AspectGiveItem(item_name)
	-- Hidden aspects: set WeaponsUnlocked only (same shop-slot reasoning as tools).
	local aspect = HIDDEN_ASPECT_ITEM_TO_NAME[item_name]
	if aspect then
		GameState.WeaponsUnlocked[aspect]        = true
		if CurrentRun then
			CurrentRun.WeaponsUnlocked = CurrentRun.WeaponsUnlocked or {}
			CurrentRun.WeaponsUnlocked[aspect] = true
		end
		-- Refresh the kit's aspect prompt if the player is at the kit when it arrives.
		pcall(function() if UpdateWeaponKits then UpdateWeaponKits() end end)
		print("[HadesII_AP] Gave hidden aspect: " .. item_name .. " (" .. aspect .. ")")
		return true
	end
	-- Base + standard aspects: same WeaponsUnlocked delivery as hidden aspects.
	local base_std = STANDARD_ASPECT_ITEM_TO_NAME[item_name] or BASE_ASPECT_ITEM_TO_NAME[item_name]
	if base_std then
		GameState.WeaponsUnlocked[base_std] = true
		if CurrentRun then
			CurrentRun.WeaponsUnlocked = CurrentRun.WeaponsUnlocked or {}
			CurrentRun.WeaponsUnlocked[base_std] = true
		end
		pcall(function() if UpdateWeaponKits then UpdateWeaponKits() end end)
		print("[HadesII_AP] Gave aspect: " .. item_name .. " (" .. base_std .. ")")
		return true
	end
	return nil
end

-- ═══ Presentation ════════════════════════════════════════════════════════════

-- Replace aspect shop labels in TraitText under hidden/base/standard aspect sanity; the starting aspect is not a check, so it keeps its vanilla name.
function H2AP_AspectRelabelTraitText(data)
	local settings = H2AP_LoadSettings() or {}
	local do_hidden = settings.hidden_aspectsanity == 1
	local do_base_std = settings.aspectsanity == 1
	if not (do_hidden or do_base_std) then return end
	local start_aspect = H2AP_InitialAspectTrait()
	local location_items = H2AP_ReadLocationItems() or {}
	for _, entry in ipairs(data.Texts) do
		local id = entry.Id
		if id then
			local ap_location = (do_hidden and HIDDEN_ASPECT_LOCATIONS[id])
				or (do_base_std and id ~= start_aspect
					and (STANDARD_ASPECT_LOCATIONS[id] or BASE_ASPECT_LOCATIONS[id]))
			if ap_location then
				H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
			end
		end
	end
end
