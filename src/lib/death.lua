---@meta _
---@diagnostic disable: lowercase-global

-- ── Death tracking ────────────────────────────────────────────────────────────

function H2AP_OnMelinoeDied()
	-- CurrentRun.PlayedTrueEnding is set just before the credits Kill(Hero), marking True Ending victory.
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
	-- DeathLink amnesty is handled on the Python client side.
	print("[HadesII_AP] Death recorded (" .. state.deaths .. " total)")
	H2AP_SaveState()
	H2AP_FlushOutbox()
end
