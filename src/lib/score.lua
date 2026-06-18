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

-- Cumulative score → number of score checks unlocked.
-- Checks 1-10 use triangular thresholds: check n unlocks at score n*(n+1)/2
-- (check 1=1, 2=3, 3=6, …, 10=55). Checks 11+ cost 10 points each beyond score 55.
local TRIANGLE_MAX_SCORE = 55  -- 10*11/2
local function checks_for_score(s)
	if s < 1 then return 0 end
	if s <= TRIANGLE_MAX_SCORE then
		return math.floor((-1 + math.sqrt(1 + 8 * s)) / 2)
	end
	return 10 + math.floor((s - TRIANGLE_MAX_SCORE) / 10)
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
		return
	end

	-- Regular rooms: accumulate score → trigger score checks.
	local state    = H2AP_LoadState()
	local settings = H2AP_LoadSettings()

	local biome    = currentRoom.Name and currentRoom.Name:sub(1, 1) or ""
	local points   = BIOME_POINTS[biome] or config.points_per_room or 1
	local max_checks = settings.score_rewards_amount or 150

	state.score = state.score + points
	H2AP_NotifyScore(state.score, points)
	local new_checks = math.min(checks_for_score(state.score), max_checks)
	if new_checks > state.checks_sent then
		state.checks_sent = new_checks
		print("[HadesII_AP] Score checks unlocked: " .. state.checks_sent)
		H2AP_NotifyMilestone(state.checks_sent, max_checks)
	end

	print("[HadesII_AP] +" .. points .. " pts (" .. biome .. ") → " .. state.score .. " total")
	H2AP_SaveState()
	H2AP_FlushOutbox()
end
