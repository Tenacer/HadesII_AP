---@meta _
---@diagnostic disable: lowercase-global

-- Library modules are imported from ready.lua / ready_late.lua, not here:
-- importing from reload.lua re-runs the file on every hot-reload, which is
-- wasted work for pure-definition modules and unsafe for the install-type ones.
-- What remains in this file is intentionally hot-reloadable: the AP-icon /
-- text-label helpers and the SJSON hook handlers, so their cosmetic logic can be
-- tweaked at runtime without restarting the game.

-- ── AP icon ───────────────────────────────────────────────────────────────────

-- Animation name for our custom AP logo, packed in Tenacer_AP-HadesII_AP.pkg.
AP_ICON_ANIM = _PLUGIN.guid .. "\\ap_icon"

-- Replace the Icon field on every AP-controlled incantation so the cauldron
-- screen shows the Archipelago logo instead of per-spell artwork. The set of
-- AP-controlled keys depends on settings:
--  • cauldronsanity → the 86 non-surface, non-goal incantations
--  • lock_surface_incantations → the two surface-unlock incantations
--  • true_ending → the two goal incantations
function H2AP_PatchIncantationIcons()
	if WorldUpgradeData == nil then return end
	local settings = H2AP_LoadSettings() or {}
	local do_cauldron = settings.cauldronsanity == 1
	for key, _ in pairs(INCANTATION_LOCATIONS) do
		local data = WorldUpgradeData[key]
		if data then
			local is_ap = H2AP_IsApKeyedIncantation(key, settings)
				or (do_cauldron and not H2AP_IsSurfaceLockIncantation(key)
					and not H2AP_IsGoalIncantation(key))
			if is_ap then
				data.Icon = AP_ICON_ANIM
			end
		end
	end
end

-- Append a `PathTrue` requirement to each AP-keyed incantation's
-- GameStateRequirements so the cauldron entry stays hidden until the player
-- receives the AP item (which sets the corresponding TextLinesRecord flag).
-- Idempotent: a sentinel `_ap_cauldron_gate_patched` on each entry prevents
-- double-application across hot-reload / SetupMap calls.
function H2AP_PatchIncantationGates()
	if WorldUpgradeData == nil then return end
	local settings = H2AP_LoadSettings() or {}
	local keyed = H2AP_KeyedIncantations(settings)
	for key in pairs(keyed) do
		local data = WorldUpgradeData[key]
		if data and not data._ap_cauldron_gate_patched then
			data.GameStateRequirements = data.GameStateRequirements or {}
			table.insert(data.GameStateRequirements, {
				PathTrue = { "GameState", "TextLinesRecord", H2AP_UnlockFlagFor(key) },
			})
			data._ap_cauldron_gate_patched = true
		end
	end
end

-- Rewrite the brewing costs of the two True Ending goal incantations so they
-- match the per-seed thresholds. Vanilla costs (8 total Z-Sand, 4 V-Lens) would
-- consume the entire item pool — patching to the threshold leaves the rest
-- free for Arcana upgrades. Gigaros + Entropy stay at 1× each.
-- Idempotent via `_ap_cost_patched` sentinel.
function H2AP_PatchIncantationCosts()
	if WorldUpgradeData == nil then return end
	local settings = H2AP_LoadSettings() or {}
	if settings.true_ending ~= 1 then return end
	local zsand = tonumber(settings.zodiac_sand_needed) or 4
	local vlens = tonumber(settings.void_lens_needed) or 2
	local d = WorldUpgradeData["WorldUpgradeTimeStop"]
	if d and not d._ap_cost_patched then
		d.Cost = { MixerIBoss = zsand, MixerMythic = 1 }
		d._ap_cost_patched = true
	end
	local s = WorldUpgradeData["WorldUpgradeStormStop"]
	if s and not s._ap_cost_patched then
		s.Cost = { MixerQBoss = vlens, HadesSpearPoints = 1 }
		s._ap_cost_patched = true
	end
end

-- Show the AP logo banner when a keepsake gifting location check fires.
-- Mirrors PlayerReceivedGiftPresentation's sound/voice/color-grading but
-- uses the AP logo and gift-style banner animations instead of the vanilla keepsake icon.
function H2AP_ShowKeepsakeCheckBanner(npc)
	thread(function()
		AdjustColorGrading({ Name = "Mythmaker", Duration = 0.66 })
		PlaySound({ Name = "/Leftovers/Menu Sounds/StarSelectConfirm" })
		thread(PlayVoiceLines, npc.GiftGivenVoiceLines, true)
		thread(PlayVoiceLines, CurrentRun.Hero.GiftReceivedVoiceLines, true)
		DisplayInfoBanner(nil, {
			Icon = AP_ICON_ANIM,
			IconScale = 1.3,
			IconMoveSpeed = 0.00001,
			IconOffsetY = 6,
			HighlightIcon = true,
			TitleText = "APCheckSent",
			FontScale = 0.82,
			AnimationName = "InfoBannerGiftIn",
			AnimationOutName = "InfoBannerGiftOut",
			IconBackingAnimationName = "LocationBackingIrisSmallSubtitleIn",
			IconBackingAnimationOutName = "LocationBackingIrisSmallSubtitleOut",
			IconBackingColor = Color.Lavender,
			IconBackingHSV = { 0.25, -0.2, 0.1 },
		})
		thread(function()
			wait(1.0)
			AdjustColorGrading({ Name = "Off", Duration = 1.0 })
		end)
		if CheckObjectiveSet("KeepsakePrompt") then
			UpdateAffordabilityStatus()
		end
	end)
end

-- Show the AP logo banner when a boss reward location check fires.
-- Uses the same InfoBanner presentation as the cauldron "AP Check Sent" popup.
function H2AP_ShowBossRewardBanner()
	thread(function()
		DisplayInfoBanner(nil, {
			TitleText = "APCheckSent",
			FontScale = 0.82,
			Icon = AP_ICON_ANIM,
			IconScale = 1.3,
			IconMoveSpeed = 0.00001,
			IconOffsetY = 6,
			AnimationName = "InfoBannerCauldronIn",
			AnimationOutName = "InfoBannerCauldronOut",
			IconBackingAnimationName = "LocationBackingIrisSmallSubtitleIn",
			IconBackingAnimationOutName = "LocationBackingIrisSmallSubtitleOut",
		})
	end)
end

-- ── SJSON hook handlers ───────────────────────────────────────────────────────

function sjson_ShellText(data)
	for _, v in ipairs(data.Texts) do
		if v.Id == 'MainMenuScreen_PlayGame' then
			v.DisplayName = 'Play Hades II AP'
			break
		end
	end
end

-- Shared: rewrite a text entry's DisplayName/Description to advertise the AP item
-- placed at `ap_location` (scouted into ap_location_items.json), falling back to a
-- generic "AP Location Check" before LocationScouts has run. Preserves the vanilla
-- name/description so the player still sees what the check is attached to
-- (per feedback_ap_helptext_preserve_vanilla). Used by both the HelpText hook
-- (incantations / prophecies) and the TraitText hook (weapons / tools / aspects).
function H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
	local item_entry = location_items[ap_location]
	local display = "AP Location Check"
	if type(item_entry) == "table" then
		display = item_entry.display or item_entry.item_name or display
	elseif type(item_entry) == "string" then
		-- Back-compat with the older flat string format.
		display = item_entry
	end
	local vanilla_name = entry.DisplayName
	local vanilla_desc = entry.Description
	local opener = (vanilla_name and vanilla_name ~= "") and vanilla_name or display
	local new_desc = "Archipelago location check for " .. opener .. ".\nComplete this in-game to send a check to the Archipelago server."
	if vanilla_desc and vanilla_desc ~= "" then
		new_desc = new_desc .. "\n\nOriginal: " .. vanilla_desc
	end
	entry.DisplayName = display
	entry.Description = new_desc
end

function sjson_HelpText(data)
	-- Inject the "AP Check Sent" banner title used by the cauldron hook.
	data.Texts[#data.Texts + 1] = { Id = "APCheckSent", DisplayName = "AP Check Sent" }

	-- Replace incantation / Fated List Quest entries with AP info when their
	-- respective sanity option is on. Weapon/tool/aspect labels live in
	-- TraitText.en.sjson, NOT here, so those are handled by sjson_TraitText.
	local settings = H2AP_LoadSettings() or {}
	local do_cauldron = settings.cauldronsanity == 1
	local do_fate = settings.fatesanity == 1
	local keyed = H2AP_KeyedIncantations(settings)
	local has_keyed = next(keyed) ~= nil
	if not (do_cauldron or do_fate or has_keyed) then return end

	local location_items = H2AP_ReadLocationItems() or {}

	-- Resolve an incantation key to the AP location name it represents, only
	-- when that key is AP-controlled in the current settings. The 86
	-- cauldronsanity keys are owned by cauldronsanity; the surface 2 and goal 2
	-- are owned by their respective toggles regardless of cauldronsanity.
	local function incantation_location_for(id)
		if keyed[id] then return INCANTATION_LOCATIONS[id] end
		if do_cauldron
			and not H2AP_IsSurfaceLockIncantation(id)
			and not H2AP_IsGoalIncantation(id) then
			return INCANTATION_LOCATIONS[id]
		end
		return nil
	end

	for _, entry in ipairs(data.Texts) do
		local id = entry.Id
		if id then
			local ap_location = incantation_location_for(id)
				or (do_fate and PROPHECY_LOCATIONS[id])
			if ap_location then
				H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
			else
				local base_id = id:match("^(.-)_Flavor$")
				if base_id and incantation_location_for(base_id) then
					local vanilla_flavor = entry.Description
					local new_desc = "What you receive in exchange is determined by the Archipelago multiworld randomizer."
					if vanilla_flavor and vanilla_flavor ~= "" then
						new_desc = new_desc .. "\n\nOriginal: " .. vanilla_flavor
					end
					entry.Description = new_desc
				end
			end
		end
	end
end

-- WeaponShop slot labels for weapons / tools / hidden aspects. Their DisplayNames
-- live in TraitText.en.sjson (the shop renders `item.HelpTextId or item.Name` as a
-- text Id via auto-lookup, and these entries' Ids equal their internal names — the
-- *_LOCATIONS keys). HelpText.en.sjson has no such entries, which is why these must
-- be patched here rather than in sjson_HelpText.
function sjson_TraitText(data)
	local settings = H2AP_LoadSettings() or {}
	local do_weapon = settings.weaponsanity == 1
	local do_tool = settings.toolsanity == 1
	local do_aspect = settings.hidden_aspectsanity == 1
	if not (do_weapon or do_tool or do_aspect) then return end

	local location_items = H2AP_ReadLocationItems() or {}
	for _, entry in ipairs(data.Texts) do
		local id = entry.Id
		if id then
			local ap_location = (do_weapon and WEAPON_LOCATIONS[id])
				or (do_tool and TOOL_LOCATIONS[id])
				or (do_aspect and HIDDEN_ASPECT_LOCATIONS[id])
			if ap_location then
				H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
			end
		end
	end
end
