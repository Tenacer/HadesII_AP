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
	fontsize = 15,  -- fallback only; the live value is config.notify_font_size
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

-- slot index (1..NOTIFY_MAX) → deadline (a _worldTime value) while occupied, nil
-- when free.
--
-- IMPORTANT: a toast runs inside a non-persistent thread() (no Persist flag), and
-- Hades' KillNonPersistentThreads() (Main.lua) runs on every map/room load, so it
-- kills any toast parked in wait() mid-display. A killed thread never reaches its
-- own slot-release line, so if a slot were a plain boolean it would leak one
-- transition at a time until all NOTIFY_MAX slots are permanently "busy" and no
-- new toast can ever appear (the multi-hour "messages stop" bug). To make slots
-- self-healing we store a DEADLINE per slot and reclaim any slot whose deadline
-- has passed, regardless of whether its thread survived. The engine tears down our
-- screen components on map load, so a killed thread leaves no visible orphan — only
-- the slot bookkeeping needed recovering.
local notify_slots = {}

-- FIFO queue of toasts waiting for a free slot, drained as slots free. Bounded so
-- a runaway sender can't grow it without limit; on overflow we drop the OLDEST
-- pending toast (the newest traffic is the most useful).
local notify_pending = {}
local NOTIFY_PENDING_MAX = 128
local NOTIFY_RECLAIM_GRACE = 1.0   -- secs past a toast's lifetime before forced reclaim

local function notify_now()
	return _worldTime or 0
end

-- Free any slot whose deadline has elapsed. This is what recovers slots whose
-- toast thread was killed by a map load before it could release itself.
local function notify_reclaim()
	local now = notify_now()
	for i = 1, NOTIFY_MAX do
		local deadline = notify_slots[i]
		if deadline ~= nil and now >= deadline then
			notify_slots[i] = nil
		end
	end
end

-- Claim a free slot for a toast of the given lifetime, reclaiming expired slots
-- first. The deadline is the lifetime plus a grace margin so a live thread will
-- normally release its slot on completion before the forced reclaim fires.
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

-- Forward declaration: a finishing toast pumps the queue, and the pump starts
-- toasts, so the two reference each other.
local notify_pump

-- One self-contained toast in a claimed slot: create → fade in → wait → fade out
-- → Destroy. Runs entirely inside a pcall'd thread; failure leaves no dangling id
-- because the only id we touch is the one we just created. On normal exit it frees
-- its slot early and pumps the queue; if the thread is instead killed on a map
-- load, the slot is recovered later by its deadline (see notify_reclaim).
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
			CreateTextBox({
				Id = id, Text = t.text, FontSize = t.fontsize, OffsetX = 0, OffsetY = 0,
				Color = t.color, Font = t.font, Justification = "Left",
			})
			SetAlpha({ Id = id, Fraction = 0 })
			if t.sound and t.sound ~= "" then PlaySound({ Name = t.sound }) end
			SetAlpha({ Id = id, Fraction = 1, Duration = 0.12 })
			wait(t.delay)
			SetAlpha({ Id = id, Fraction = 0, Duration = 0.33 })
			wait(0.33)
			Destroy({ Ids = { id } })
		end)
		-- Always release the slot, even if presentation failed partway, then let
		-- the next queued toast (if any) claim it.
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

-- Enqueue a toast and immediately try to display it. Replaces the old
-- drop-on-full behaviour.
local function notify_spawn(text, color, delay, sound, bgcol, fontsize, font)
	if #notify_pending >= NOTIFY_PENDING_MAX then
		table.remove(notify_pending, 1)  -- bound the queue; shed the oldest
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
