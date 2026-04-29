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
--   last_deathlink_seq (int)   — seq of last processed incoming DeathLink (dedup guard)
--   vow_received       (table) — shrine_upgrade_name -> count of vow items received (reverse_Fear)

local _state = nil

local function state_path() return ap_dir() .. "ap_state_" .. ap_world_id() .. ".json" end

function ap_load_state()
	if _state then return _state end
	_state = {
		score              = 0,
		checks_sent        = 0,
		items_index        = 0,
		deaths             = 0,
		victory            = false,
		checked_locations  = {},
		last_deathlink_seq = -1,
		vow_received       = {},
	}
	local f = io.open(state_path(), "r")
	if not f then return _state end
	local raw = f:read("*a")
	f:close()
	local parsed = json_decode(raw)
	if type(parsed) == "table" then
		_state = parsed
		if type(_state.checked_locations) ~= "table" then
			_state.checked_locations = {}
		end
	end
	return _state
end

function ap_save_state()
	local s = ap_load_state()
	local f = io.open(state_path(), "w")
	if not f then print("[HadesII_AP] ERROR: could not write state") return end
	f:write(json_val(s))
	f:close()
end

-- ── Location tracking ─────────────────────────────────────────────────────────

function ap_check_location(name)
	local state = ap_load_state()
	for _, existing in ipairs(state.checked_locations) do
		if existing == name then return end  -- already recorded
	end
	table.insert(state.checked_locations, name)
	print("[HadesII_AP] Location checked: " .. name)
	ap_save_state()
	ap_flush_outbox()
end
