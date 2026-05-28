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

