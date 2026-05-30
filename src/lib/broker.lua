---@meta _
---@diagnostic disable: lowercase-global

-- ── Broker QoL unlock ─────────────────────────────────────────────────────────
-- When the AP `unlock_broker` setting is on, grant the Broker (WorldUpgradeMarket)
-- from the start of the game. The Crossroads hub-load events call
-- ActivateConditionalItems(GhostAdminCategoryIndex = 1), which spawns the Broker
-- obstacle automatically for any category-1 WorldUpgrade whose
-- GameState.WorldUpgrades flag is set — so setting the flags before the hub
-- loads is all that's needed. WorldUpgradesAdded is set too because many
-- downstream requirement checks (Broker interactions, dependent incantations)
-- key off WorldUpgradesAdded.WorldUpgradeMarket rather than WorldUpgrades.

local BROKER_WORLD_UPGRADE = "WorldUpgradeMarket"

function H2AP_ApplyUnlockBroker()
	local settings = H2AP_LoadSettings()
	if not (settings and settings.unlock_broker == 1) then return end
	if GameState == nil then return end          -- pre-profile SetupMap guard
	if GameState.WorldUpgrades[BROKER_WORLD_UPGRADE] then return end  -- idempotent
	GameState.WorldUpgrades[BROKER_WORLD_UPGRADE]         = true
	GameState.WorldUpgradesAdded[BROKER_WORLD_UPGRADE]    = true
	GameState.WorldUpgradesViewed[BROKER_WORLD_UPGRADE]   = true
	GameState.WorldUpgradesRevealed[BROKER_WORLD_UPGRADE] = true
	print("[HadesII_AP] Broker unlocked at start (WorldUpgradeMarket)")
end
