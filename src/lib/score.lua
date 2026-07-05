---@meta _
---@diagnostic disable: lowercase-global

-- ── Score tracking ────────────────────────────────────────────────────────────

-- Per-biome score points (room-name prefix → points per regular room), ramping 1→4 per route.
local BIOME_POINTS = {
	F = 1,  -- Erebus
	G = 2,  -- Oceanus
	H = 3,  -- Mourning Fields
	I = 4,  -- Tartarus (Chronos route)
	N = 1,  -- Ephyra
	O = 2,  -- Thessaly
	P = 3,  -- Olympus
	Q = 4,  -- Summit (Typhon route)
}

-- Route a room belongs to, keyed by room-name prefix; each route accumulates score against its own budget.
local ROUTE_FOR_BIOME = {
	F = "underworld", G = "underworld", H = "underworld", I = "underworld",
	N = "surface",    O = "surface",    P = "surface",    Q = "surface",
}

-- Encounter types that do NOT award room-clear score: non-combat utility rooms and optional challenge side-rooms.
local SCORE_EXCLUDED_ENCOUNTER_TYPES = {
	NonCombat      = true,
	PerfectClear   = true,
	TimeChallenge  = true,
	EliteChallenge = true,
}

local function encounter_awards_score(encounter)
	if not encounter then return false end
	local etype = encounter.EncounterType
	if etype == nil then return false end
	return not SCORE_EXCLUDED_ENCOUNTER_TYPES[etype]
end

-- ── Room-based location systems (room_based / room_weapon_based) ───────────────
-- Per-route max run depth; MUST match the apworld's UNDERWORLD_ROOM_MAX / SURFACE_ROOM_MAX in Locations.py.
-- TODO(confirm): estimates — update both sides from the depths logged during a full run.
local ROOM_DEPTH_MAX = { underworld = 40, surface = 36 }
-- Run depth where Tartarus begins; the Chronos-kill auto-grant covers from here to the underworld max.
local UNDERWORLD_AUTOGRANT_FROM = 26
local ROUTE_LABEL = { underworld = "Underworld", surface = "Surface" }

-- Resolves the active location system from slot data (accepts raw int or option string).
function H2AP_LocationSystem()
	local s = H2AP_LoadSettings() or {}
	local v = s.location_system
	if v == 1 or v == "room_based" then return "room" end
	if v == 2 or v == "room_weapon_based" then return "room_weapon" end
	return "score"
end

-- Two-digit zero-padded depth, matching the apworld's room_location_name (%02d).
local function pad_depth(n) return string.format("%02d", n) end

-- Fire the room check for one (route, depth[, weapon]); out-of-range depths log and no-op.
local function H2AP_FireRoomCheck(route, depth, system)
	local maxd = ROOM_DEPTH_MAX[route]
	if not maxd or depth < 1 then return end
	if depth > maxd then
		print("[HadesII_AP] WARNING: " .. route .. " run depth " .. depth
			.. " exceeds ROOM_DEPTH_MAX (" .. maxd .. ") — bump the constant (mod + apworld)")
		return
	end
	local label = ROUTE_LABEL[route]
	local name = "Clear " .. label .. " Room " .. pad_depth(depth)
	if system == "room_weapon" then
		local weapon = type(GetEquippedWeapon) == "function" and GetEquippedWeapon() or nil
		local token = weapon and WEAPON_SHORT[weapon]
		if not token then return end  -- unknown/no weapon: nothing to credit
		name = name .. " " .. token
	end
	H2AP_CheckLocation(name)
end

-- Score-check gap curve: slow rise → plateau → final ramp, tuned by the constants below.
local SCORE_P1, SCORE_P2 = 0.25, 0.70      -- end of first rise / start of finale (fractions)
local SCORE_G0, SCORE_G1, SCORE_G2 = 2, 11, 18  -- start / plateau / end gap (points)

local function smoothstep(x)
	if x < 0 then x = 0 elseif x > 1 then x = 1 end
	return x * x * (3 - 2 * x)
end

-- Integer cumulative-score thresholds for a route budgeted at N checks, cached per N.
local _threshold_cache = {}
local function score_thresholds(N)
	if N < 1 then return {} end
	local cached = _threshold_cache[N]
	if cached then return cached end
	local t, cum = {}, 0
	for n = 1, N do
		local frac = (N > 1) and (n - 1) / (N - 1) or 0
		local g
		if frac <= SCORE_P1 then
			g = SCORE_G0 + (SCORE_G1 - SCORE_G0) * smoothstep(frac / SCORE_P1)
		elseif frac < SCORE_P2 then
			g = SCORE_G1
		else
			g = SCORE_G1 + (SCORE_G2 - SCORE_G1) * smoothstep((frac - SCORE_P2) / (1 - SCORE_P2))
		end
		cum = cum + math.floor(g + 0.5)  -- integer points per check
		t[n] = cum
	end
	_threshold_cache[N] = t
	return t
end

-- Cumulative score → number of score checks unlocked for a budget of N.
local function checks_for_score(s, N)
	if s < 1 or N < 1 then return 0 end
	local t = score_thresholds(N)
	local count = 0
	for n = 1, N do
		if s >= t[n] then count = n else break end
	end
	return count
end

-- Points remaining until the next score check; nil once the budget is capped.
function H2AP_PointsToNextScoreCheck(s, N)
	if N < 1 then return nil end
	local t = score_thresholds(N)
	local unlocked = checks_for_score(s, N)
	if unlocked >= N then return nil end
	return t[unlocked + 1] - s
end

-- True when the score-check budget is split per route (separate mode).
local function H2AP_ScoreSeparate(settings)
	local mode = settings.score_split_mode
	return mode == 1 or mode == "separate"
end

-- Per-route check budgets (underworld, surface); MUST match Locations.score_check_split on the apworld side.
local function H2AP_ScoreBudgets(settings, max_checks)
	if not H2AP_ScoreSeparate(settings) then
		return max_checks, 0
	end
	local ratio = settings.surface_score_ratio
	if type(ratio) ~= "number" then ratio = 40 end
	local surface_budget = math.floor(max_checks * ratio / 100)
	return max_checks - surface_budget, surface_budget
end

local function H2AP_ScoreChecksSent(state, settings, max_checks)
	if not H2AP_ScoreSeparate(settings) then
		return checks_for_score(state.score or 0, max_checks), 0
	end
	local underworld_budget, surface_budget = H2AP_ScoreBudgets(settings, max_checks)
	-- The threshold curve already tops out exactly at the budget, so no clamp.
	local under_checks   = checks_for_score(state.score_underworld or 0, underworld_budget)
	local surface_checks = checks_for_score(state.score_surface or 0,    surface_budget)
	return under_checks, surface_checks
end

-- Evaluate the BossDefeats goal after a boss kill and flag victory if met (True Ending victory fires in death.lua instead).
function H2AP_CheckBossDefeatsVictory()
	local settings = H2AP_LoadSettings() or {}
	if settings.true_ending == true or settings.true_ending == 1 then return end

	local state = H2AP_LoadState()
	if state.victory then return end

	local chronos = state.chronos_kills or 0
	local typhon  = state.typhon_kills or 0
	local mode    = settings.boss_defeats_mode
	local met
	if mode == 1 or mode == "separate" then
		met = chronos >= (settings.chronos_kills_needed or 7)
			and typhon >= (settings.typhon_kills_needed or 5)
	else
		met = (chronos + typhon) >= (settings.boss_defeats_needed or 5)
	end

	if met then
		state.victory = true
		print("[HadesII_AP] BossDefeats goal met — victory!")
		H2AP_SaveState()
		H2AP_FlushOutbox()
	end
end

-- Room-based counting trigger; hooked to DoUnlockRoomExits so non-combat rooms still count their depth.
function H2AP_OnRoomExitsUnlocked(currentRoom)
	if not currentRoom then return end
	local system = H2AP_LocationSystem()
	if system ~= "room" and system ~= "room_weapon" then return end

	local biome = currentRoom.Name and currentRoom.Name:sub(1, 1) or ""
	local route = ROUTE_FOR_BIOME[biome] or "underworld"
	local depth = (CurrentRun and CurrentRun.RunDepthCache) or 0
	H2AP_FireRoomCheck(route, depth, system)

	-- Log observed max depth per route and each biome's start depth to confirm the apworld bounds.
	local state = H2AP_LoadState()
	state.room_depth_max = state.room_depth_max or {}
	state.biome_min_depth = state.biome_min_depth or {}
	local dirty = false
	if depth > (state.room_depth_max[route] or 0) then
		state.room_depth_max[route] = depth
		print("[HadesII_AP] new max " .. route .. " run depth: " .. depth)
		dirty = true
	end
	if biome ~= "" and depth >= 1 and depth < (state.biome_min_depth[biome] or 1e9) then
		state.biome_min_depth[biome] = depth
		print("[HadesII_AP] biome " .. biome .. " starts at run depth " .. depth)
		dirty = true
	end
	if dirty then H2AP_SaveState() end
end

-- Credit room-clear score for one cleared room; shared by regular rooms and the final-boss branch.
local function credit_room_score(currentRoom, currentEncounter)
	local biome  = currentRoom.Name and currentRoom.Name:sub(1, 1) or ""
	local route  = ROUTE_FOR_BIOME[biome] or "underworld"
	local system = H2AP_LocationSystem()

	-- Room-based systems count depths on DoUnlockRoomExits, not here.
	if system ~= "score" then return end

	-- Skip encounters that shouldn't award score.
	if not encounter_awards_score(currentEncounter) then
		return
	end

	-- score_based: accumulate score → trigger score checks.
	local state    = H2AP_LoadState()
	local settings = H2AP_LoadSettings()

	local points   = BIOME_POINTS[biome] or config.points_per_room or 1
	local max_checks = settings.score_rewards_amount or 150
	local separate = H2AP_ScoreSeparate(settings)

	-- Credit the score to this room's route.
	local route_field = "score_" .. route
	state[route_field] = (state[route_field] or 0) + points
	state.score = (state.score_underworld or 0) + (state.score_surface or 0)
	-- Toast the route score (separate) or the running total (combined), with points to next check.
	if separate then
		local underworld_budget, surface_budget = H2AP_ScoreBudgets(settings, max_checks)
		local route_budget = (route == "surface") and surface_budget or underworld_budget
		local to_next = H2AP_PointsToNextScoreCheck(state[route_field], route_budget)
		H2AP_NotifyScore(points, state[route_field], ROUTE_LABEL[route], to_next)
	else
		local to_next = H2AP_PointsToNextScoreCheck(state.score, max_checks)
		H2AP_NotifyScore(points, state.score, nil, to_next)
	end

	local prev_under   = state.checks_sent_underworld or 0
	local prev_surface = state.checks_sent_surface or 0
	local under_checks, surface_checks = H2AP_ScoreChecksSent(state, settings, max_checks)
	state.checks_sent_underworld = under_checks
	state.checks_sent_surface    = surface_checks

	-- Separate mode: only the cleared room's route can have gained a check.
	if separate then
		local underworld_budget, surface_budget = H2AP_ScoreBudgets(settings, max_checks)
		if route == "underworld" and under_checks > prev_under then
			H2AP_NotifyMilestone(under_checks, underworld_budget, ROUTE_LABEL.underworld)
		elseif route == "surface" and surface_checks > prev_surface then
			H2AP_NotifyMilestone(surface_checks, surface_budget, ROUTE_LABEL.surface)
		end
	end

	local new_checks = math.min(under_checks + surface_checks, max_checks)
	if new_checks > state.checks_sent then
		state.checks_sent = new_checks
		print("[HadesII_AP] Score checks unlocked: " .. state.checks_sent)
		if not separate then
			H2AP_NotifyMilestone(new_checks, max_checks, nil)
		end
	end

	print("[HadesII_AP] +" .. points .. " pts (" .. biome .. "/" .. route .. ") → "
		.. state.score .. " total (U:" .. (state.score_underworld or 0)
		.. " S:" .. (state.score_surface or 0) .. ")")
	H2AP_SaveState()
	H2AP_FlushOutbox()
end

function H2AP_OnRoomCleared(currentRoom, currentEncounter)
	if not currentRoom then return end

	-- Boss rooms: bump the kill counter; the AP check fires from the pickup's OnUsed handler.
	local boss_key = H2AP_BossForRoom(currentRoom)
	if boss_key then
		local state = H2AP_LoadState()
		local field = boss_key .. "_kills"
		state[field] = (state[field] or 0) + 1

		-- Record an un-fakeable "Typhon beaten with Storm Stop" flag; vanilla's TyphonDefeatedWithStormStop can't be trusted since the Entropy grant fakes it.
		if boss_key == "typhon"
				and GameState and GameState.WorldUpgradesAdded
				and GameState.WorldUpgradesAdded.WorldUpgradeStormStop then
			GameState.AP_TyphonKilledWithStormStop = true
		end

		-- Record a distinct weapon clear and fire its "<Weapon> Clear" check under weaponsanity.
		if type(GetEquippedWeapon) == "function" then
			local weapon = GetEquippedWeapon()
			if weapon and not state.weapon_clears[weapon] then
				state.weapon_clears[weapon] = true
				local settings = H2AP_LoadSettings() or {}
				local loc = WEAPON_CLEAR_LOCATIONS[weapon]
				if loc and (settings.weaponsanity == true or settings.weaponsanity == 1) then
					H2AP_CheckLocation(loc)
				end
			end
		end

		H2AP_SaveState()

		-- BossDefeats goal check (no-op under True Ending).
		H2AP_CheckBossDefeatsVictory()

		-- Tartarus depth is variable, so auto-grant the deep underworld room checks on the Chronos kill.
		if boss_key == "chronos" then
			local system = H2AP_LocationSystem()
			if system == "room" or system == "room_weapon" then
				for depth = UNDERWORLD_AUTOGRANT_FROM, ROOM_DEPTH_MAX.underworld do
					H2AP_FireRoomCheck("underworld", depth, system)
				end
				print("[HadesII_AP] Chronos cleared — auto-granted underworld room tail "
					.. UNDERWORLD_AUTOGRANT_FROM .. ".." .. ROOM_DEPTH_MAX.underworld)
			end
		end

		local settings = H2AP_LoadSettings() or {}
		-- Redirect the exit to EndEarlyAccessPresentation, except on a True Ending run with both goal incantations (the credits must play).
		local is_te_run = settings.true_ending
			and GameState and GameState.WorldUpgrades
			and GameState.WorldUpgrades.WorldUpgradeTimeStop
			and GameState.WorldUpgrades.WorldUpgradeStormStop
		if settings.score_rewards_amount ~= nil
				and not (CurrentRun and CurrentRun.IsDreamRun)
				and not (GameState and GameState.ReachedTrueEnding)
				and not is_te_run then
			CurrentRun.CurrentRoom.ExitFunctionName = "EndEarlyAccessPresentation"
			CurrentRun.CurrentRoom.SkipLoadNextMap  = true
			print("[HadesII_AP] Boss cleared — exit redirected to EndEarlyAccessPresentation")
		end

		-- Final-boss rooms award room-clear score like any other room.
		credit_room_score(currentRoom, currentEncounter)
		return
	end

	-- Regular rooms: credit room-clear score.
	credit_room_score(currentRoom, currentEncounter)
end
