---@meta _
---@diagnostic disable: lowercase-global

-- ── Reverse Order Rivals ──────────────────────────────────────────────────────
-- When settings.reverse_order_rivals == 1 AND settings.fear_system ∈ {1, 2}:
--   Rank N of the Vow of Rivals enhances the LAST N biomes' bosses instead of
--   the first N. Rank 1 → Chronos/Typhon, rank 2 → +Cerberus/Prometheus, etc.
-- With vanilla fear_system the override is inert.

local function ap_reverse_active()
    local settings = ap_load_settings()
    if not settings then return false end
    if settings.reverse_order_rivals ~= 1 then return false end
    if settings.fear_system ~= 1 and settings.fear_system ~= 2 then return false end
    return true
end

-- Override IsBossDifficultyShrineUpgradeActive via modutil.mod.Path.Set so the
-- write lands in _G (where the game's scripts resolve the global). A bare
-- `function IsBossDifficultyShrineUpgradeActive(...)` declaration here writes
-- to our LuaENVY-private env and the game never sees it — see
-- feedback_modutil_wrap_crash.md.
--
-- The original returns false when shrineRank < EnteredBiomes; we flip the
-- comparison so rank N covers biomes (5-N)..4 instead of 1..N.
if not _ap_orig_IsBossDifficultyShrineUpgradeActive then
    _ap_orig_IsBossDifficultyShrineUpgradeActive = IsBossDifficultyShrineUpgradeActive
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

modutil.mod.Path.Set("IsBossDifficultyShrineUpgradeActive", ap_is_boss_difficulty_shrine_upgrade_active)
print("[HadesII_AP] Reverse rivals: IsBossDifficultyShrineUpgradeActive override installed")

-- ── Vow incantation requirement patching ─────────────────────────────────────
-- The cauldron incantations WorldUpgradeBossDifficultyT2/T3/T4 gate themselves
-- on having beaten the previous tier's EM2 encounters. In reverse mode those
-- encounter cache entries are written for different biomes, so we rewrite the
-- HasAll lists to match. T4 also has ReachedTrueEnding + Chronos/Typhon gates
-- which we strip so T4 is reachable from gameplay (rank 4 in reverse fights
-- the easiest bosses).
--
-- Mutating WorldUpgradeData at module load time triggers the App.Reset GC
-- crash; this is called lazily from prefix_SetupMap, idempotently.

local AP_REVERSE_PATCH_FLAG = "_ap_reverse_rivals_patched"

local REVERSE_ENCOUNTER_REWRITE = {
    WorldUpgradeBossDifficultyT2 = { "BossChronos02", "BossTyphonHead02" },
    WorldUpgradeBossDifficultyT3 = { "BossInfestedCerberus02", "BossPrometheus02" },
    WorldUpgradeBossDifficultyT4 = { "BossScylla02", "BossEris02" },
}

function ap_patch_vow_requirements()
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
