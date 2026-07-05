---@meta _
---@diagnostic disable: lowercase-global

-- ── AP reward visuals ─────────────────────────────────────────────────────────

-- The carrier obstacle we spawn for the "AP icon" case, its visual overridden via
-- SetAnimation after spawn and its AddResources nilled so it only triggers a check.
AP_ICON_CARRIER_OBSTACLE = "WeaponPointsRareDrop"

-- World-obstacle animation for the AP logo, registered into Items_General_VFX.
AP_REWARD_ANIM = "APRewardIcon"

-- Registers an Animation for our AP logo so it can be a world obstacle's graphic.
function sjson_ItemAnimations(data)
	if data == nil or data.Animations == nil then return end
	table.insert(data.Animations, {
		Name        = AP_REWARD_ANIM,
		InheritFrom = "BaseMetaRewardAnimatedDrop",
		FilePath    = AP_ICON_ANIM,
	})
end

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

-- ── Boss identification & kill counting ───────────────────────────────────────

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

-- The AP location name for the CURRENT (just-finished) kill — derived from
-- the per-boss kill counter that H2AP_OnRoomCleared just incremented.
function H2AP_BossCurrentLocationName(boss_key)
	if not boss_key then return nil end
	local count = H2AP_BossKillCount(boss_key)
	if count <= 0 then return nil end
	return BOSS_LOCATION_BASE_NAME[boss_key] .. " " .. tostring(count)
end

-- ── Reward spawning ───────────────────────────────────────────────────────────

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

-- OnUsed handler for the AP-boss-reward obstacles. Reads the AP location name
-- attached to the obstacle (set in H2AP_SpawnApBossReward) and sends the
-- check. Idempotent — H2AP_CheckLocation dedupes against state.checked_locations.
function H2AP_OnBossDropUsed(usee, args, user)
	if usee and usee.APLocation then
		print("[HadesII_AP] Boss reward picked up — sending " .. usee.APLocation)
		H2AP_CheckLocation(usee.APLocation)
		H2AP_ShowBossRewardBanner()
	end
	-- The vanilla UseConsumableItem clears AddResources/Cost handling. We've
	-- nilled AddResources, so calling it here is a clean no-op apart from the
	-- standard consume bookkeeping (Destroy, ConsumeSound, etc).
	if UseConsumableItem then
		UseConsumableItem(usee, args, user)
	end
end

-- OnUsedFunctionName resolves via the game's _G, so publish the handler there.
game.H2AP_OnBossDropUsed = H2AP_OnBossDropUsed

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
		local ok = pcall(SetAnimation, { Name = AP_REWARD_ANIM, DestinationId = reward.ObjectId })
		if not ok then
			print("[HadesII_AP] SetAnimation failed for " .. AP_REWARD_ANIM)
		end
	end
	return reward
end
