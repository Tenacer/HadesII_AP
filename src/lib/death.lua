---@meta _
---@diagnostic disable: lowercase-global

-- ── Death tracking ────────────────────────────────────────────────────────────

function on_melinoe_died()
	-- EndCreditsExitTimer sets CurrentRun.PlayedTrueEnding = true immediately
	-- before calling Kill(Hero), so we can detect True Ending victory here.
	if CurrentRun and CurrentRun.PlayedTrueEnding then
		local state = ap_load_state()
		if not state.victory then
			state.victory = true
			print("[HadesII_AP] True Ending victory!")
			ap_save_state()
			ap_flush_outbox()
		end
		return
	end
	local state = ap_load_state()
	state.deaths = (state.deaths or 0) + 1
	-- DeathLink amnesty (grouping N deaths before bouncing) is handled on the
	-- Python client side using the death_link_amnesty slot-data value.
	print("[HadesII_AP] Death recorded (" .. state.deaths .. " total)")
	ap_save_state()
	ap_flush_outbox()
end
