---@meta _
---@diagnostic disable: lowercase-global

-- ── Settings (written by Python client on AP connect) ─────────────────────────
-- Cached once the file is found; nil if the file doesn't exist yet (retried on
-- every call). _settings is reset to nil on each hot-reload / room transition.

local _settings = nil

function H2AP_LoadSettings()
	if _settings then return _settings end
	local f = io.open(H2AP_Dir() .. "ap_settings.json", "r")
	if not f then
		-- Don't cache — return empty without setting _settings so the next call
		-- retries. The Python client may not have connected yet.
		return {}
	end
	local raw = f:read("*a")
	f:close()
	_settings = H2AP_JsonDecode(raw) or {}
	print("[HadesII_AP] Settings loaded: fear_system=" .. tostring(_settings.fear_system)
		.. " score_rewards=" .. tostring(_settings.score_rewards_amount))
	return _settings
end
