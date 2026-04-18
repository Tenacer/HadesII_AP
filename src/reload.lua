---@meta _
---@diagnostic disable: lowercase-global

-- ── JSON encoder (outbox is read by Python) ───────────────────────────────────

local function json_val(v)
	local t = type(v)
	if t == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		if #v > 0 then
			local parts = {}
			for _, item in ipairs(v) do parts[#parts+1] = json_val(item) end
			return "[" .. table.concat(parts, ",") .. "]"
		else
			local parts = {}
			for k, val in pairs(v) do
				parts[#parts+1] = '"' .. tostring(k) .. '":' .. json_val(val)
			end
			return "{" .. table.concat(parts, ",") .. "}"
		end
	end
	return "null"
end

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
		os.execute('mkdir "' .. _ap_dir:sub(1, -2) .. '"')
		print("[HadesII_AP] IPC directory: " .. _ap_dir)
	end
	return _ap_dir
end

-- ── State persistence (score survives across runs) ────────────────────────────
-- Format: simple key=value text file, one entry per line.

local _state = nil

local function state_path() return ap_dir() .. "ap_state.txt" end

function ap_load_state()
	if _state then return _state end
	_state = { score = 0, checks_sent = 0, items_index = 0 }
	local f = io.open(state_path(), "r")
	if not f then return _state end
	for line in f:lines() do
		local k, v = line:match("^(%w+)=(%d+)$")
		if k and _state[k] ~= nil then
			_state[k] = tonumber(v)
		end
	end
	f:close()
	return _state
end

function ap_save_state()
	local s = ap_load_state()
	local f = io.open(state_path(), "w")
	if not f then print("[HadesII_AP] ERROR: could not write state") return end
	for k, v in pairs(s) do f:write(k .. "=" .. tostring(v) .. "\n") end
	f:close()
end

-- ── Outbox / inbox ────────────────────────────────────────────────────────────

function ap_flush_outbox(extra)
	local s = ap_load_state()
	local data = {
		score       = s.score,
		checks_sent = s.checks_sent,
		items_index = s.items_index,
		status      = "playing",
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
	local data = f:read("*a")
	f:close()
	return data
end

-- ── Score tracking ────────────────────────────────────────────────────────────

local FINAL_BOSS_ROOMS = { I_Boss01 = true, Q_Boss01 = true, Q_Boss02 = true }

function on_room_cleared(currentRoom, currentEncounter)
	if not currentRoom then return end

	if FINAL_BOSS_ROOMS[currentRoom.Name] then
		on_boss_cleared(currentRoom)
		return
	end

	local state = ap_load_state()
	local points = config.points_per_room or 1
	state.score = state.score + points

	local threshold = config.points_per_location or 10
	local new_checks = math.floor(state.score / threshold)
	if new_checks > state.checks_sent then
		state.checks_sent = new_checks
		print("[HadesII_AP] New check(s) reached — total sent: " .. state.checks_sent)
	end

	print("[HadesII_AP] +" .. points .. " pts → " .. state.score .. " total, " .. state.checks_sent .. " checks sent")
	ap_save_state()
	ap_flush_outbox()
end

function on_boss_cleared(currentRoom)
	local state = ap_load_state()
	print("[HadesII_AP] Final boss cleared: " .. currentRoom.Name)
	ap_flush_outbox({ status = "boss_cleared", boss_room = currentRoom.Name })
end

-- ── Boss reward replacement ───────────────────────────────────────────────────

function should_replace_reward(currentRoom)
	return currentRoom ~= nil and FINAL_BOSS_ROOMS[currentRoom.Name] == true
end

-- ── Item granting ─────────────────────────────────────────────────────────────

-- Maps AP item resource_id → internal game resource name
local RESOURCE_MAP = {
	-- Meta-progression
	Ashes          = "MetaCardPointsCommon",
	Psyche         = "MemPointsCommon",
	Bones          = "MetaCurrency",
	Nightmare      = "WeaponPointsRare",
	Nectar         = "GiftPoints",
	Ambrosia       = "GiftPointsRare",
	FabricOfMemory = "MetaFabric",
	-- Biome boss drops
	Cinder      = "MixerFBoss",   -- Erebus
	Pearl       = "MixerGBoss",   -- Oceanus
	Tears       = "MixerHBoss",   -- Fields of Mourning
	Sand        = "MixerIBoss",   -- Tartarus
	Wool        = "MixerNBoss",   -- City of Ephyra
	GoldenApple = "MixerOBoss",   -- Rift of Thessaly
	Feather     = "MixerPBoss",   -- Slope of Olympus
	VoidLens    = "MixerQBoss",   -- Mount Olympus
}

function give_resource(resource_id, amount)
	local internal = RESOURCE_MAP[resource_id]
	if not internal then
		print("[HadesII_AP] Unknown resource_id: " .. tostring(resource_id))
		return false
	end
	AddResource(internal, amount, _PLUGIN.guid)
	print("[HadesII_AP] Gave " .. amount .. "x " .. resource_id .. " (" .. internal .. ")")
	return true
end

-- kept for the Gift keybind debug shortcut
function give_Ashes(amount)
	give_resource("Ashes", amount)
end

-- ── Inbox processing (grant items from AP) ───────────────────────────────────

local function parse_inbox_items(raw)
	-- Extracts the items array from the JSON inbox.
	-- Parses entries of the form: {"index":N,"resource_id":"X","amount":N}
	local items = {}
	for entry in raw:gmatch("{(.-)}" ) do
		local index       = tonumber(entry:match('"index"%s*:%s*(%d+)'))
		local resource_id = entry:match('"resource_id"%s*:%s*"([^"]+)"')
		local amount      = tonumber(entry:match('"amount"%s*:%s*(%d+)'))
		if index and resource_id and amount then
			items[#items + 1] = { index = index, resource_id = resource_id, amount = amount }
		end
	end
	return items
end

function ap_process_inbox()
	local raw = ap_read_inbox()
	if not raw then return end

	local state = ap_load_state()
	local items = parse_inbox_items(raw)

	local granted = 0
	for _, item in ipairs(items) do
		if item.index >= state.items_index then
			if give_resource(item.resource_id, item.amount) then
				state.items_index = item.index + 1
				granted = granted + 1
			end
		end
	end

	if granted > 0 then
		print("[HadesII_AP] Granted " .. granted .. " item(s) from AP")
		ap_save_state()
		ap_flush_outbox()
	end
end

-- ── Room hooks ────────────────────────────────────────────────────────────────

function prefix_SetupMap()
	local state = ap_load_state()
	print("[HadesII_AP] Room loaded — score: " .. state.score .. ", checks sent: " .. state.checks_sent)
	ap_process_inbox()
end

function sjson_ShellText(data)
	for _,v in ipairs(data.Texts) do
		if v.Id == 'MainMenuScreen_PlayGame' then
			v.DisplayName = 'Hades II AP'
			break
		end
	end
end
