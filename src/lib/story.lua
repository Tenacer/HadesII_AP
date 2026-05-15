---@meta _
---@diagnostic disable: lowercase-global

-- ── Story flag injection ──────────────────────────────────────────────────────

local function set_text_lines_flag(flag)
	GameState.TextLinesRecord = GameState.TextLinesRecord or {}
	if not GameState.TextLinesRecord[flag] then
		GameState.TextLinesRecord[flag] = true
		print("[HadesII_AP] TextLinesRecord: " .. flag)
	end
	-- Mirror into the active run so checks inside a run see the flag immediately.
	if CurrentRun and CurrentRun.TextLinesRecord then
		CurrentRun.TextLinesRecord[flag] = true
	end
end

-- Called after every inbox poll. Counts how many Zodiac Sand / Void Lens /
-- Gigaros have been granted (index < items_index) and ensures the matching
-- story flags are set. Idempotent — safe to call on every poll.
function H2AP_SyncStoryFlags(inbox)
	if not GameState then return end
	local items = inbox.items or {}
	local state = H2AP_LoadState()
	local sand_count  = 0
	local lens_count  = 0
	local has_gigaros = false

	for _, item in ipairs(items) do
		if item.index ~= nil and item.index < state.items_index then
			local name = item.item_name or ""
			if     name == "Zodiac Sand" then sand_count  = sand_count + 1
			elseif name == "Void Lens"   then lens_count  = lens_count + 1
			elseif name == "Gigaros"     then has_gigaros = true
			end
		end
	end

	for i = 1, math.min(sand_count, #ZAGREUS_MEETING_FLAGS) do
		set_text_lines_flag(ZAGREUS_MEETING_FLAGS[i])
	end

	for i = 1, math.min(lens_count, #ZEUS_MEETING_FLAGS) do
		set_text_lines_flag(ZEUS_MEETING_FLAGS[i])
	end

	-- Gigaros: ensure the full prerequisite chain + meeting05 are all set.
	if has_gigaros then
		for _, flag in ipairs(ZAGREUS_MEETING_FLAGS) do
			set_text_lines_flag(flag)
		end
		set_text_lines_flag("ZagreusPastMeeting05")
	end
end
