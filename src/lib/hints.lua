---@meta _
---@diagnostic disable: lowercase-global

-- ── Hint dispatch ─────────────────────────────────────────────────────────────
-- Persisted, deduped list of locations the Python client should hint (LocationScouts create_as_hint=2).

function H2AP_HintLocation(name)
	local state = H2AP_LoadState()
	state.hinted_locations = state.hinted_locations or {}
	for _, existing in ipairs(state.hinted_locations) do
		if existing == name then return false end
	end
	table.insert(state.hinted_locations, name)
	print("[HadesII_AP] Location hinted: " .. name)
	H2AP_SaveState()
	H2AP_FlushOutbox()
	return true
end

-- ── Cauldron: hint visible incantations on category display ───────────────────

function H2AP_HintCauldronVisible(screen)
	local settings = H2AP_LoadSettings()
	if not settings then return end
	local do_cauldron = settings.cauldronsanity == 1
	local keyed = H2AP_KeyedIncantations(settings)
	if not (do_cauldron or next(keyed)) then return end
	if not (screen and screen.AvailableItems) then return end
	for _, itemData in ipairs(screen.AvailableItems) do
		local name = itemData and itemData.Name
		local ap_location = name and INCANTATION_LOCATIONS[name]
		if ap_location then
			-- Hint AP-keyed incantations always, the other 86 only under cauldronsanity.
			local should_hint
			if keyed[name] then
				should_hint = true
			elseif do_cauldron
				and not H2AP_IsSurfaceLockIncantation(name)
				and not H2AP_IsGoalIncantation(name) then
				should_hint = true
			end
			if should_hint then
				H2AP_HintLocation(ap_location)
			end
		end
	end
end

-- ── Quest log: hint visible (non-cashed-out) prophecies on screen open ────────

function H2AP_HintQuestlogVisible()
	local settings = H2AP_LoadSettings()
	if not (settings and settings.fatesanity == 1) then return end
	if not (QuestOrderData and QuestData and GameState and GameState.QuestStatus) then return end
	for _, questName in ipairs(QuestOrderData) do
		local questData = QuestData[questName]
		if questData then
			local ap_location = PROPHECY_LOCATIONS[questData.Name]
			if ap_location and GameState.QuestStatus[questData.Name] ~= "CashedOut" then
				if IsGameStateEligible(questData, questData.UnlockGameStateRequirements) then
					H2AP_HintLocation(ap_location)
				end
			end
		end
	end
end

-- ── Quest completion: poll for cashed-out prophecies ─────────────────────────
-- Backstop for the CashOutQuest override, catching any cashout that slipped through.

function H2AP_CheckQuestCompletions()
	local settings = H2AP_LoadSettings()
	if not (settings and settings.fatesanity == 1) then return end
	if not (GameState and GameState.QuestStatus) then return end
	for quest_id, location in pairs(PROPHECY_LOCATIONS) do
		if GameState.QuestStatus[quest_id] == "CashedOut" then
			H2AP_CheckLocation(location)
		end
	end
end
