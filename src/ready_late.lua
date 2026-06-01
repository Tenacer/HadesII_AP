---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- here is where your mod sets up all the things it will do after all other mods load.
-- this file will not be reloaded if it changes during gameplay
-- 	so you will most likely want to have it reference
--	values and functions later defined in `reload_late.lua`.

-- ── Initial startup calls ────────────────────────────────────────────────────

-- These need reload.lua (imported in on_reload before on_ready_late fires).
-- Patch incantation icons + cauldron-visibility gates for the hub screen
-- before the first SetupMap wrap fires.
H2AP_PatchIncantationIcons()
H2AP_PatchIncantationGates()
H2AP_PatchIncantationCosts()
-- Flush the outbox immediately so the Python client sees the game is running.
H2AP_FlushOutbox()

-- ── GiftData fix ──────────────────────────────────────────────────────────────

-- Clear GameStateRequirements from all GiftData gift-level entries so that AP can
-- trigger keepsake location checks via gifting without needing specific NPC dialogue
-- to have happened first. Runs after all mods have populated GiftData.
for npcName, npcData in pairs(GiftData) do
	if type(npcData) == "table" then
		for i = 1, #npcData do
			if npcData[i] and npcData[i].GameStateRequirements then
				npcData[i].GameStateRequirements = {}
			end
		end
	end
end

-- ── Contested game-function wraps ─────────────────────────────────────────────
-- These three globals are also hooked by several other installed mods, so we
-- register our wraps here (on_ready_late, i.e. after on_all_mods_loaded) rather
-- than in ready.lua's early on_ready phase. That keeps our position in the wrap
-- chain deterministic relative to the other mods and avoids the load-order GC
-- instability described in ModUtil issue #12. The callbacks reference H2AP_*
-- globals resolved at call time (defined in reload.lua), so late registration is
-- safe. Recompute ap_icon_pkg here since ready.lua's local isn't in scope.
local ap_icon_pkg = rom.path.combine(_PLUGIN.plugins_data_mod_folder_path, _PLUGIN.guid)

-- Runs at the start of every room load: processes the AP inbox (grant queued items).
-- The inbox polling thread is started here on the first SetupMap call because
-- thread() requires SessionMapState to exist, which is only true once a map loads.
local _polling_started = false
modutil.mod.Path.Wrap("SetupMap", function(base, ...)
	-- Reload the package each room (game may evict it) and re-patch icons
	-- (hot-reloads of reload.lua reset WorldUpgradeData icon fields).
	LoadPackages({ Name = ap_icon_pkg })
	H2AP_PatchIncantationIcons()
	H2AP_PatchIncantationGates()
	H2AP_PatchIncantationCosts()
	H2AP_SetupMap()
	if not _polling_started then
		_polling_started = true
		-- Persist=true survives LoadMap/KillNonPersistentThreads so we only need to start once.
		thread(function()
			while true do
				wait(0.5, "AP_Inbox_Poll", true)
				H2AP_ProcessInbox()
			end
		end)
	end
	return base(...)
end)

-- Fires when all enemies in a room are dead: score a room clear or a boss kill.
modutil.mod.Path.Wrap("OnAllEnemiesDead", function(base, currentRoom, currentEncounter)
	local result = base(currentRoom, currentEncounter)
	H2AP_OnRoomCleared(currentRoom, currentEncounter)
	return result
end)

-- KillHero is the hero-specific death handler in DeathLoopLogic.lua.
-- Kill() calls it only when victim == CurrentRun.Hero, so this fires exactly
-- once per Melinoë death and not for enemy deaths.
modutil.mod.Path.Wrap("KillHero", function(base, victim, triggerArgs)
	local result = base(victim, triggerArgs)
	H2AP_OnMelinoeDied()
	return result
end)

