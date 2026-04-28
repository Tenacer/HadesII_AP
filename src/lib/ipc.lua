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
	local f = io.open(ap_dir() .. "ap_out.json", "w")
	if not f then print("[HadesII_AP] ERROR: could not write ap_out.json") return end
	f:write(json_val(data))
	f:close()
end

function ap_read_inbox()
	local f = io.open(ap_dir() .. "ap_in.json", "r")
	if not f then return nil end
	local raw = f:read("*a")
	f:close()
	return json_decode(raw)
end
