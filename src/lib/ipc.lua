---@meta _
---@diagnostic disable: lowercase-global

-- Communication with the Python client: settings, state persistence, outbox/inbox, location checks, hints and item dispatch.

-- ═══ Data ════════════════════════════════════════════════════════════════════

-- ── State fields ──────────────────────────────────────────────────────────────
-- Persisted as JSON so complex fields (checked_locations array) survive restarts.
-- Fields:
--   score              (int)   — cumulative room-clear score (sum of the two routes; display only)
--   score_underworld   (int)   — cumulative score on the underworld/Chronos route (F/G/H/I)
--   score_surface      (int)   — cumulative score on the surface/Typhon route (N/O/P/Q)
--   checks_sent        (int)   — number of score checks earned so far (combined total)
--   checks_sent_underworld (int) — score checks earned from the underworld budget (separate mode)
--   checks_sent_surface    (int) — score checks earned from the surface budget (separate mode)
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

local COLOR_SENT     = { 0.55, 0.85, 1.00, 1.00 }
local COLOR_RECEIVED = { 0.65, 1.00, 0.65, 1.00 }

-- ═══ Logic ═══════════════════════════════════════════════════════════════════

-- ── Settings (written by Python client on AP connect) ─────────────────────────
-- Cached once the file is found; retried on every call until then.

local _settings = nil

function H2AP_LoadSettings()
	if _settings then return _settings end
	local f = io.open(H2AP_Dir() .. "ap_settings.json", "r")
	if not f then
		-- Don't cache so the next call retries (the client may not have connected yet).
		return {}
	end
	local raw = f:read("*a")
	f:close()
	_settings = H2AP_JsonDecode(raw) or {}
	print("[HadesII_AP] Settings loaded: fear_system=" .. tostring(_settings.fear_system)
		.. " score_rewards=" .. tostring(_settings.score_rewards_amount))
	return _settings
end

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

-- ── State persistence ─────────────────────────────────────────────────────────

local _state = nil

local function state_path() return H2AP_Dir() .. "ap_state_" .. H2AP_WorldId() .. ".json" end

function H2AP_LoadState()
	if _state then return _state end
	_state = {
		score              = 0,
		score_underworld   = 0,
		score_surface      = 0,
		checks_sent        = 0,
		checks_sent_underworld = 0,
		checks_sent_surface    = 0,
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
		-- Migration: attribute a legacy combined score entirely to the underworld route.
		if type(_state.score_underworld) ~= "number" then
			_state.score_underworld = _state.score or 0
		end
		if type(_state.score_surface) ~= "number" then
			_state.score_surface = 0
		end
	end
	return _state
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

-- ── Hints ─────────────────────────────────────────────────────────────────────
-- Persisted, deduped list of locations the Python client should hint (LocationScouts create_as_hint=2).

function H2AP_HintLocation(name)
	local state = H2AP_LoadState()
	state.hinted_locations = state.hinted_locations or {}
	for _, existing in ipairs(state.hinted_locations) do
		if existing == name then return false end
	end
	table.insert(state.hinted_locations, name)
	print("[HadesII_AP] Location hinted: " .. name)
	H2AP_SaveState()
	H2AP_FlushOutbox()
	return true
end

-- ── Item granting ─────────────────────────────────────────────────────────────

function H2AP_GiveItem(item_name)
	local handled = H2AP_FearGiveItem(item_name)
	if handled ~= nil then return handled end

	handled = H2AP_TrapsGiveItem(item_name)
	if handled ~= nil then return handled end
	handled = H2AP_CauldronGiveItem(item_name)
	if handled ~= nil then return handled end
	handled = H2AP_GoalGiveItem(item_name)
	if handled ~= nil then return handled end
	handled = H2AP_KeepsakeGiveItem(item_name)
	if handled ~= nil then return handled end
	handled = H2AP_FamiliarGiveItem(item_name)
	if handled ~= nil then return handled end
	handled = H2AP_ToolGiveItem(item_name)
	if handled ~= nil then return handled end
	handled = H2AP_WeaponGiveItem(item_name)
	if handled ~= nil then return handled end
	handled = H2AP_AspectGiveItem(item_name)
	if handled ~= nil then return handled end
	handled = H2AP_ProphecyGiveItem(item_name)
	if handled ~= nil then return handled end
	-- Unknown item — log and advance items_index so it isn't re-processed.
	print("[HadesII_AP] Received (pending implementation): " .. tostring(item_name))
	return true
end

-- ── Inbox processing ──────────────────────────────────────────────────────────

-- DeathLink: deathlink_seq ensures each death only triggers once across polls.
local function process_deathlink(inbox)
	if not inbox.deathlink then return end
	local seq = inbox.deathlink_seq or 0
	local state = H2AP_LoadState()
	if seq ~= (state.last_deathlink_seq or -1) then
		state.last_deathlink_seq = seq
		H2AP_SaveState()
		if CurrentRun and CurrentRun.Hero and not CurrentRun.Hero.IsDead
				and CurrentRun.CurrentRoom and not SessionMapState.HandlingDeath then
			print("[HadesII_AP] DeathLink from: " .. tostring(inbox.deathlink_source or "unknown"))
			Kill(CurrentRun.Hero, { AttackerName = "DeathLink" })
		else
			print("[HadesII_AP] DeathLink received but not in active run — ignored")
		end
	end
end

function H2AP_ProcessInbox()
	local inbox = H2AP_ReadInbox()
	if not inbox then return end

	-- Drop the scout cache so consumers see any newly written scout responses.
	H2AP_InvalidateLocationItemsCache()

	process_deathlink(inbox)

	-- Grant items in index order, skipping ones already processed.
	local state   = H2AP_LoadState()
	local items   = inbox.items or {}
	local granted = 0

	for _, item in ipairs(items) do
		local idx = item.index
		if idx ~= nil and idx >= state.items_index then
			if H2AP_GiveItem(item.item_name or "") then
				state.items_index = idx + 1
				granted = granted + 1
				H2AP_NotifyReceived(item)
			end
		end
	end

	if granted > 0 then
		print("[HadesII_AP] Granted " .. granted .. " item(s) from AP")
		H2AP_SaveState()
		H2AP_FlushOutbox()
	end

	-- Sync story flags and shrine levels on every poll (both idempotent).
	H2AP_SyncStoryFlags(inbox)
	H2AP_ApplyShrineLevels()
end

-- Count a regular death for DeathLink; amnesty is handled on the Python client side.
function H2AP_RecordDeath()
	local state = H2AP_LoadState()
	state.deaths = (state.deaths or 0) + 1
	print("[HadesII_AP] Death recorded (" .. state.deaths .. " total)")
	H2AP_SaveState()
	H2AP_FlushOutbox()
end

-- Start the inbox polling thread once; called on the first SetupMap because thread() needs SessionMapState.
local _polling_started = false
function H2AP_StartInboxPolling()
	if _polling_started then return end
	_polling_started = true
	-- Persist=true survives LoadMap/KillNonPersistentThreads so we only need to start once.
	thread(function()
		while true do
			wait(0.5, "AP_Inbox_Poll", true)
			H2AP_ProcessInbox()
		end
	end)
end

-- Log the current progress counters on map load.
function H2AP_LogProgress()
	local state = H2AP_LoadState()
	print("[HadesII_AP] Map loaded — score: " .. state.score
		.. ", checks: " .. state.checks_sent
		.. ", items: "  .. state.items_index)
end

-- ═══ Presentation ════════════════════════════════════════════════════════════

function H2AP_NotifySent(location_name)
	local text = "Sent: " .. tostring(location_name)
	local entry = H2AP_GetLocationItem(location_name)
	if type(entry) == "table" and entry.is_local == false then
		local who = entry.player_name
		if type(who) == "string" and who ~= "" then
			text = text .. " -> " .. who
			local game = entry.sender_game
			if type(game) == "string" and game ~= "" then
				text = text .. " (" .. game .. ")"
			end
		end
	end
	H2AP_Notify(text, COLOR_SENT)
end

-- Accepts an item_name string or the full inbox entry table; remote items get a "from <Player> (<Game>)" suffix.
function H2AP_NotifyReceived(item)
	local item_name, player_name, sender_game, is_local
	if type(item) == "table" then
		item_name   = item.item_name
		player_name = item.player_name
		sender_game = item.sender_game
		is_local    = item.is_local
	else
		item_name = item
	end
	item_name = tostring(item_name or "")

	local amount = H2AP_FillerAmount(item_name)
	local text
	if amount then
		text = "Received: " .. amount .. "x " .. item_name
	else
		text = "Received: " .. item_name
	end

	if is_local == false and type(player_name) == "string" and player_name ~= "" then
		text = text .. " from " .. player_name
		if type(sender_game) == "string" and sender_game ~= "" then
			text = text .. " (" .. sender_game .. ")"
		end
	end

	H2AP_Notify(text, COLOR_RECEIVED)
end
