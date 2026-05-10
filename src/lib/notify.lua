---@meta _
---@diagnostic disable: lowercase-global

-- ── In-game notification log (PrintStack wrapper) ────────────────────────────

local NOTIFY_DEFAULTS = {
	delay    = 2.0,
	fontsize = 13,
	font     = "UbuntuMonoBold",
	sound    = "/Leftovers/SFX/AuraOff",
}

local COLOR_SENT     = { 0.55, 0.85, 1.00, 1.00 }
local COLOR_RECEIVED = { 0.65, 1.00, 0.65, 1.00 }
local COLOR_SCORE    = { 0.85, 0.85, 0.85, 1.00 }
local COLOR_MSTONE   = { 1.00, 0.85, 0.45, 1.00 }

-- pcall'd because the first call creates screen components and could fail in
-- an unexpected context. The paired print() in callers is the source of truth.
function ap_notify(text, color, delay, sound)
	if type(text) ~= "string" or text == "" then return end
	if not (ModUtil and ModUtil.Hades and ModUtil.Hades.PrintStack) then return end
	pcall(ModUtil.Hades.PrintStack,
		text,
		delay or NOTIFY_DEFAULTS.delay,
		color,
		nil,
		NOTIFY_DEFAULTS.fontsize,
		NOTIFY_DEFAULTS.font,
		sound or NOTIFY_DEFAULTS.sound)
end

function ap_notify_sent(location_name)
	ap_notify("Sent: " .. tostring(location_name), COLOR_SENT)
end

function ap_notify_received(item_name)
	local settings = ap_load_settings() or {}
	local filler = FILLER_ITEMS and FILLER_ITEMS[item_name]
	if filler then
		local amount = settings[filler.setting] or 1
		ap_notify("Received: " .. amount .. "x " .. item_name, COLOR_RECEIVED)
	else
		ap_notify("Received: " .. tostring(item_name), COLOR_RECEIVED)
	end
end

-- Score ticks fire every cleared room — shorter delay, no sound to avoid spam.
function ap_notify_score(total_score, delta)
	ap_notify("+" .. tostring(delta) .. " pts → " .. tostring(total_score),
		COLOR_SCORE, 1.5, "")
end

function ap_notify_milestone(checks_sent, max_checks)
	ap_notify("Score check unlocked (" .. checks_sent .. "/" .. max_checks .. ")",
		COLOR_MSTONE)
end
