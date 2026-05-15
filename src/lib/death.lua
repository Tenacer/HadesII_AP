---@meta _
---@diagnostic disable: lowercase-global

-- ── Death tracking ────────────────────────────────────────────────────────────

function H2AP_OnMelinoeDied()
	-- EndCreditsExitTimer sets CurrentRun.PlayedTrueEnding = true immediately
	-- before calling Kill(Hero), so we can detect True Ending victory here.
	if CurrentRun and CurrentRun.PlayedTrueEnding then
		local state = H2AP_LoadState()
		if not state.victory then
			state.victory = true
			print("[HadesII_AP] True Ending victory!")
			H2AP_SaveState()
			H2AP_FlushOutbox()
		end
		return
	end
	local state = H2AP_LoadState()
	state.deaths = (state.deaths or 0) + 1
	-- DeathLink amnesty (grouping N deaths before bouncing) is handled on the
	-- Python client side using the death_link_amnesty slot-data value.
	print("[HadesII_AP] Death recorded (" .. state.deaths .. " total)")
	H2AP_SaveState()
	H2AP_FlushOutbox()
end
