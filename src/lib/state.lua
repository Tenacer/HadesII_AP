---@meta _
---@diagnostic disable: lowercase-global

-- ── State persistence ─────────────────────────────────────────────────────────
-- Persisted as JSON so complex fields (checked_locations array) survive restarts.
-- Fields:
--   score              (int)   — cumulative room-clear score
--   checks_sent        (int)   — number of score checks earned so far
--   items_index        (int)   — next AP item index to process
--   deaths             (int)   — raw death counter forwarded to DeathLink
--   victory            (bool)  — true once the goal condition is met
--   checked_locations  (array) — AP location names reported to the Python client
--   hinted_locations   (array) — AP location names the Python client should hint (create_as_hint=2)
--   last_deathlink_seq (int)   — seq of last processed incoming DeathLink (dedup guard)
--   vow_received       (table) — shrine_upgrade_name -> count of vow items received (reverse_Fear)
--   chronos_kills      (int)   — Chronos kills observed (per-kill reward indexing, True Ending)
--   typhon_kills       (int)   — Typhon  kills observed (per-kill reward indexing, True Ending)
--   weapon_clears      (table) — set of internal weapon names that have cleared a
--                                final boss (distinct-clear count for the weapons goal)

local _state = nil

local function state_path() return H2AP_Dir() .. "ap_state_" .. H2AP_WorldId() .. ".json" end

function H2AP_LoadState()
	if _state then return _state end
	_state = {
		score              = 0,
		checks_sent        = 0,
		items_index        = 0,
		deaths             = 0,
		victory            = false,
		checked_locations  = {},
		hinted_locations   = {},
		last_deathlink_seq = -1,
		vow_received       = {},
		chronos_kills      = 0,
		typhon_kills       = 0,
		weapon_clears      = {},
	}
	local f = io.open(state_path(), "r")
	if not f then return _state end
	local raw = f:read("*a")
	f:close()
	local parsed = H2AP_JsonDecode(raw)
	if type(parsed) == "table" then
		_state = parsed
		if type(_state.checked_locations) ~= "table" then
			_state.checked_locations = {}
		end
		if type(_state.hinted_locations) ~= "table" then
			_state.hinted_locations = {}
		end
		if type(_state.weapon_clears) ~= "table" then
			_state.weapon_clears = {}
		end
	end
	return _state
end

-- Number of distinct weapons that have cleared a final boss (weapons goal).
function H2AP_DistinctWeaponClears()
	local n = 0
	for _ in pairs(H2AP_LoadState().weapon_clears) do n = n + 1 end
	return n
end

function H2AP_SaveState()
	local s = H2AP_LoadState()
	local f = io.open(state_path(), "w")
	if not f then print("[HadesII_AP] ERROR: could not write state") return end
	f:write(H2AP_JsonVal(s))
	f:close()
end

-- ── Location tracking ─────────────────────────────────────────────────────────

function H2AP_CheckLocation(name)
	local state = H2AP_LoadState()
	for _, existing in ipairs(state.checked_locations) do
		if existing == name then return end  -- already recorded
	end
	table.insert(state.checked_locations, name)
	print("[HadesII_AP] Location checked: " .. name)
	H2AP_NotifySent(name)
	H2AP_SaveState()
	H2AP_FlushOutbox()
end
