---@meta _
---@diagnostic disable: lowercase-global

-- ── Hint dispatch ─────────────────────────────────────────────────────────────
-- Cumulative list of AP location names we've asked the Python client to hint.
-- Persists in ap_state.json so we never re-hint the same location, even across
-- game restarts. Python client dedupes again via its own session set, then sends
-- LocationScouts with create_as_hint=2 (free hint, no point cost).

function ap_hint_location(name)
	local state = ap_load_state()
	state.hinted_locations = state.hinted_locations or {}
	for _, existing in ipairs(state.hinted_locations) do
		if existing == name then return false end
	end
	table.insert(state.hinted_locations, name)
	print("[HadesII_AP] Location hinted: " .. name)
	ap_save_state()
	ap_flush_outbox()
	return true
end

-- ── Cauldron: hint visible incantations on category display ───────────────────
-- screen.AvailableItems is populated by GhostAdminDisplayCategory and contains
-- exactly the WorldUpgradeData entries shown in the active tab (excludes purchased
-- non-repeatable items + reveal-capped items). We hint each one whose key is in
-- INCANTATION_LOCATIONS.

function ap_hint_cauldron_visible(screen)
	local settings = ap_load_settings()
	if not (settings and settings.cauldronsanity == 1) then return end
	if not (screen and screen.AvailableItems) then return end
	for _, itemData in ipairs(screen.AvailableItems) do
		local ap_location = itemData and itemData.Name and INCANTATION_LOCATIONS[itemData.Name]
		if ap_location then
			ap_hint_location(ap_location)
		end
	end
end

-- ── Quest log: hint visible (non-cashed-out) prophecies on screen open ────────
-- Mirrors OpenQuestLogScreen's filter: a quest is shown when its status is not
-- "CashedOut" AND its UnlockGameStateRequirements are met. CashedOut quests have
-- already had their AP check sent so hinting them adds nothing.

function ap_hint_questlog_visible()
	local settings = ap_load_settings()
	if not (settings and settings.fatesanity == 1) then return end
	if not (QuestOrderData and QuestData and GameState and GameState.QuestStatus) then return end
	for _, questName in ipairs(QuestOrderData) do
		local questData = QuestData[questName]
		if questData then
			local ap_location = PROPHECY_LOCATIONS[questData.Name]
			if ap_location and GameState.QuestStatus[questData.Name] ~= "CashedOut" then
				if IsGameStateEligible(questData, questData.UnlockGameStateRequirements) then
					ap_hint_location(ap_location)
				end
			end
		end
	end
end

-- ── Quest completion: poll for cashed-out prophecies ─────────────────────────
-- Backstop for the CashOutQuest override (reload.lua). The override fires the
-- AP check the moment the player clicks cashout; this poll catches anything
-- that slipped through (mod reload mid-cashout, save-state edge cases) on the
-- next prefix_SetupMap. ap_check_location is idempotent.

function ap_check_quest_completions()
	local settings = ap_load_settings()
	if not (settings and settings.fatesanity == 1) then return end
	if not (GameState and GameState.QuestStatus) then return end
	for quest_id, location in pairs(PROPHECY_LOCATIONS) do
		if GameState.QuestStatus[quest_id] == "CashedOut" then
			ap_check_location(location)
		end
	end
end
