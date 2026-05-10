---@meta _
---@diagnostic disable: lowercase-global

-- Tunable amounts (per-item-received). Mirrors the original Hades 1
-- (Polycosmos) values; MaxHealth helper downgraded from +25 to +5.
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
	GameState.AP_HelperLodger = GameState.AP_HelperLodger or {
		MaxHealth        = 0,
		InitialMoney     = 0,
		BoonBoost        = 0,
		MaxHealthApplied = 0,
	}
	GameState.AP_TrapQueue = GameState.AP_TrapQueue or {
		MoneyPending  = 0,
		HealthPending = 0,
	}
end

-- ── Trap dispatch ────────────────────────────────────────────────────────────

function give_item_trap(item_name)
	init_lodger()
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

function give_item_helper(item_name)
	init_lodger()
	local L = GameState.AP_HelperLodger
	if item_name == "Max Health Helper" then
		L.MaxHealth = L.MaxHealth + 1
		ap_apply_max_health_helper()
	elseif item_name == "Initial Money Helper" then
		L.InitialMoney = L.InitialMoney + 1
		-- Effect applied at next StartNewRun via ap_apply_initial_money_helper.
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

-- Re-apply the cumulative MaxHealth bonus to HeroData.DefaultHero (and to
-- CurrentRun.Hero if a run is active). Idempotent: MaxHealthApplied tracks
-- what we've already added so reload / re-call won't double-stack.
function ap_apply_max_health_helper()
	init_lodger()
	local L = GameState.AP_HelperLodger
	local target = L.MaxHealth * HELPER_MAX_HEALTH_PER
	local delta  = target - L.MaxHealthApplied
	if delta == 0 then return end
	if HeroData and HeroData.DefaultHero then
		HeroData.DefaultHero.MaxHealth = (HeroData.DefaultHero.MaxHealth or 0) + delta
	end
	if CurrentRun and CurrentRun.Hero then
		CurrentRun.Hero.MaxHealth = (CurrentRun.Hero.MaxHealth or 0) + delta
		CurrentRun.Hero.Health    = math.min(
			(CurrentRun.Hero.Health or 0) + delta, CurrentRun.Hero.MaxHealth)
		if ShowHealthUI then ShowHealthUI() end
	end
	L.MaxHealthApplied = target
end

-- Add the persistent starting-money bonus on top of vanilla starting money.
-- Called from the StartNewRun override in reload.lua after the base call.
function ap_apply_initial_money_helper()
	init_lodger()
	local L = GameState.AP_HelperLodger
	if L.InitialMoney <= 0 then return end
	AddResource("Money", L.InitialMoney * HELPER_INITIAL_MONEY_PER, _PLUGIN.guid)
end

-- Returns the additive rarity boost (0..1) to apply to every rarity bucket.
function ap_boon_boost_pct()
	init_lodger()
	return (GameState.AP_HelperLodger.BoonBoost or 0) * HELPER_BOON_BOOST_PER
end

-- ── Mid-run trap drain ───────────────────────────────────────────────────────

-- Mirrors PolycosmosTrapManager.ShouldAvoidTriggerTraps — avoid touching
-- CurrentRun mid-transition / mid-load (those are the documented crash spots).
local function unsafe_to_apply_traps()
	if CurrentRun == nil or CurrentRun.Hero == nil or CurrentRun.CurrentRoom == nil then
		return true
	end
	if (CurrentRun.RunDepthCache or 0) < 1 then return true end
	if not IsEmpty(CurrentRun.BlockTimerFlags or {}) then return true end
	if IsInputAllowed and not IsInputAllowed({}) then return true end
	return false
end

function ap_process_trap_queue()
	init_lodger()
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
			ap_notify("Trap: lost " .. (n * TRAP_MONEY_AMOUNT) .. " Money",
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
			ap_notify("Trap: " .. n .. "x Health Punishment",
				{ 1.0, 0.5, 0.5, 1.0 })
			if ShowHealthUI then ShowHealthUI() end
		end
	end
end
