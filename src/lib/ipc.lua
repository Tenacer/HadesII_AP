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
			return "Z:" .. linux_home:gsub("/", "\\") .. "\\hadesii_ap\\"
		end
	end
	local profile = os.getenv("USERPROFILE") or "C:\\Users\\Default"
	return profile .. "\\hadesii_ap\\"
end

function ap_dir()
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

function ap_world_id()
	local s = ap_load_settings()
	return (s and s.world_id) or "default"
end

-- ── Outbox / inbox ────────────────────────────────────────────────────────────

function ap_flush_outbox(extra)
	local s = ap_load_state()
	local data = {
		score             = s.score,
		checks_sent       = s.checks_sent,
		items_index       = s.items_index,
		deaths            = s.deaths,
		victory           = s.victory or false,
		checked_locations = s.checked_locations,
		status            = "playing",
	}
	if extra then
		for k, v in pairs(extra) do data[k] = v end
	end
	local fname = "ap_out_" .. ap_world_id() .. ".json"
	local f = io.open(ap_dir() .. fname, "w")
	if not f then print("[HadesII_AP] ERROR: could not write " .. fname) return end
	f:write(json_val(data))
	f:close()
end

function ap_read_inbox()
	local fname = "ap_in_" .. ap_world_id() .. ".json"
	local f = io.open(ap_dir() .. fname, "r")
	if not f then return nil end
	local raw = f:read("*a")
	f:close()
	return json_decode(raw)
end
