---@meta _
---@diagnostic disable: lowercase-global

-- ── Inbox processing ──────────────────────────────────────────────────────────

function ap_process_inbox()
	local inbox = ap_read_inbox()
	if not inbox then return end

	-- DeathLink: Python client appends this when another player dies.
	-- deathlink_seq is an incrementing counter so each death only triggers once
	-- even if the flag stays in the inbox across multiple polls.
	if inbox.deathlink then
		local seq = inbox.deathlink_seq or 0
		local state = ap_load_state()
		if seq ~= (state.last_deathlink_seq or -1) then
			state.last_deathlink_seq = seq
			ap_save_state()
			if CurrentRun and CurrentRun.Hero and not CurrentRun.Hero.IsDead
					and CurrentRun.CurrentRoom and not SessionMapState.HandlingDeath then
				print("[HadesII_AP] DeathLink from: " .. tostring(inbox.deathlink_source or "unknown"))
				Kill(CurrentRun.Hero, { AttackerName = "DeathLink" })
			else
				print("[HadesII_AP] DeathLink received but not in active run — ignored")
			end
		end
	end

	-- Grant items in index order, skipping ones already processed.
	local state   = ap_load_state()
	local items   = inbox.items or {}
	local granted = 0

	for _, item in ipairs(items) do
		local idx = item.index
		if idx ~= nil and idx >= state.items_index then
			if give_item(item.item_name or "") then
				state.items_index = idx + 1
				granted = granted + 1
			end
		end
	end

	if granted > 0 then
		print("[HadesII_AP] Granted " .. granted .. " item(s) from AP")
		ap_save_state()
		ap_flush_outbox()
	end

	-- Sync story flags on every poll (idempotent). Also covers restarts where
	-- items_index is restored from state but GameState flags need re-applying.
	sync_story_flags(inbox)

	-- Re-apply shrine levels on every poll so they take effect as soon as
	-- ap_settings.json is written by the Python client, even mid-hub-session.
	ap_apply_shrine_levels()
end

-- ── Room hooks ────────────────────────────────────────────────────────────────

function prefix_SetupMap()
	local state = ap_load_state()
	print("[HadesII_AP] Map loaded — score: " .. state.score
		.. ", checks: " .. state.checks_sent
		.. ", items: "  .. state.items_index)
	ap_apply_shrine_levels()
	ap_init_weapon_state()
	ap_process_inbox()
end
