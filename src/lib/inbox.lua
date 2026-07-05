---@meta _
---@diagnostic disable: lowercase-global

-- ── Inbox processing ──────────────────────────────────────────────────────────

function H2AP_ProcessInbox()
	local inbox = H2AP_ReadInbox()
	if not inbox then return end

	-- Drop the scout cache so consumers see any newly written scout responses.
	H2AP_InvalidateLocationItemsCache()

	-- DeathLink: deathlink_seq ensures each death only triggers once across polls.
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

	-- Sync story flags and shrine levels on every poll (both idempotent).
	H2AP_SyncStoryFlags(inbox)
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
	H2AP_ApplyUnlockBroker()
	H2AP_ProcessInbox()
	H2AP_CheckQuestCompletions()
	H2AP_ProcessTrapQueue()
end
