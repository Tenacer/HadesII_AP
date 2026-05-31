---@meta _
---@diagnostic disable: lowercase-global

-- ── In-game notification toasts (mod-owned, ID-safe) ─────────────────────────
--
-- These DELIBERATELY do not use ModUtil.Hades.PrintStack. That helper keeps a
-- single shared stack of screen components and, every cull cycle, Destroys all
-- of its row object IDs and recreates the visible ones via a CullEnabled/
-- CullPrintStack state machine that stalls. The Destroy churn frees engine
-- object IDs, which Hades immediately recycles to the next SpawnObstacle /
-- CreateConsumableItem — including a just-dropped god boon. A later stale-id
-- Destroy from the stalled cull then kills that recycled object, deleting the
-- boon while it stays registered in MapState.RoomRequiredObjects → the exit
-- door locks with nothing to collect (soft-lock). The same stall is why
-- PrintStack messages "stop after a few".
--
-- Our replacement: each toast is a single screen component that this module
-- creates, fades, and Destroys on its OWN thread. We only ever Destroy an id we
-- created this cycle and never hold an id past its own Destroy, so no live world
-- object can ever be hit by a stale id.

local NOTIFY_DEFAULTS = {
	delay    = 5.0,
	fontsize = 13,
	font     = "LatoBold",
	sound    = "/Leftovers/SFX/AuraOff",
	-- Per-toast backing rectangle colour. RGB matches the panel backing; alpha
	-- 0.75 keeps the text readable over the scene.
	bgcol    = { 0.0745, 0.1020, 0.0980, 0.75 },
}

local COLOR_SENT     = { 0.55, 0.85, 1.00, 1.00 }
local COLOR_RECEIVED = { 0.65, 1.00, 0.65, 1.00 }
local COLOR_SCORE    = { 0.85, 0.85, 0.85, 1.00 }
local COLOR_MSTONE   = { 1.00, 0.85, 0.45, 1.00 }

-- Toast layout. Slots stack upward from a fixed anchor near the bottom-left so
-- the stack stays clear of the combat HUD. Each visible toast owns one slot;
-- when it expires the slot frees and the next toast reuses it. Existing toasts
-- never move (no repositioning churn).
local NOTIFY_GROUP   = "H2AP_Notify"
local NOTIFY_ROW_H   = 30
local NOTIFY_MAX     = 12
local NOTIFY_BASE_X  = 420
local NOTIFY_BASE_DY = 220   -- pixels above the screen bottom for slot 0

-- slot index (1..NOTIFY_MAX) → true while occupied
local notify_slots = {}

local function notify_claim_slot()
	for i = 1, NOTIFY_MAX do
		if not notify_slots[i] then
			notify_slots[i] = true
			return i
		end
	end
	return nil
end

-- One self-contained toast: create → fade in → wait → fade out → Destroy.
-- Runs entirely inside a pcall'd thread; failure leaves no dangling id because
-- the only id we touch is the one we just created.
local function notify_spawn(text, color, delay, sound, bgcol, fontsize, font)
	local slot = notify_claim_slot()
	if slot == nil then return end  -- screen full; drop (rare; print() is the log)

	thread(function()
		local ok = pcall(function()
			local cx = ScreenCenterX or 480
			local cy = ScreenCenterY or 270
			local x  = NOTIFY_BASE_X
			local y  = 2 * cy - NOTIFY_BASE_DY - (slot - 1) * NOTIFY_ROW_H

			local comp = CreateScreenComponent({ Name = "rectangle01", Group = NOTIFY_GROUP, X = x, Y = y })
			local id = comp.Id
			SetScaleX({ Id = id, Fraction = 10 / 6 })
			SetScaleY({ Id = id, Fraction = 0.1 })
			SetColor({ Id = id, Color = bgcol })
			CreateTextBox({
				Id = id, Text = text, FontSize = fontsize, OffsetX = 0, OffsetY = 0,
				Color = color, Font = font, Justification = "Left",
			})
			SetAlpha({ Id = id, Fraction = 0 })
			if sound and sound ~= "" then PlaySound({ Name = sound }) end
			SetAlpha({ Id = id, Fraction = 1, Duration = 0.12 })
			wait(delay)
			SetAlpha({ Id = id, Fraction = 0, Duration = 0.33 })
			wait(0.33)
			Destroy({ Ids = { id } })
		end)
		-- Always release the slot, even if presentation failed partway.
		notify_slots[slot] = nil
		if not ok then
			-- nothing else to clean up: any created id was the only thing touched
		end
	end)
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
		NOTIFY_DEFAULTS.fontsize,
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
