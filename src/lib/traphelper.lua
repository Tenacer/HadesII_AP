---@meta _
---@diagnostic disable: lowercase-global

-- Tunable per-item amounts, mirroring Polycosmos.
local TRAP_MONEY_AMOUNT        = 100
local TRAP_HEALTH_FRACTION     = 0.25     -- of MaxHealth
local HELPER_MAX_HEALTH_PER    = 5
local HELPER_INITIAL_MONEY_PER = 25
local HELPER_BOON_BOOST_PER    = 0.01     -- 1% per rarity bucket

TRAP_ITEMS   = {
	["Money Punishment"]  = true,
	["Health Punishment"] = true,
}

HELPER_ITEMS = {
	["Max Health Helper"]    = true,
	["Boon Boost Helper"]    = true,
	["Initial Money Helper"] = true,
}

local function init_lodger()
	if GameState == nil then return false end
	GameState.AP_HelperLodger = GameState.AP_HelperLodger or {
		MaxHealth        = 0,
		InitialMoney     = 0,
		BoonBoost        = 0,
	}
	GameState.AP_TrapQueue = GameState.AP_TrapQueue or {
		MoneyPending  = 0,
		HealthPending = 0,
	}
	return true
end

-- ── Trap dispatch ────────────────────────────────────────────────────────────

function H2AP_GiveItemTrap(item_name)
	if not init_lodger() then return false end
	if item_name == "Money Punishment" then
		GameState.AP_TrapQueue.MoneyPending = GameState.AP_TrapQueue.MoneyPending + 1
	elseif item_name == "Health Punishment" then
		GameState.AP_TrapQueue.HealthPending = GameState.AP_TrapQueue.HealthPending + 1
	end
	print("[HadesII_AP] Trap queued: " .. item_name
		.. " (MoneyPending=" .. GameState.AP_TrapQueue.MoneyPending
		.. " HealthPending=" .. GameState.AP_TrapQueue.HealthPending .. ")")
	return true
end

-- ── Helper dispatch ──────────────────────────────────────────────────────────

-- Apply a max-health bonus as a RoomRewardMaxHealthTrait — a raw MaxHealth write would be wiped on the next trait recalc.
local function apply_max_health_trait(amount)
	if amount <= 0 then return false end
	if not (CurrentRun and CurrentRun.Hero) then return false end
	if not (GetProcessedTraitData and AddTraitToHero) then return false end
	local ok = pcall(function()
		local healthTraitData = GetProcessedTraitData({
			Unit = CurrentRun.Hero, TraitName = "RoomRewardMaxHealthTrait" })
		healthTraitData.PropertyChanges[1].ChangeValue = amount
		AddTraitToHero({ TraitData = healthTraitData })
	end)
	return ok
end

function H2AP_GiveItemHelper(item_name)
	if not init_lodger() then return false end
	local L = GameState.AP_HelperLodger
	if item_name == "Max Health Helper" then
		L.MaxHealth = L.MaxHealth + 1
		-- Grant this item's share immediately if a run is live; the cumulative bonus re-applies each run.
		if apply_max_health_trait(HELPER_MAX_HEALTH_PER) then
			if FrameState then FrameState.RequestUpdateHealthUI = true end
		end
	elseif item_name == "Initial Money Helper" then
		L.InitialMoney = L.InitialMoney + 1
		-- Effect applied at next StartNewRun via H2AP_ApplyInitialMoneyHelper.
	elseif item_name == "Boon Boost Helper" then
		L.BoonBoost = L.BoonBoost + 1
		-- Effect applied via the GetRarityChances override.
	end
	print("[HadesII_AP] Helper applied: " .. item_name
		.. " (MH=" .. L.MaxHealth
		.. " IM=" .. L.InitialMoney
		.. " BB=" .. L.BoonBoost .. ")")
	return true
end

-- Apply the full cumulative MaxHealth bonus to the freshly-built run hero at StartNewRun.
function H2AP_ApplyMaxHealthHelper()
	if not init_lodger() then return end
	local L = GameState.AP_HelperLodger
	local bonus = L.MaxHealth * HELPER_MAX_HEALTH_PER
	if bonus <= 0 then return end
	if apply_max_health_trait(bonus) and CurrentRun and CurrentRun.Hero then
		CurrentRun.Hero.Health = CurrentRun.Hero.MaxHealth
		if FrameState then FrameState.RequestUpdateHealthUI = true end
	end
end

-- Add the persistent starting-money bonus on top of vanilla starting money.
function H2AP_ApplyInitialMoneyHelper()
	if not init_lodger() then return end
	local L = GameState.AP_HelperLodger
	if L.InitialMoney <= 0 then return end
	AddResource("Money", L.InitialMoney * HELPER_INITIAL_MONEY_PER, _PLUGIN.guid)
end

-- Returns the additive rarity boost (0..1) to apply to every rarity bucket.
function H2AP_BoonBoostPct()
	if not init_lodger() then return 0 end
	return (GameState.AP_HelperLodger.BoonBoost or 0) * HELPER_BOON_BOOST_PER
end

-- ── Mid-run trap drain ───────────────────────────────────────────────────────

-- Avoid touching CurrentRun mid-transition / mid-load (the documented crash spots).
local function unsafe_to_apply_traps()
	if CurrentRun == nil or CurrentRun.Hero == nil or CurrentRun.CurrentRoom == nil then
		return true
	end
	if (CurrentRun.RunDepthCache or 0) < 1 then return true end
	if not IsEmpty(CurrentRun.BlockTimerFlags or {}) then return true end
	if IsInputAllowed and not IsInputAllowed({}) then return true end
	return false
end

function H2AP_ProcessTrapQueue()
	if not init_lodger() then return end
	if unsafe_to_apply_traps() then return end
	local q = GameState.AP_TrapQueue

	if q.MoneyPending > 0 then
		local money = (GetResourceAmount and GetResourceAmount("Money")) or 0
		local maxApplicable = math.floor(money / TRAP_MONEY_AMOUNT)
		local n = math.min(maxApplicable, q.MoneyPending)
		if n > 0 then
			SpendResource("Money", n * TRAP_MONEY_AMOUNT, _PLUGIN.guid, {
				NoLifetimeEffect = true,
				SkipQuestStatusCheck = true,
				SkipResourceSpendPresentation = true,
			})
			q.MoneyPending = q.MoneyPending - n
			H2AP_Notify("Trap: lost " .. (n * TRAP_MONEY_AMOUNT) .. " Money",
				{ 1.0, 0.5, 0.5, 1.0 })
		end
	end

	if q.HealthPending > 0 then
		local hero = CurrentRun.Hero
		local damage = math.floor((hero.MaxHealth or 0) * TRAP_HEALTH_FRACTION)
		if damage > 0 then
			local n = q.HealthPending
			hero.Health = math.max((hero.Health or 0) - damage * n, 1)
			q.HealthPending = 0
			H2AP_Notify("Trap: " .. n .. "x Health Punishment",
				{ 1.0, 0.5, 0.5, 1.0 })
			if ShowHealthUI then ShowHealthUI() end
		end
	end
end
