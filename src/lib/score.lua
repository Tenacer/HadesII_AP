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
function ap_boss_for_room(currentRoom)
	if not currentRoom then return nil end
	return BOSS_ROOM_TO_BOSS[currentRoom.Name]
end

-- Returns how many AP-check rewards the player should get for this boss before
-- vanilla fallback drops (Nightmare + Gemstones) take over.
function ap_boss_kills_needed(boss_key)
	local settings = ap_load_settings() or {}
	local opt_key = boss_key .. "_kills_needed"
	local v = settings[opt_key]
	if type(v) == "number" then return v end
	return BOSS_DEFAULT_KILLS_NEEDED[boss_key] or 1
end

-- Total kills observed for this boss so far (after on_room_cleared has fired
-- for the current kill, this is THIS kill's 1-indexed count).
function ap_boss_kill_count(boss_key)
	local state = ap_load_state()
	return state[boss_key .. "_kills"] or 0
end

-- Decides what the boss reward should do this room. Returns one of:
--   "ap_check"  → on_room_cleared already sent the AP check, suppress vanilla
--   "fallback"  → past the configured kill count, drop Nightmare + Gemstones
--   "vanilla"   → not a TrueEnding boss kill, leave the reward untouched
--   nil         → not a boss room
-- Must be called AFTER on_room_cleared has incremented the kill counter.
function ap_boss_reward_action(currentRoom)
	local boss_key = ap_boss_for_room(currentRoom)
	if not boss_key then return nil end
	local settings = ap_load_settings() or {}
	if not (settings.true_ending == true or settings.true_ending == 1) then
		return "vanilla"
	end
	local count = ap_boss_kill_count(boss_key)
	if count <= ap_boss_kills_needed(boss_key) then
		return "ap_check"
	end
	return "fallback"
end

-- Kept for compatibility — true if SpawnRoomReward should NOT call base().
function should_replace_reward(currentRoom)
	local action = ap_boss_reward_action(currentRoom)
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
function ap_spawn_consumable_drop(name, angle_deg, distance)
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
-- the per-boss kill counter that on_room_cleared just incremented.
function ap_boss_current_location_name(boss_key)
	if not boss_key then return nil end
	local count = ap_boss_kill_count(boss_key)
	if count <= 0 then return nil end
	return BOSS_LOCATION_BASE_NAME[boss_key] .. " " .. tostring(count)
end

-- OnUsed handler for the AP-boss-reward obstacles. Reads the AP location name
-- attached to the obstacle (set in ap_spawn_ap_boss_reward) and sends the
-- check. Idempotent — ap_check_location dedupes against state.checked_locations.
function ap_on_boss_drop_used(usee, args)
	if usee and usee.APLocation then
		print("[HadesII_AP] Boss reward picked up — sending " .. usee.APLocation)
		ap_check_location(usee.APLocation)
		ap_show_boss_reward_banner()
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
function ap_spawn_ap_boss_reward(ap_location)
	if not (CurrentRun and CurrentRun.Hero) then return nil end
	local entry = ap_get_location_item(ap_location)
	local resource_obstacle = nil
	if entry and entry.is_local and entry.item_name then
		resource_obstacle = RESOURCE_OBSTACLE_FOR_ITEM[entry.item_name]
	end

	local obstacle_name = resource_obstacle or AP_ICON_CARRIER_OBSTACLE
	local reward = ap_spawn_consumable_drop(obstacle_name, 0, 110)
	if not reward then return nil end

	-- Suppress the underlying resource grant — AP delivers the actual item via
	-- the inbox cycle. The obstacle is purely a visual + AP-check trigger.
	reward.AddResources         = nil
	reward.OnUsedFunctionName   = "ap_on_boss_drop_used"
	reward.APLocation           = ap_location

	-- For the AP-icon case (carrier obstacle, no scouted resource match),
	-- override the animation so the player sees the AP logo.
	if not resource_obstacle then
		pcall(SetAnimation, { Name = AP_ICON_ANIM, DestinationId = reward.ObjectId })
	end
	return reward
end

function on_room_cleared(currentRoom, currentEncounter)
	if not currentRoom then return end

	-- Boss rooms: increment the per-boss kill counter; the AP location check
	-- is deferred to the obstacle's OnUsed handler (ap_on_boss_drop_used)
	-- so the player has to pick the reward up. Always handle the exit redirect.
	local boss_key = ap_boss_for_room(currentRoom)
	if boss_key then
		local state = ap_load_state()
		local field = boss_key .. "_kills"
		state[field] = (state[field] or 0) + 1
		ap_save_state()

		local settings = ap_load_settings() or {}
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
	local state    = ap_load_state()
	local settings = ap_load_settings()

	local points    = config.points_per_room or 1
	local threshold = config.points_per_location or 10
	local max_checks = settings.score_rewards_amount or 150

	state.score = state.score + points
	local new_checks = math.min(math.floor(state.score / threshold), max_checks)
	if new_checks > state.checks_sent then
		state.checks_sent = new_checks
		print("[HadesII_AP] Score checks unlocked: " .. state.checks_sent)
	end

	print("[HadesII_AP] +" .. points .. " pts → " .. state.score .. " total")
	ap_save_state()
	ap_flush_outbox()
end
