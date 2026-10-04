---@meta _
---@diagnostic disable: lowercase-global

-- Fear: reverse_Fear and minimal_Fear vow levels, the hidden shrine and reverse-order Vow of Rivals.
-- reverse_Fear starts vows locked ON and each AP vow item lowers a rank; minimal_Fear applies vow ranks as a permanent floor; the shrine is hidden in both.

-- ═══ Data ════════════════════════════════════════════════════════════════════

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

local AP_REVERSE_PATCH_FLAG = "_ap_reverse_rivals_patched"

local REVERSE_ENCOUNTER_REWRITE = {
    WorldUpgradeBossDifficultyT2 = { "BossChronos02", "BossTyphonHead02" },
    WorldUpgradeBossDifficultyT3 = { "BossInfestedCerberus02", "BossPrometheus02" },
    WorldUpgradeBossDifficultyT4 = { "BossScylla02", "BossEris02" },
}

-- ═══ Logic ═══════════════════════════════════════════════════════════════════

-- ── Vow levels ────────────────────────────────────────────────────────────────

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

-- Receiving a vow item in reverse_Fear: bump the unlock counter and re-apply levels; returns nil for other items.
function H2AP_FearGiveItem(item_name)
    local shrine_name = H2AP_GetShrineForVowItem(item_name)
    if not shrine_name then return nil end

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

-- UseShrineObject wrap: block the shrine screen when the mod manages vow levels (reverse/minimal fear).
function H2AP_OnUseShrine(base, usee, args)
    local settings = H2AP_LoadSettings()
    if settings and settings.fear_system ~= nil and settings.fear_system ~= 3 then
        print("[HadesII_AP] Shrine interaction blocked (fear system active)")
        return
    end
    return base(usee, args)
end

-- ── Reverse Order Rivals ──────────────────────────────────────────────────────
-- Under reverse_order_rivals, rank N of the Vow of Rivals enhances the LAST N biomes' bosses instead of the first N.

local function ap_reverse_active()
    local settings = H2AP_LoadSettings()
    if not settings then return false end
    if settings.reverse_order_rivals ~= 1 then return false end
    if settings.fear_system ~= 1 and settings.fear_system ~= 2 then return false end
    return true
end

local function ap_is_boss_difficulty_shrine_upgrade_active(source, args)
    if not ap_reverse_active() then
        return _ap_orig_IsBossDifficultyShrineUpgradeActive(source, args)
    end

    args = args or {}
    local shrineRank
    if args.UseShrineUpgradesCache then
        shrineRank = (CurrentRun and CurrentRun.ShrineUpgradesCache
            and CurrentRun.ShrineUpgradesCache.BossDifficultyShrineUpgrade) or 0
    else
        shrineRank = (GameState and GameState.ShrineUpgrades
            and GameState.ShrineUpgrades.BossDifficultyShrineUpgrade) or 0
    end

    local enteredBiomes = (CurrentRun and CurrentRun.EnteredBiomes) or 0
    if shrineRank < (5 - enteredBiomes) then
        return false
    end

    if CurrentRun and CurrentRun.IsDreamRun and enteredBiomes > 0 then
        local latestBiomeVisited = CurrentRun.BiomeVisitOrder[enteredBiomes]
        local encounterMapData = BossDifficultyShrineEncounterBiomeMap[latestBiomeVisited]
        if encounterMapData then
            if encounterMapData.OnlyRequireSeen then
                return GameState.EncountersOccurredCache[encounterMapData.Encounter] == true
            else
                return GameState.EncountersCompletedCache[encounterMapData.Encounter] == true
            end
        end
    end

    return true
end

-- Override via Path.Set so the write lands in the game's _G, flipping the rank comparison so rank N covers the last N biomes; called once from ready_late.
function H2AP_InstallReverseRivals()
    if not _ap_orig_IsBossDifficultyShrineUpgradeActive then
        _ap_orig_IsBossDifficultyShrineUpgradeActive = IsBossDifficultyShrineUpgradeActive
    end
    modutil.mod.Path.Set("IsBossDifficultyShrineUpgradeActive", ap_is_boss_difficulty_shrine_upgrade_active)
    print("[HadesII_AP] Reverse rivals: IsBossDifficultyShrineUpgradeActive override installed")
end

-- Rewrite the T2/T3/T4 vow incantation encounter gates for reverse order and strip T4's post-ending gates; called lazily from the SetupMap wrap to avoid the App.Reset GC crash.
function H2AP_PatchVowRequirements()
    if not ap_reverse_active() then return end
    if WorldUpgradeData == nil then return end

    for upgrade_name, new_encounters in pairs(REVERSE_ENCOUNTER_REWRITE) do
        local data = WorldUpgradeData[upgrade_name]
        if data and not data[AP_REVERSE_PATCH_FLAG] then
            local reqs = data.GameStateRequirements
            if type(reqs) == "table" then
                local kept = {}
                for _, req in ipairs(reqs) do
                    local drop = false

                    -- Rewrite the EncountersCompletedCache.HasAll list.
                    if req.Path and req.Path[1] == "GameState"
                        and req.Path[2] == "EncountersCompletedCache"
                        and req.HasAll then
                        req.HasAll = new_encounters
                    end

                    -- For T4: strip the ReachedTrueEnding + Chronos/Typhon gates.
                    if upgrade_name == "WorldUpgradeBossDifficultyT4" then
                        local p = req.PathTrue or req.Path
                        if p then
                            local joined = table.concat(p, ".")
                            if joined == "GameState.ReachedTrueEnding"
                                or joined == "GameState.EnemyKills.Chronos"
                                or joined == "GameState.EnemyKills.TyphonHead" then
                                drop = true
                            end
                            -- TextLinesRecord NeoChronosAbout* clauses
                            if joined == "GameState.TextLinesRecord" and req.HasAny then
                                local has_neo = false
                                for _, name in ipairs(req.HasAny) do
                                    if name == "NeoChronosAboutTartarus01"
                                        or name == "NeoChronosAboutTartarus01_B"
                                        or name == "NeoChronosAboutOlympus01"
                                        or name == "NeoChronosAboutOlympus01_B" then
                                        has_neo = true
                                        break
                                    end
                                end
                                if has_neo then drop = true end
                            end
                        end
                    end

                    if not drop then
                        kept[#kept + 1] = req
                    end
                end
                data.GameStateRequirements = kept
            end
            data[AP_REVERSE_PATCH_FLAG] = true
            print("[HadesII_AP] Reverse rivals: patched " .. upgrade_name .. " requirements")
        end
    end
end
