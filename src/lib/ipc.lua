---@meta _
---@diagnostic disable: lowercase-global

-- ── IPC path detection ────────────────────────────────────────────────────────

local _ap_dir = nil

local function detect_ap_dir()
	if config.ap_path and config.ap_path ~= "" then
		return config.ap_path
	end
	local compat = os.getenv("STEAM_COMPAT_DATA_PATH")
	if compat then
		local linux_home = compat:match("(.-)/%.local/") or compat:match("(.-)/%.steam/")
		if linux_home then
			return "Z:" .. linux_home:gsub("/", "\\") .. "\\.local\\share\\HadesII_AP\\"
		end
	end
	local local_appdata = os.getenv("LOCALAPPDATA")
	if local_appdata and local_appdata ~= "" then
		return local_appdata .. "\\HadesII_AP\\"
	end
	local profile = os.getenv("USERPROFILE") or "C:\\Users\\Default"
	return profile .. "\\AppData\\Local\\HadesII_AP\\"
end

function H2AP_Dir()
	if not _ap_dir then
		_ap_dir = detect_ap_dir()
		print("[HadesII_AP] IPC directory: " .. _ap_dir)
	end
	return _ap_dir
end

-- ── World identity ────────────────────────────────────────────────────────────
-- world_id is written into ap_settings.json by the Python client on connect.
-- It uniquely identifies the AP slot being played ({seed_name}_{slot}).
-- All IPC files are suffixed with the world_id so that multiple Hades II worlds
-- in the same generate don't share state, and switching worlds is safe.
-- Note: settings are cached per hot-reload session; triggering a hot-reload
-- (or restarting the game) is required when switching worlds mid-session.

function H2AP_WorldId()
	local s = H2AP_LoadSettings()
	return (s and s.world_id) or "default"
end

-- ── Outbox / inbox ────────────────────────────────────────────────────────────

function H2AP_FlushOutbox(extra)
	local s = H2AP_LoadState()
	local data = {
		score             = s.score,
		score_underworld  = s.score_underworld or 0,
		score_surface     = s.score_surface or 0,
		checks_sent       = s.checks_sent,
		items_index       = s.items_index,
		deaths            = s.deaths,
		victory           = s.victory or false,
		checked_locations = s.checked_locations,
		hinted_locations  = s.hinted_locations or {},
		weapon_clears     = H2AP_DistinctWeaponClears(),
		status            = "playing",
	}
	if extra then
		for k, v in pairs(extra) do data[k] = v end
	end
	local fname = "ap_out_" .. H2AP_WorldId() .. ".json"
	local f = io.open(H2AP_Dir() .. fname, "w")
	if not f then print("[HadesII_AP] ERROR: could not write " .. fname) return end
	f:write(H2AP_JsonVal(data))
	f:close()
end

function H2AP_ReadInbox()
	local fname = "ap_in_" .. H2AP_WorldId() .. ".json"
	local f = io.open(H2AP_Dir() .. fname, "r")
	if not f then return nil end
	local raw = f:read("*a")
	f:close()
	return H2AP_JsonDecode(raw)
end

-- ── Location items (written by Python client after LocationScouts) ────────────
-- Maps AP location name → item display string (e.g. "Progressive Sword [Player2]").
-- Cached after first successful read; nil returned and retried if file not found yet.

local _location_items_cache = nil

function H2AP_ReadLocationItems()
	if _location_items_cache then return _location_items_cache end
	local fname = "ap_location_items_" .. H2AP_WorldId() .. ".json"
	local f = io.open(H2AP_Dir() .. fname, "r")
	if not f then return nil end
	local raw = f:read("*a")
	f:close()
	local data = H2AP_JsonDecode(raw)
	if type(data) == "table" then
		_location_items_cache = data
	end
	return _location_items_cache
end

-- Force the location-items cache to refresh on next read (e.g. after the
-- Python client writes a new scout response).
function H2AP_InvalidateLocationItemsCache()
	_location_items_cache = nil
end

-- Returns the structured entry (table) for a scouted location, or nil if
-- the file isn't on disk yet or the location wasn't scouted. Each entry has
--   item_name (str), player_slot (int), player_name (str),
--   sender_game (str), is_local (bool), display (str)
-- See HadesIIClient._write_location_items for the source of truth.
function H2AP_GetLocationItem(name)
	local data = H2AP_ReadLocationItems()
	if type(data) ~= "table" then return nil end
	local entry = data[name]
	if type(entry) == "table" then return entry end
	return nil
end
