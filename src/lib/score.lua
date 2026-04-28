---@meta _
---@diagnostic disable: lowercase-global

-- ── Score / boss tracking ─────────────────────────────────────────────────────

-- Maps boss room name → AP location name for the kill-reward check.
local BOSS_ROOM_TO_LOCATION = {
	I_Boss01 = "Chronos Kill Reward",
	Q_Boss01 = "Typhon Kill Reward",
	Q_Boss02 = "Typhon Kill Reward",
}

function should_replace_reward(currentRoom)
	return currentRoom ~= nil and BOSS_ROOM_TO_LOCATION[currentRoom.Name] ~= nil
end

function on_room_cleared(currentRoom, currentEncounter)
	if not currentRoom then return end

	-- Boss rooms: report the kill-reward location check instead of scoring.
	local location = BOSS_ROOM_TO_LOCATION[currentRoom.Name]
	if location then
		ap_check_location(location)
		-- In AP mode, redirect the exit to EndEarlyAccessPresentation (the proper
		-- run-completion sequence) instead of loading the post-boss story room.
		-- Exception: True Ending mode with both goal incantations unlocked — the
		-- game needs to play through I_PostBoss01 → I_ChronosFlashback01 → credits.
		local settings = ap_load_settings()
		local is_te_run = settings and settings.true_ending
			and GameState and GameState.WorldUpgrades
			and GameState.WorldUpgrades.WorldUpgradeTimeStop
			and GameState.WorldUpgrades.WorldUpgradeStormStop
		if settings and settings.score_rewards_amount ~= nil
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
