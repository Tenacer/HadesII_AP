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
-- world_id ({seed_name}_{slot}) suffixes every IPC file so multiple Hades II worlds don't share state.

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
		checks_sent_underworld = s.checks_sent_underworld or 0,
		checks_sent_surface    = s.checks_sent_surface or 0,
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
-- AP location name → scouted item entry, cached after the first successful read.

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

-- Force the location-items cache to refresh on next read.
function H2AP_InvalidateLocationItemsCache()
	_location_items_cache = nil
end

-- Returns the scouted entry table for a location, or nil (see HadesIIClient._write_location_items for the fields).
function H2AP_GetLocationItem(name)
	local data = H2AP_ReadLocationItems()
	if type(data) ~= "table" then return nil end
	local entry = data[name]
	if type(entry) == "table" then return entry end
	return nil
end
