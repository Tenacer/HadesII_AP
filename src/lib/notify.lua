---@meta _
---@diagnostic disable: lowercase-global

-- ── In-game notification log (PrintStack wrapper) ────────────────────────────

local NOTIFY_DEFAULTS = {
	delay    = 5.0,
	fontsize = 13,
	font     = "LatoBold",
	sound    = "/Leftovers/SFX/AuraOff",
	-- ModUtil.Hades.PrintStack sets this on the per-row rectangle and the engine
	-- multiplies it into the text alpha. Keep the default RGB (matches the panel
	-- backing) but raise alpha from 0.125 → 0.75 so text is readable.
	bgcol    = { 0.0745, 0.1020, 0.0980, 0.75 },
}

local COLOR_SENT     = { 0.55, 0.85, 1.00, 1.00 }
local COLOR_RECEIVED = { 0.65, 1.00, 0.65, 1.00 }
local COLOR_SCORE    = { 0.85, 0.85, 0.85, 1.00 }
local COLOR_MSTONE   = { 1.00, 0.85, 0.45, 1.00 }

-- pcall'd because the first call creates screen components and could fail in
-- an unexpected context. The paired print() in callers is the source of truth.
function H2AP_Notify(text, color, delay, sound)
	if type(text) ~= "string" or text == "" then return end
	if not (ModUtil and ModUtil.Hades and ModUtil.Hades.PrintStack) then return end
	pcall(ModUtil.Hades.PrintStack,
		text,
		delay or NOTIFY_DEFAULTS.delay,
		color,
		NOTIFY_DEFAULTS.bgcol,
		NOTIFY_DEFAULTS.fontsize,
		NOTIFY_DEFAULTS.font,
		sound or NOTIFY_DEFAULTS.sound)
end

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

-- Accepts either an item_name string (legacy) or the full inbox entry table
-- {item_name, player_name, sender_game, is_local}. Remote items get a
-- "from <Player> (<Game>)" suffix; local items keep the bare label.
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

	local settings = H2AP_LoadSettings() or {}
	local filler = FILLER_ITEMS and FILLER_ITEMS[item_name]
	local text
	if filler then
		local amount = settings[filler.setting] or 1
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

-- Score ticks fire every cleared room — no sound to avoid spam.
function H2AP_NotifyScore(total_score, delta)
	H2AP_Notify("+" .. tostring(delta) .. " pts. Total score: " .. tostring(total_score),
		COLOR_SCORE, nil, "")
end

function H2AP_NotifyMilestone(checks_sent, max_checks)
	H2AP_Notify("Score check unlocked (" .. checks_sent .. "/" .. max_checks .. ")",
		COLOR_MSTONE)
end
