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
	H2AP_Notify("Sent: " .. tostring(location_name), COLOR_SENT)
end

function H2AP_NotifyReceived(item_name)
	local settings = H2AP_LoadSettings() or {}
	local filler = FILLER_ITEMS and FILLER_ITEMS[item_name]
	if filler then
		local amount = settings[filler.setting] or 1
		H2AP_Notify("Received: " .. amount .. "x " .. item_name, COLOR_RECEIVED)
	else
		H2AP_Notify("Received: " .. tostring(item_name), COLOR_RECEIVED)
	end
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
