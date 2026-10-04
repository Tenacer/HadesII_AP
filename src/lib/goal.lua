---@meta _
---@diagnostic disable: lowercase-global

-- Goal: BossDefeats and True Ending victory, True Ending ingredients and the story flags they unlock.

-- ═══ Data ════════════════════════════════════════════════════════════════════

-- One flag injected per Zodiac Sand received, in order.
-- Meeting05 is reserved for Gigaros (see H2AP_SyncStoryFlags).
ZAGREUS_MEETING_FLAGS = {
	"ZagreusPastMeeting02",
	"ZagreusPastMeeting02_2",
	"ZagreusPastMeeting03",
	"ZagreusPastMeeting04",
	"ZagreusPastMeeting04_2",
	"ZagreusPastMeeting04_3",
}

-- One flag injected per Void Lens received, in order.
ZEUS_MEETING_FLAGS = {
	"ZeusPalaceMeeting02",
	"ZeusPalaceMeeting03_A",
	"ZeusPalaceMeeting04",
	"ZeusPalaceMeeting04_B",
}

-- ── Resource immunity ─────────────────────────────────────────────────────────
-- The game wipes directly-granted resources unless the "legitimacy" flag vanilla would have set is present, so assert those flags ourselves (idempotent, nil-safe).
local RESOURCE_IMMUNITY = {
	-- Gigaros: vanilla records HadesSpear01 use as a count.
	["Gigaros"] = function()
		GameState.UseRecord = GameState.UseRecord or {}
		GameState.UseRecord.HadesSpear01 = GameState.UseRecord.HadesSpear01 or 1
	end,
	-- Entropy: vanilla sets this on the Storm Stop Typhon kill.
	["Entropy"] = function()
		GameState.TyphonDefeatedWithStormStop = true
	end,
}

-- ═══ Logic ═══════════════════════════════════════════════════════════════════

-- ── Story flags ───────────────────────────────────────────────────────────────

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

-- Sync story flags for granted items after every inbox poll; idempotent.
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

-- True Ending ingredients grant the resource and let H2AP_SyncStoryFlags handle flags; returns nil for other items.
function H2AP_GoalGiveItem(item_name)
	if item_name == "Zodiac Sand" then
		AddResource("MixerIBoss", 1, _PLUGIN.guid)
		print("[HadesII_AP] Gave Zodiac Sand (MixerIBoss)")
		return true
	end
	if item_name == "Void Lens" then
		AddResource("MixerQBoss", 1, _PLUGIN.guid)
		print("[HadesII_AP] Gave Void Lens (MixerQBoss)")
		return true
	end
	if item_name == "Gigaros" then
		AddResource("HadesSpearPoints", 1, _PLUGIN.guid)
		print("[HadesII_AP] Gave Gigaros (HadesSpearPoints)")
		return true
	end
	if item_name == "Entropy" then
		AddResource("MixerMythic", 1, _PLUGIN.guid)
		print("[HadesII_AP] Gave Entropy (MixerMythic)")
		return true
	end
	return nil
end

-- ── Victory ───────────────────────────────────────────────────────────────────

-- Evaluate the BossDefeats goal after a boss kill and flag victory if met (True Ending victory fires on the credits death instead).
function H2AP_CheckBossDefeatsVictory()
	local settings = H2AP_LoadSettings() or {}
	if settings.true_ending == true or settings.true_ending == 1 then return end

	local state = H2AP_LoadState()
	if state.victory then return end

	local chronos = state.chronos_kills or 0
	local typhon  = state.typhon_kills or 0
	local mode    = settings.boss_defeats_mode
	local met
	if mode == 1 or mode == "separate" then
		met = chronos >= (settings.chronos_kills_needed or 7)
			and typhon >= (settings.typhon_kills_needed or 5)
	else
		met = (chronos + typhon) >= (settings.boss_defeats_needed or 5)
	end

	if met then
		state.victory = true
		print("[HadesII_AP] BossDefeats goal met — victory!")
		H2AP_SaveState()
		H2AP_FlushOutbox()
	end
end

-- Redirect the final-boss exit to EndEarlyAccessPresentation, except on a True Ending run with both goal incantations (the credits must play).
function H2AP_RedirectBossExit()
	local settings = H2AP_LoadSettings() or {}
	local is_te_run = settings.true_ending
		and GameState and GameState.WorldUpgrades
		and GameState.WorldUpgrades.WorldUpgradeTimeStop
		and GameState.WorldUpgrades.WorldUpgradeStormStop
	if settings.score_rewards_amount ~= nil
			and not (CurrentRun and CurrentRun.IsDreamRun)
			and not (GameState and GameState.ReachedTrueEnding)
			and not is_te_run then
		CurrentRun.CurrentRoom.ExitFunctionName = "EndEarlyAccessPresentation"
		CurrentRun.CurrentRoom.SkipLoadNextMap  = true
		print("[HadesII_AP] Boss cleared — exit redirected to EndEarlyAccessPresentation")
	end
end

-- CurrentRun.PlayedTrueEnding is set just before the credits Kill(Hero), marking True Ending victory; returns true on that death.
function H2AP_CheckTrueEndingVictory()
	if not (CurrentRun and CurrentRun.PlayedTrueEnding) then return false end
	local state = H2AP_LoadState()
	if not state.victory then
		state.victory = true
		print("[HadesII_AP] True Ending victory!")
		H2AP_SaveState()
		H2AP_FlushOutbox()
	end
	return true
end
