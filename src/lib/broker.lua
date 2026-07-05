---@meta _
---@diagnostic disable: lowercase-global

-- ── Broker QoL unlock ─────────────────────────────────────────────────────────
-- Under unlock_broker, grant the Broker from game start by setting its WorldUpgrade flags before the hub loads.

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
