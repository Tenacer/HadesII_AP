---@meta _
---@diagnostic disable: lowercase-global

-- ── In-game notification toasts (mod-owned, ID-safe) ─────────────────────────
-- Deliberately avoids ModUtil.Hades.PrintStack, whose stale-id Destroy churn can delete live world objects (soft-lock); each toast here owns and destroys only its own component.

local NOTIFY_DEFAULTS = {
	delay    = 5.0,
	fontsize = 15,  -- fallback only; the live value is config.notify_font_size
	font     = "LatoBold",
	sound    = "/Leftovers/SFX/AuraOff",
	-- Backing rectangle colour; alpha keeps the text readable over the scene.
	bgcol    = { 0.0745, 0.1020, 0.0980, 0.75 },
}

local COLOR_SENT     = { 0.55, 0.85, 1.00, 1.00 }
local COLOR_RECEIVED = { 0.65, 1.00, 0.65, 1.00 }
local COLOR_SCORE    = { 0.85, 0.85, 0.85, 1.00 }
local COLOR_MSTONE   = { 1.00, 0.85, 0.45, 1.00 }

-- Toast layout: slots stack upward from a fixed anchor near the bottom-left; existing toasts never move.
local NOTIFY_GROUP   = "H2AP_Notify"
local NOTIFY_ROW_H   = 30
local NOTIFY_MAX     = 12
local NOTIFY_BASE_X  = 420
local NOTIFY_BASE_DY = 220   -- pixels above the screen bottom for slot 0

-- slot index (1..NOTIFY_MAX) → deadline while occupied, nil when free; deadlines (not booleans) let slots self-heal when a map load kills the toast thread before it releases its slot.
local notify_slots = {}

-- Bounded FIFO queue of toasts waiting for a free slot; overflow sheds the oldest.
local notify_pending = {}
local NOTIFY_PENDING_MAX = 128
local NOTIFY_RECLAIM_GRACE = 1.0   -- secs past a toast's lifetime before forced reclaim

local function notify_now()
	return _worldTime or 0
end

-- Free any slot whose deadline has elapsed.
local function notify_reclaim()
	local now = notify_now()
	for i = 1, NOTIFY_MAX do
		local deadline = notify_slots[i]
		if deadline ~= nil and now >= deadline then
			notify_slots[i] = nil
		end
	end
end

-- Claim a free slot for a toast of the given lifetime, reclaiming expired slots first.
local function notify_claim_slot(lifetime)
	notify_reclaim()
	for i = 1, NOTIFY_MAX do
		if notify_slots[i] == nil then
			notify_slots[i] = notify_now() + lifetime + NOTIFY_RECLAIM_GRACE
			return i
		end
	end
	return nil
end

-- Forward declaration: the pump and toasts reference each other.
local notify_pump

-- One self-contained toast in a claimed slot: create, fade in, wait, fade out, Destroy, then free the slot and pump the queue.
local function notify_start(slot, t)
	thread(function()
		pcall(function()
			local cx = ScreenCenterX or 480
			local cy = ScreenCenterY or 270
			local x  = NOTIFY_BASE_X
			local y  = 2 * cy - NOTIFY_BASE_DY - (slot - 1) * NOTIFY_ROW_H

			local comp = CreateScreenComponent({ Name = "rectangle01", Group = NOTIFY_GROUP, X = x, Y = y })
			local id = comp.Id
			SetScaleX({ Id = id, Fraction = 10 / 6 })
			SetScaleY({ Id = id, Fraction = 0.1 })
			SetColor({ Id = id, Color = t.bgcol })
			-- Center justification keeps the text inside the single-line backing bar.
			CreateTextBox({
				Id = id, Text = t.text, FontSize = t.fontsize, OffsetX = 0, OffsetY = 0,
				Color = t.color, Font = t.font, Justification = "Center",
			})
			SetAlpha({ Id = id, Fraction = 0 })
			if t.sound and t.sound ~= "" then PlaySound({ Name = t.sound }) end
			SetAlpha({ Id = id, Fraction = 1, Duration = 0.12 })
			wait(t.delay)
			SetAlpha({ Id = id, Fraction = 0, Duration = 0.33 })
			wait(0.33)
			Destroy({ Ids = { id } })
		end)
		-- Always release the slot, then let the next queued toast claim it.
		notify_slots[slot] = nil
		notify_pump()
	end)
end

-- Drain the pending queue into any free slots.
notify_pump = function()
	while #notify_pending > 0 do
		local t = notify_pending[1]
		-- Lifetime mirrors the thread body: fade-in + hold + fade-out.
		local lifetime = 0.12 + (t.delay or 0) + 0.33
		local slot = notify_claim_slot(lifetime)
		if slot == nil then return end  -- all slots busy; wait for one to free
		table.remove(notify_pending, 1)
		notify_start(slot, t)
	end
end

-- Enqueue a toast and immediately try to display it.
local function notify_spawn(text, color, delay, sound, bgcol, fontsize, font)
	if #notify_pending >= NOTIFY_PENDING_MAX then
		table.remove(notify_pending, 1)  -- shed the oldest
	end
	notify_pending[#notify_pending + 1] = {
		text = text, color = color, delay = delay, sound = sound,
		bgcol = bgcol, fontsize = fontsize, font = font,
	}
	notify_pump()
end

-- pcall'd at the boundary too, so a notification can never break a caller.
function H2AP_Notify(text, color, delay, sound)
	if type(text) ~= "string" or text == "" then return end
	if CreateScreenComponent == nil or thread == nil then return end
	pcall(notify_spawn,
		text,
		color or { 1, 1, 1, 1 },
		delay or NOTIFY_DEFAULTS.delay,
		sound or NOTIFY_DEFAULTS.sound,
		NOTIFY_DEFAULTS.bgcol,
		(config and config.notify_font_size) or NOTIFY_DEFAULTS.fontsize,
		NOTIFY_DEFAULTS.font)
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

-- Score ticks fire every cleared room, so no sound; route_label is shown in separate split mode, nil in combined.
function H2AP_NotifyScore(delta, total, route_label, to_next)
	local route = route_label and (route_label .. " ") or ""
	local label = route_label and (route_label .. " score") or "Total score"
	local tail = to_next and ("  (" .. tostring(to_next) .. " to next check)") or ""
	H2AP_Notify("+" .. tostring(delta) .. " " .. route .. "pts. " .. label .. ": " .. tostring(total) .. tail,
		COLOR_SCORE, nil, "")
end

-- Announce an unlocked score check against its route's budget (route_label nil in combined mode).
function H2AP_NotifyMilestone(checks_sent, budget, route_label)
	local prefix = route_label and (route_label .. " score check") or "Score check"
	H2AP_Notify(prefix .. " unlocked (" .. checks_sent .. "/" .. budget .. ")",
		COLOR_MSTONE)
end
