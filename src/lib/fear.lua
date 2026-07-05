---@meta _
---@diagnostic disable: lowercase-global

-- ── Fear system ───────────────────────────────────────────────────────────────
-- reverse_Fear starts vows locked ON and each AP vow item lowers a rank; minimal_Fear applies vow ranks as a permanent floor; the shrine is hidden in both.

-- Maps AP vow item name → shrine upgrade name.
VOW_SHRINE_MAP = {
    ["Vow of Pain"]    = "EnemyDamageShrineUpgrade",
    ["Vow of Grit"]    = "EnemyHealthShrineUpgrade",
    ["Vow of Wards"]   = "EnemyShieldShrineUpgrade",
    ["Vow of Frenzy"]  = "EnemySpeedShrineUpgrade",
    ["Vow of Hordes"]  = "EnemyCountShrineUpgrade",
    ["Vow of Menace"]  = "NextBiomeEnemyShrineUpgrade",
    ["Vow of Return"]  = "EnemyRespawnShrineUpgrade",
    ["Vow of Fangs"]   = "EnemyEliteShrineUpgrade",
    ["Vow of Scars"]   = "HealingReductionShrineUpgrade",
    ["Vow of Debt"]    = "ShopPricesShrineUpgrade",
    ["Vow of Shadow"]  = "MinibossCountShrineUpgrade",
    ["Vow of Forfeit"] = "BoonSkipShrineUpgrade",
    ["Vow of Time"]    = "BiomeSpeedShrineUpgrade",
    ["Vow of Void"]    = "LimitGraspShrineUpgrade",
    ["Vow of Hubris"]  = "BoonManaReserveShrineUpgrade",
    ["Vow of Denial"]  = "BanUnpickedBoonsShrineUpgrade",
    ["Vow of Rivals"]  = "BossDifficultyShrineUpgrade",
}

-- Returns the shrine upgrade name for a vow AP item, or nil if not a vow item.
function H2AP_GetShrineForVowItem(item_name)
    return VOW_SHRINE_MAP[item_name]
end

-- Sets a shrine upgrade level and updates the cached spend total.
local function set_shrine_rank(shrine_name, rank)
    if GameState == nil or GameState.ShrineUpgrades == nil then return end
    GameState.ShrineUpgrades[shrine_name] = rank
    pcall(ShrineUpgradeExtractValues, shrine_name)
end

local function refresh_shrine_cache()
    if GameState == nil then return end
    local ok, total = pcall(GetTotalSpentShrinePoints)
    if ok then GameState.SpentShrinePointsCache = total end
end

-- Enforce shrine levels for the active fear system; called on every SetupMap and inbox poll.
function H2AP_ApplyShrineLevels()
    local settings = H2AP_LoadSettings()
    if not settings or settings.fear_system == 3 or settings.fear_system == nil then
        if settings and settings.fear_system == nil then
            print("[HadesII_AP] H2AP_ApplyShrineLevels: settings not ready yet (fear_system nil)")
        end
        return
    end
    if GameState == nil then
        print("[HadesII_AP] H2AP_ApplyShrineLevels: GameState nil, skipping")
        return
    end

    local vow_ranks = settings.vow_ranks or {}
    GameState.ShrineUpgrades = GameState.ShrineUpgrades or {}

    if settings.fear_system == 1 then
        -- reverse_Fear: target = initial_rank - items_received (min 0)
        local state = H2AP_LoadState()
        local received = state.vow_received or {}
        for shrine_name, initial_rank in pairs(vow_ranks) do
            local unlocked = received[shrine_name] or 0
            local target = math.max(0, initial_rank - unlocked)
            set_shrine_rank(shrine_name, target)
        end

    elseif settings.fear_system == 2 then
        -- minimal_Fear: ensure current rank >= floor rank
        for shrine_name, floor_rank in pairs(vow_ranks) do
            local current = GameState.ShrineUpgrades[shrine_name] or 0
            if current < floor_rank then
                set_shrine_rank(shrine_name, floor_rank)
            end
        end
    end

    refresh_shrine_cache()
end

-- Receiving a vow item in reverse_Fear: bump the unlock counter and re-apply levels.
function H2AP_GiveItemVow(item_name)
    local shrine_name = H2AP_GetShrineForVowItem(item_name)
    if not shrine_name then return false end

    local settings = H2AP_LoadSettings()
    if not settings or settings.fear_system ~= 1 then
        -- minimal_Fear / vanilla: vow items shouldn't be in the pool, but handle gracefully
        print("[HadesII_AP] Vow item ignored (not reverse_Fear): " .. item_name)
        return true
    end

    local state = H2AP_LoadState()
    state.vow_received = state.vow_received or {}
    state.vow_received[shrine_name] = (state.vow_received[shrine_name] or 0) + 1

    local vow_ranks = settings.vow_ranks or {}
    local initial = vow_ranks[shrine_name] or 0
    local unlocked = state.vow_received[shrine_name]
    local new_rank = math.max(0, initial - unlocked)
    set_shrine_rank(shrine_name, new_rank)
    refresh_shrine_cache()

    print("[HadesII_AP] Vow unlocked: " .. item_name
        .. " -> " .. shrine_name .. " rank " .. new_rank)
    return true
end
