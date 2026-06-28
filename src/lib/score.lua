---@meta _
---@diagnostic disable: lowercase-global

-- ── Score / boss tracking ─────────────────────────────────────────────────────

-- Maps boss room name → boss identifier (for the per-kill reward indexing).
local BOSS_ROOM_TO_BOSS = {
	I_Boss01 = "chronos",
	Q_Boss01 = "typhon",
	Q_Boss02 = "typhon",
}

local BOSS_DEFAULT_KILLS_NEEDED = {
	chronos = 7,
	typhon  = 5,
}

-- Per-biome score weight (room-name prefix → points awarded per regular room).
-- Linear by depth, per route: each route ramps independently from 1 → 4.
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

-- Route a room belongs to, keyed by room-name prefix. The underworld/Chronos
-- path (F/G/H/I) and the surface/Typhon path (N/O/P/Q) accumulate score
-- independently, each capped at its own share of the total check budget
-- (see H2AP_ScoreChecksSent). This is purely a Lua-side budgeting concern —
-- score checks are interchangeable filler, so the Python client doesn't care
-- which physical location lights up, only the total count.
local ROUTE_FOR_BIOME = {
	F = "underworld", G = "underworld", H = "underworld", I = "underworld",
	N = "surface",    O = "surface",    P = "surface",    Q = "surface",
}

-- Encounter types that do NOT award room-clear score. Two groups:
--   • Non-combat utility rooms — shops, fountains, story beats, openings, empties
--     (all inherit EncounterData "NonCombat").
--   • Optional challenge side-rooms triggered by a challenge switch: PerfectClear
--     (take no damage), TimeChallenge (beat the clock) and EliteChallenge (forced
--     elite wave). They're off the main path and shouldn't pad the score.
-- Everything else counts: normal combat (Default / Miniboss / ArachneCombat), all
-- boss rooms (Boss — the mid-run six plus the final Chronos/Typhon rooms, which
-- now credit score from the boss branch), and the god-choice Devotion rooms.
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
-- Per-route max run depth. MUST match the apworld's UNDERWORLD_ROOM_MAX /
-- SURFACE_ROOM_MAX (Locations.py, derived from the *_BIOME_BOUNDS). Underworld is
-- variable (Tartarus has optional rooms) so its tail is auto-granted on the
-- Chronos kill; surface is fixed. The apworld places each depth's check in its
-- biome region (boss-victory gated) — the mod only fires checks by name, so it
-- doesn't need the per-biome boundaries, only the per-route maxima here.
-- TODO(confirm): estimates — H2AP_OnRoomCleared logs the observed max run depth
-- per route AND each biome's start depth ("[HadesII_AP] biome <X> starts at run
-- depth N"); update both sides (incl. the apworld bounds) after a full run.
local ROOM_DEPTH_MAX = { underworld = 40, surface = 36 }
-- Run depth where Tartarus begins; the Chronos-kill auto-grant covers
-- [UNDERWORLD_AUTOGRANT_FROM .. ROOM_DEPTH_MAX.underworld].
local UNDERWORLD_AUTOGRANT_FROM = 26
local ROUTE_LABEL = { underworld = "Underworld", surface = "Surface" }

-- Resolves the active location system from slot data. Slot-data values may be the
-- raw int (AP as_dict) or the option string, so accept both (mirrors the
-- score_split_mode handling below).
function H2AP_LocationSystem()
	local s = H2AP_LoadSettings() or {}
	local v = s.location_system
	if v == 1 or v == "room_based" then return "room" end
	if v == 2 or v == "room_weapon_based" then return "room_weapon" end
	return "score"
end

-- Two-digit zero-padded depth, matching the apworld's room_location_name (%02d).
local function pad_depth(n) return string.format("%02d", n) end

-- Fire the room check for a single (route, depth[, weapon]) under the active room
-- system. Out-of-range depths are clamped (logged once) rather than crashing, so
-- an under-sized ROOM_DEPTH_MAX never breaks a run.
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

-- Cumulative score → number of score checks unlocked.
-- The per-check gap (points needed over the previous check) follows a
-- slow-rise → mid-plateau → rise-again shape, expressed as a double smoothstep
-- over the check's fractional position t = (n-1)/(N-1), so the plateau lands in
-- the middle and the final ramp lands at the end regardless of the route's
-- budget N. Gaps are rounded to whole points (clearer to players); thresholds
-- are their running sum and so are integers too. Tunables below; raise
-- SCORE_G1 to lift the whole curve, raise SCORE_G2 for a steeper finale.
local SCORE_P1, SCORE_P2 = 0.25, 0.70      -- end of first rise / start of finale (fractions)
local SCORE_G0, SCORE_G1, SCORE_G2 = 2, 11, 18  -- start / plateau / end gap (points)

local function smoothstep(x)
	if x < 0 then x = 0 elseif x > 1 then x = 1 end
	return x * x * (3 - 2 * x)
end

-- Integer cumulative-score thresholds for a route whose total budget is N
-- checks: threshold[n] = score at which check n unlocks. Cached per N (budgets
-- are stable within a run, so each table builds once).
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

-- Cumulative score → number of score checks unlocked, for a route budgeted at
-- N checks. Thresholds are monotone increasing; a linear scan is plenty here.
local function checks_for_score(s, N)
	if s < 1 or N < 1 then return 0 end
	local t = score_thresholds(N)
	local count = 0
	for n = 1, N do
		if s >= t[n] then count = n else break end
	end
	return count
end

-- Points remaining until the next score check unlocks, for a route at score `s`
-- with budget `N`. Returns nil once every check in the budget is unlocked (so
-- callers can omit the "to next check" hint at the cap).
function H2AP_PointsToNextScoreCheck(s, N)
	if N < 1 then return nil end
	local t = score_thresholds(N)
	local unlocked = checks_for_score(s, N)
	if unlocked >= N then return nil end
	return t[unlocked + 1] - s
end

-- Score checks earned from the room-clear score, returned as (under, surface).
-- The caller sums them for the total; the per-route split also feeds the IPC
-- outbox so the client can map each route's checks to the correct location-id
-- range (underworld → low/Erebus ids, surface → high/Ephyra ids).
--   Combined mode (score_split_mode 0): one pool — the summed score feeds the
--     full budget, so any route can earn every check. Returned as (total, 0);
--     the client lights consecutive ids from the combined `checks_sent`.
--   Separate mode (score_split_mode 1, default): each route accumulates score
--     independently and is capped at its own share of the budget.
--     `surface_score_ratio` (0-100, default 40) is the surface route's
--     percentage of `max_checks`; the underworld route gets the rest. An
--     all-underworld player therefore tops out at the underworld share and must
--     play surface for the remaining checks (and vice versa). The budget split
--     here MUST match Locations.score_check_split on the apworld side.
-- True when the score-check budget is split per route (separate mode).
local function H2AP_ScoreSeparate(settings)
	local mode = settings.score_split_mode
	return mode == 1 or mode == "separate"
end

-- Per-route check budgets, returned as (underworld_budget, surface_budget).
-- Combined mode puts the whole budget on the sole pool → (max_checks, 0).
-- MUST match Locations.score_check_split on the apworld side.
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

local BOSS_LOCATION_BASE_NAME = {
	chronos = "Chronos Kill Reward",
	typhon  = "Typhon Kill Reward",
}

-- Maps an AP item name (as written in items.csv) to the ConsumableData entry
-- whose obstacle visual matches that resource. Used when the AP item placed at
-- a boss reward location is for OUR slot AND is a Hades II resource — we spawn
-- the matching drop visually but suppress its AddResources (AP delivers the
-- item via the normal inbox cycle, so the obstacle only sends the location
-- check on pickup). Items not in this table fall back to the AP icon obstacle.
RESOURCE_OBSTACLE_FOR_ITEM = {
	["Zodiac Sand"] = "MixerIBossDrop",
	["Void Lens"]   = "MixerQBossDrop",
	["Bones"]       = "MetaCurrencyBigDrop",
	["Ash"]         = "MetaCardPointsCommonBigDrop",
	["Psyche"]      = "MemPointsCommonBigDrop",
	["Nectar"]      = "GiftDrop",
	["Nightmare"]   = "WeaponPointsRareDrop",
	["Moon Dust"]   = "CardUpgradePointsDrop",
	["Fate Fabric"] = "MetaFabricDrop",
	["Gemstones"]   = "GemPointsBigDrop",
}

-- The carrier obstacle we spawn for the "AP icon" case. The visual is
-- overridden via SetAnimation to AP_ICON_ANIM after spawn — the actual
-- ConsumableData entry doesn't matter as long as it can be physically
-- spawned, picked up, and we nil out its AddResources.
AP_ICON_CARRIER_OBSTACLE = "WeaponPointsRareDrop"

-- Returns the boss key ("chronos"/"typhon") if this room is a final boss room.
function H2AP_BossForRoom(currentRoom)
	if not currentRoom then return nil end
	return BOSS_ROOM_TO_BOSS[currentRoom.Name]
end

-- Returns how many AP-check rewards the player should get for this boss before
-- vanilla fallback drops (Nightmare + Gemstones) take over.
function H2AP_BossKillsNeeded(boss_key)
	local settings = H2AP_LoadSettings() or {}
	local opt_key = boss_key .. "_kills_needed"
	local v = settings[opt_key]
	if type(v) == "number" then return v end
	return BOSS_DEFAULT_KILLS_NEEDED[boss_key] or 1
end

-- Total kills observed for this boss so far (after H2AP_OnRoomCleared has fired
-- for the current kill, this is THIS kill's 1-indexed count).
function H2AP_BossKillCount(boss_key)
	local state = H2AP_LoadState()
	return state[boss_key .. "_kills"] or 0
end

-- Decides what the boss reward should do this room. Returns one of:
--   "ap_check"  → H2AP_OnRoomCleared already sent the AP check, suppress vanilla
--   "fallback"  → past the configured kill count, drop Nightmare + Gemstones
--   "vanilla"   → not a TrueEnding boss kill, leave the reward untouched
--   nil         → not a boss room
-- Must be called AFTER H2AP_OnRoomCleared has incremented the kill counter.
function H2AP_BossRewardAction(currentRoom)
	local boss_key = H2AP_BossForRoom(currentRoom)
	if not boss_key then return nil end
	local settings = H2AP_LoadSettings() or {}
	if not (settings.true_ending == true or settings.true_ending == 1) then
		return "vanilla"
	end
	local count = H2AP_BossKillCount(boss_key)
	if count <= H2AP_BossKillsNeeded(boss_key) then
		return "ap_check"
	end
	return "fallback"
end

-- Kept for compatibility — true if SpawnRoomReward should NOT call base().
function H2AP_ShouldReplaceReward(currentRoom)
	local action = H2AP_BossRewardAction(currentRoom)
	return action == "ap_check" or action == "fallback"
end

-- Spawn a single ConsumableData drop as a real interactable pickup near the
-- hero. Mirrors the else-branch of RewardLogic.lua's SpawnRoomReward so the
-- result behaves like a normal boss-room drop (player walks up, presses use,
-- drop is consumed and the resource is granted).
--
--   name        — ConsumableData entry (e.g. "WeaponPointsRareDrop", "GemPointsBigDrop")
--   angle_deg   — angle from the hero to spawn at (degrees, 0 = right)
--   distance    — pixels from the hero
function H2AP_SpawnConsumableDrop(name, angle_deg, distance)
	if not (CurrentRun and CurrentRun.Hero) then return nil end
	distance = distance or 110
	local rad = math.rad(angle_deg or 0)
	local offset = { X = math.cos(rad) * distance, Y = math.sin(rad) * distance }

	local consumableId = SpawnObstacle({
		Name          = name,
		DestinationId = CurrentRun.Hero.ObjectId,
		Group         = "Standing",
		OffsetX       = offset.X,
		OffsetY       = offset.Y,
	})
	local reward = CreateConsumableItem(consumableId, name, 0, {
		RunProgressUpgradeEligible = true,
		AutoLoadPackages           = true,
	})
	if reward then
		reward.IgnorePurchase       = true
		reward.PurchaseRequirements = nil
		if reward.ExtractValues ~= nil then
			ExtractValues(CurrentRun.Hero, reward, reward)
		end
		-- Mark as required so the room can't be exited until picked up.
		MapState.RoomRequiredObjects[consumableId] = reward
	end
	return reward
end

-- The AP location name for the CURRENT (just-finished) kill — derived from
-- the per-boss kill counter that H2AP_OnRoomCleared just incremented.
function H2AP_BossCurrentLocationName(boss_key)
	if not boss_key then return nil end
	local count = H2AP_BossKillCount(boss_key)
	if count <= 0 then return nil end
	return BOSS_LOCATION_BASE_NAME[boss_key] .. " " .. tostring(count)
end

-- OnUsed handler for the AP-boss-reward obstacles. Reads the AP location name
-- attached to the obstacle (set in H2AP_SpawnApBossReward) and sends the
-- check. Idempotent — H2AP_CheckLocation dedupes against state.checked_locations.
function H2AP_OnBossDropUsed(usee, args)
	if usee and usee.APLocation then
		print("[HadesII_AP] Boss reward picked up — sending " .. usee.APLocation)
		H2AP_CheckLocation(usee.APLocation)
		H2AP_ShowBossRewardBanner()
	end
	-- The vanilla UseConsumableItem clears AddResources/Cost handling. We've
	-- nilled AddResources, so calling it here is a clean no-op apart from the
	-- standard consume bookkeeping (Destroy, ConsumeSound, etc).
	if UseConsumableItem then
		UseConsumableItem(usee, args)
	end
end

-- Spawn the boss reward obstacle for an AP-check kill. Decides the visual
-- (matching resource drop, or AP-icon-overridden carrier) based on the
-- scouted item placed at this AP location.
--   ap_location  — AP location name (e.g. "Chronos Kill Reward 3")
function H2AP_SpawnApBossReward(ap_location)
	if not (CurrentRun and CurrentRun.Hero) then return nil end
	local entry = H2AP_GetLocationItem(ap_location)
	local resource_obstacle = nil
	if entry and entry.is_local and entry.item_name then
		resource_obstacle = RESOURCE_OBSTACLE_FOR_ITEM[entry.item_name]
	end

	local obstacle_name = resource_obstacle or AP_ICON_CARRIER_OBSTACLE
	local reward = H2AP_SpawnConsumableDrop(obstacle_name, 0, 110)
	if not reward then return nil end

	-- Suppress the underlying resource grant — AP delivers the actual item via
	-- the inbox cycle. The obstacle is purely a visual + AP-check trigger.
	reward.AddResources         = nil
	reward.OnUsedFunctionName   = "H2AP_OnBossDropUsed"
	reward.APLocation           = ap_location

	-- For the AP-icon case (carrier obstacle, no scouted resource match),
	-- override the animation so the player sees the AP logo.
	if not resource_obstacle then
		pcall(SetAnimation, { Name = AP_ICON_ANIM, DestinationId = reward.ObjectId })
	end
	return reward
end

-- Evaluate the BossDefeats goal after a boss kill and flag victory if met.
-- True Ending mode is skipped — its victory fires in death.lua on the natural
-- credits sequence. The Python client relays state.victory as CLIENT_GOAL
-- (gated additionally on weapon clears when weaponsanity is on).
--   combined (boss_defeats_mode 0): chronos + typhon kills >= boss_defeats_needed
--   separate (boss_defeats_mode 1): chronos >= chronos_kills_needed AND
--                                    typhon  >= typhon_kills_needed
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

-- Room-based counting trigger. Hooked to DoUnlockRoomExits, which fires once per
-- room regardless of combat (unlike OnAllEnemiesDead) — matching Polycosmos'
-- room hook — so depths at non-combat rooms (shops, story, forced-shop PreBoss)
-- still get their check. No-op outside the room/room_weapon systems. Dedup is by
-- H2AP_CheckLocation, so save/load re-fires and revisited depths are harmless.
function H2AP_OnRoomExitsUnlocked(currentRoom)
	if not currentRoom then return end
	local system = H2AP_LocationSystem()
	if system ~= "room" and system ~= "room_weapon" then return end

	local biome = currentRoom.Name and currentRoom.Name:sub(1, 1) or ""
	local route = ROUTE_FOR_BIOME[biome] or "underworld"
	local depth = (CurrentRun and CurrentRun.RunDepthCache) or 0
	H2AP_FireRoomCheck(route, depth, system)

	-- Track + log the observed max depth per route AND the shallowest run depth
	-- each biome is entered at, so the apworld's per-route maxima and
	-- {UNDERWORLD,SURFACE}_BIOME_BOUNDS can be confirmed from a real run.
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

-- Credit room-clear score for one cleared room under the score_based system.
-- Factored out so regular rooms AND the final-boss rooms (Chronos/Typhon, which
-- take the boss branch in H2AP_OnRoomCleared) award score identically. No-op
-- outside the score system or for non-scoring encounters (see
-- encounter_awards_score) — so it's safe to call unconditionally on a cleared room.
local function credit_room_score(currentRoom, currentEncounter)
	local biome  = currentRoom.Name and currentRoom.Name:sub(1, 1) or ""
	local route  = ROUTE_FOR_BIOME[biome] or "underworld"
	local system = H2AP_LocationSystem()

	-- Room-based systems count depths on DoUnlockRoomExits (fires for ALL rooms,
	-- combat or not — see H2AP_OnRoomExitsUnlocked), NOT here: OnAllEnemiesDead
	-- skips non-combat rooms (shops/story/forced-shop PreBoss), which would leave
	-- those depths' checks permanently unobtainable.
	if system ~= "score" then return end

	-- Skip rooms that shouldn't award score — non-combat utility chambers (shops,
	-- story, fountains, empties) and optional challenge side-rooms — which still
	-- reach OnAllEnemiesDead and would otherwise tick the score up.
	if not encounter_awards_score(currentEncounter) then
		return
	end

	-- score_based: accumulate score → trigger score checks.
	local state    = H2AP_LoadState()
	local settings = H2AP_LoadSettings()

	local points   = BIOME_POINTS[biome] or config.points_per_room or 1
	local max_checks = settings.score_rewards_amount or 150
	local separate = H2AP_ScoreSeparate(settings)

	-- Credit the score to the route this room belongs to (default underworld for
	-- any unrecognized prefix). Each route is budgeted independently.
	local route_field = "score_" .. route
	state[route_field] = (state[route_field] or 0) + points
	state.score = (state.score_underworld or 0) + (state.score_surface or 0)
	-- Separate mode: name the route in the toast so the player sees which score
	-- they're building. Combined mode shows the running total. Either way include
	-- the points remaining until the next check unlocks (nil once capped).
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

	-- Separate mode: only the cleared room's route can have gained a check, so
	-- fire that route's milestone against its own budget.
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

	-- Boss rooms: increment the per-boss kill counter; the AP location check
	-- is deferred to the obstacle's OnUsed handler (H2AP_OnBossDropUsed)
	-- so the player has to pick the reward up. Always handle the exit redirect.
	local boss_key = H2AP_BossForRoom(currentRoom)
	if boss_key then
		local state = H2AP_LoadState()
		local field = boss_key .. "_kills"
		state[field] = (state[field] or 0) + 1

		-- True Ending ordering gate: record an un-fakeable "Typhon beaten with
		-- Storm Stop" flag the moment it genuinely happens in-game. Mirrors the
		-- vanilla CheckTyphonReward condition (PresentationBiomeQ.lua). We can't
		-- reuse GameState.TyphonDefeatedWithStormStop here because the Entropy AP
		-- grant fakes it (story.lua) — this separate flag is what gates Dissolution
		-- of Time brewing (see H2AP_PatchGoalIncantationGate), so the player can't
		-- cast it before brewing Disintegration AND actually defeating Typhon.
		if boss_key == "typhon"
				and GameState and GameState.WorldUpgradesAdded
				and GameState.WorldUpgradesAdded.WorldUpgradeStormStop then
			GameState.AP_TyphonKilledWithStormStop = true
		end

		-- Record a distinct weapon clear for the weapons goal. The first time a
		-- given weapon clears a final boss, fire its trackable "<Weapon> Clear"
		-- AP check (only meaningful — and only a valid location — under weaponsanity).
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

		-- BossDefeats goal: flag victory once the configured kill threshold is
		-- met (no-op under True Ending, which ends via death.lua on the credits).
		H2AP_CheckBossDefeatsVictory()

		-- Room-based systems: Tartarus has optional rooms (variable depth), so a
		-- short path to Chronos can skip deep underworld room checks. Auto-grant
		-- the Tartarus-range underworld rooms on the Chronos kill so they stay
		-- completable (mirrors Polycosmos' ProcessAutomaticRooms; underworld-only —
		-- the surface route's boss depths are fixed). For room_weapon this grants
		-- the equipped weapon's tail (H2AP_FireRoomCheck reads GetEquippedWeapon).
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
		-- In AP mode, redirect the exit to EndEarlyAccessPresentation (the proper
		-- run-completion sequence) instead of loading the post-boss story room.
		-- Exception: True Ending mode with both goal incantations unlocked — the
		-- game needs to play through I_PostBoss01 → I_ChronosFlashback01 → credits.
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

		-- Final-boss rooms are full combat Encounters, so they award room-clear
		-- score like any other room — in both goal modes. (No-op outside the score
		-- system.) Done here because the boss branch returns before the regular path.
		credit_room_score(currentRoom, currentEncounter)
		return
	end

	-- Regular rooms: credit room-clear score (no-op outside the score system or for
	-- non-scoring encounters).
	credit_room_score(currentRoom, currentEncounter)
end
