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

-- ── Resource immunity ─────────────────────────────────────────────────────────
--
-- Resources we grant directly via AddResource (see items.lua) are silently wiped
-- by the game unless the "legitimacy" flag the vanilla game would have set is
-- present. PatchLogic.lua's DoPatches() runs this check on every launch/App.Reset,
-- and DoStoryReset() wipes the same resources too. Since we never make the player
-- earn the resource the vanilla way, we must assert the flag ourselves.
--
-- Each entry asserts only the persistent GameState flag(s) — that is all the wipe
-- checks read. We deliberately do NOT route through RecordUse(): it also writes
-- CurrentRun.UseRecord / BiomeUseRecord / CurrentRoom.UseRecord, which are nil
-- during an inbox poll at the title/Crossroads and would crash.
--
-- Keyed by AP item name. Each function must be idempotent and nil-safe.
local RESOURCE_IMMUNITY = {
	-- Gigaros (HadesSpearPoints): vanilla sets UseRecord.HadesSpear01 via
	-- RecordUse on the HadesSpear01 obstacle (RoomDataI.lua id 800279). Stored
	-- as a count, so seed 1 to match the vanilla type.
	["Gigaros"] = function()
		GameState.UseRecord = GameState.UseRecord or {}
		GameState.UseRecord.HadesSpear01 = GameState.UseRecord.HadesSpear01 or 1
	end,
	-- Entropy (MixerMythic): vanilla sets this when Typhon is defeated with
	-- Storm Stop. Plain GameState boolean — not a UseRecord entry.
	["Entropy"] = function()
		GameState.TyphonDefeatedWithStormStop = true
	end,
}

-- Called after every inbox poll. Counts how many Zodiac Sand / Void Lens /
-- Gigaros have been granted (index < items_index) and ensures the matching
-- story flags are set, plus re-asserts resource-immunity flags for any granted
-- item that needs one. Idempotent — safe to call on every poll.
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
			-- Re-assert the immunity flag for any granted resource that needs it.
			local immunize = RESOURCE_IMMUNITY[name]
			if immunize then immunize() end
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
