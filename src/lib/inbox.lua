---@meta _
---@diagnostic disable: lowercase-global

-- ── Inbox processing ──────────────────────────────────────────────────────────

function H2AP_ProcessInbox()
	local inbox = H2AP_ReadInbox()
	if not inbox then return end

	-- The Python client may have written new scout responses to
	-- ap_location_items_<world>.json since our last cache fill (e.g. a
	-- LocationInfo arrived just after Connected). Drop the cache so the next
	-- consumer (boss-reward spawn, sjson re-hook) sees fresh data.
	H2AP_InvalidateLocationItemsCache()

	-- DeathLink: Python client appends this when another player dies.
	-- deathlink_seq is an incrementing counter so each death only triggers once
	-- even if the flag stays in the inbox across multiple polls.
	if inbox.deathlink then
		local seq = inbox.deathlink_seq or 0
		local state = H2AP_LoadState()
		if seq ~= (state.last_deathlink_seq or -1) then
			state.last_deathlink_seq = seq
			H2AP_SaveState()
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
	local state   = H2AP_LoadState()
	local items   = inbox.items or {}
	local granted = 0

	for _, item in ipairs(items) do
		local idx = item.index
		if idx ~= nil and idx >= state.items_index then
			if H2AP_GiveItem(item.item_name or "") then
				state.items_index = idx + 1
				granted = granted + 1
				H2AP_NotifyReceived(item)
			end
		end
	end

	if granted > 0 then
		print("[HadesII_AP] Granted " .. granted .. " item(s) from AP")
		H2AP_SaveState()
		H2AP_FlushOutbox()
	end

	-- Sync story flags on every poll (idempotent). Also covers restarts where
	-- items_index is restored from state but GameState flags need re-applying.
	H2AP_SyncStoryFlags(inbox)

	-- Re-apply shrine levels on every poll so they take effect as soon as
	-- ap_settings.json is written by the Python client, even mid-hub-session.
	H2AP_ApplyShrineLevels()
end

-- ── Room hooks ────────────────────────────────────────────────────────────────

function H2AP_SetupMap()
	local state = H2AP_LoadState()
	print("[HadesII_AP] Map loaded — score: " .. state.score
		.. ", checks: " .. state.checks_sent
		.. ", items: "  .. state.items_index)
	H2AP_ApplyShrineLevels()
	H2AP_PatchVowRequirements()
	H2AP_InitWeaponState()
	H2AP_ProcessInbox()
	H2AP_CheckToolUnlocks()
	H2AP_CheckQuestCompletions()
	H2AP_ProcessTrapQueue()
end
