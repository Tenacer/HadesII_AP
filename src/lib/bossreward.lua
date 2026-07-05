---@meta _
---@diagnostic disable: lowercase-global

-- ── AP reward visuals ─────────────────────────────────────────────────────────

-- Carrier obstacle for the "AP icon" case; visual overridden after spawn, AddResources nilled.
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

-- Maps a local AP item name to the ConsumableData drop with the matching visual; unmapped items use the AP icon obstacle.
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

-- How many AP-check rewards this boss gives before fallback drops take over.
function H2AP_BossKillsNeeded(boss_key)
	local settings = H2AP_LoadSettings() or {}
	local opt_key = boss_key .. "_kills_needed"
	local v = settings[opt_key]
	if type(v) == "number" then return v end
	return BOSS_DEFAULT_KILLS_NEEDED[boss_key] or 1
end

-- Total kills observed for this boss so far.
function H2AP_BossKillCount(boss_key)
	local state = H2AP_LoadState()
	return state[boss_key .. "_kills"] or 0
end

-- Returns "ap_check" / "fallback" / "vanilla" / nil for this room's boss reward; must run after H2AP_OnRoomCleared incremented the kill counter.
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

-- The AP location name for the just-finished kill.
function H2AP_BossCurrentLocationName(boss_key)
	if not boss_key then return nil end
	local count = H2AP_BossKillCount(boss_key)
	if count <= 0 then return nil end
	return BOSS_LOCATION_BASE_NAME[boss_key] .. " " .. tostring(count)
end

-- ── Reward spawning ───────────────────────────────────────────────────────────

-- Spawn a ConsumableData drop as a real interactable pickup near the hero, mirroring vanilla SpawnRoomReward.
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

-- OnUsed handler for AP-boss-reward obstacles: send the attached location check, then let vanilla handle the consume bookkeeping.
function H2AP_OnBossDropUsed(usee, args, user)
	if usee and usee.APLocation then
		print("[HadesII_AP] Boss reward picked up — sending " .. usee.APLocation)
		H2AP_CheckLocation(usee.APLocation)
		H2AP_ShowBossRewardBanner()
	end
	if UseConsumableItem then
		UseConsumableItem(usee, args, user)
	end
end

-- OnUsedFunctionName resolves via the game's _G, so publish the handler there.
game.H2AP_OnBossDropUsed = H2AP_OnBossDropUsed

-- Spawn the boss reward obstacle for an AP-check kill, picking the visual from the scouted item.
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

	-- Suppress the resource grant — the obstacle is purely a visual + AP-check trigger.
	reward.AddResources         = nil
	reward.OnUsedFunctionName   = "H2AP_OnBossDropUsed"
	reward.APLocation           = ap_location

	-- AP-icon case: override the animation so the player sees the AP logo.
	if not resource_obstacle then
		local ok = pcall(SetAnimation, { Name = AP_REWARD_ANIM, DestinationId = reward.ObjectId })
		if not ok then
			print("[HadesII_AP] SetAnimation failed for " .. AP_REWARD_ANIM)
		end
	end
	return reward
end
